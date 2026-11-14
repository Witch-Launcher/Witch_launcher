// FSR3 Frame Generation bridge implementation on top of the AMD FidelityFX
// SDK (Vulkan backend). See ffx_bridge.h for the contract.
//
// Design notes:
//  - We use the direct FrameInterpolation API (ffxFrameInterpolationPrepare +
//    ffxFrameInterpolationDispatch), NOT the FrameInterpolationSwapchain
//    wrapper: the launcher owns present pacing through the patched
//    RenderPearl surface.
//  - Motion vectors are synthesized from the camera pose delta (a
//    constant-depth reprojection of the current pixel into the previous
//    camera, which is the backward mapping FidelityFX expects) and computed
//    on the GPU. FidelityFX disocclusion refinement is limited by the
//    synthetic depth (constant far plane) until engine depth can be
//    captured.
//  - Outputs are double buffered: slot s is written by the real frame and
//    presented on the next vsync by the agent.

#include "ffx_bridge.h"

#include "synth_mvs_vk.h"
#include "fsr1_resolve_vk.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <condition_variable>
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <mutex>
#include <thread>
#include <vector>
#include <atomic>

#include <dlfcn.h>

#include <vulkan/vulkan.h>

#include <FidelityFX/host/ffx_interface.h>
#include <FidelityFX/host/ffx_frameinterpolation.h>
#include <FidelityFX/host/ffx_opticalflow.h>
#include <FidelityFX/host/ffx_fsr1.h>
#include <FidelityFX/host/ffx_fsr2.h>
#include <FidelityFX/host/ffx_fsr3upscaler.h>
#include <FidelityFX/host/backends/vk/ffx_vk.h>

#include "ffx_fsr3upscaler_private.h"
#include "ffx_opticalflow_private.h"

namespace {

constexpr int kMaxOutputs = 2;
// Interpolated outputs: one slot per generated sub-frame. The largest
// supported frame generation multiplier is x6 (5 generated frames per real
// frame), and every slot of a frame must stay alive until its presents drain
// before the next record pass rotates back onto it.
constexpr int kMaxFgOutputs = 6;

// Reference distance (metres) the synthetic motion vectors assume the scene
// sits at. Minecraft gives us no depth buffer, so the camera reprojection has
// to pick a single "typical" distance. The displacement is exact for a pure
// camera rotation at any distance (the rotation part is depth independent);
// only the parallax of a walking camera depends on this value, so it should
// be in the range of the geometry that covers most of the screen (a few
// metres to the horizon).
constexpr float kMotionReferenceDepth = 8.0f;

// Distance used for the pixels that look above the horizon (sky and distant
// terrain) when the ground plane is known. It matches the far plane the game
// reports, and it keeps the model continuous at the horizon: the ground
// distance approaches it as the ray flattens out.
constexpr float kMotionFarDepth = 64.0f;

// Fallback vertical field of view (radians) when the game reports a
// degenerate one - the tangent of the half FOV is used to build the camera
// ray and must not be zero.
constexpr float kFallbackFovYRadians = 1.2217305f;  // 70 degrees

// How long the present path waits for a free swapchain image before it skips
// the generated frame. The display releases an image once per vsync, so
// waiting for a full frame time would stall the render thread for ~16 ms per
// generated frame. Two milliseconds is enough for an image that was just
// released and keeps the stall off the critical path.
constexpr uint64_t kPresentAcquireTimeoutNs = 2000000ull;  // 2 ms

struct BridgeState {
    bool initialized = false;
    bool enabled = true;
    // Upscaler mode (0 = none). Frame generation is tracked separately so the
    // two features can run together (combo).
    int mode = 0;
    bool fg = false;
    float sharpness = 0.0f;

    uint32_t renderWidth = 0;
    uint32_t renderHeight = 0;
    uint32_t displayWidth = 0;
    uint32_t displayHeight = 0;
    // Resolution the frame interpolation runs at.
    //
    // In combo mode the upscaler already produced a display-resolution image,
    // so the interpolation consumes that and runs at the display resolution.
    // In pure FG mode the only source is the game's own colour texture, which
    // lives at the render resolution - and the SDK copies the current frame
    // into its internal previous-frame history using the SOURCE extent. A
    // mismatch there means the history is only partially updated and the
    // interpolation blends against stale pixels (double images). So the
    // interpolation (and its optical flow) must use the resolution of the
    // image that is actually fed to it.
    uint32_t fgWidth = 0;
    uint32_t fgHeight = 0;
    // Swapchain format (bridge outputs / FI back buffer in combo mode) and
    // the game render texture format (external color resource, FI back
    // buffer in pure-FG mode).
    VkFormat colorFormat = VK_FORMAT_B8G8R8A8_UNORM;
    VkFormat srcColorFormat = VK_FORMAT_R8G8B8A8_UNORM;

    // Handles retained for teardown.
    VkDevice device = VK_NULL_HANDLE;
    VkPhysicalDevice physicalDevice = VK_NULL_HANDLE;
    VkQueue queue = VK_NULL_HANDLE;
    uint32_t queueFamilyIndex = 0;

    uint32_t hostVisibleMemoryType = UINT32_MAX;
    uint32_t deviceLocalMemoryType = UINT32_MAX;

    FfxInterface ffxInterface = {};
    FfxFrameInterpolationContext fiContext = {};
    bool fiContextValid = false;

    // Optical flow context feeding the frame interpolation dispatch (the
    // composite driver runs ffxOpticalflowContextDispatch before the FI
    // dispatch and wires its outputs into the FI description; without it the
    // FI binds empty optical-flow resources).
    FfxOpticalflowContext ofContext = {};
    bool ofContextValid = false;
    FfxResourceInternal ofVectorInternal = {};
    FfxResourceInternal ofScdInternal = {};
    FfxResource ofVector = {};
    FfxResource ofScd = {};

    FfxFsr1Context fsr1Context = {};
    bool fsr1Valid = false;

    FfxFsr2Context fsr2Context = {};
    bool fsr2Valid = false;

    FfxFsr3UpscalerContext fsr3uContext = {};
    bool fsr3uValid = false;
    // Shared resources required by the FSR3 upscaler dispatch (dilated depth /
    // motion vectors / reconstructed previous nearest depth). Allocated from
    // the interface pool; freed with the backend context.
    FfxResourceInternal fsr3uDilatedDepthInternal = {};
    FfxResourceInternal fsr3uDilatedMVsInternal = {};
    FfxResourceInternal fsr3uRecPrevNearestDepthInternal = {};
    FfxResource fsr3uDilatedDepth = {};
    FfxResource fsr3uDilatedMVs = {};
    FfxResource fsr3uRecPrevNearestDepth = {};

    // Bridge-owned command infrastructure for the upscaler path (recorded
    // buffer joins the game's frame submission) and the frame generation
    // extra present (own acquire/submit/present).
    VkCommandPool commandPool = VK_NULL_HANDLE;
    // Witch patch: dedicated pool for the paced-present worker thread
    // (pools are not internally synchronized; one pool per recording
    // thread).
    VkCommandPool presentCommandPool = VK_NULL_HANDLE;    // Ring of primary command buffers for the per-frame FidelityFX work.
    // Rotating avoids resetting a buffer that a previous submission may
    // still hold pending (the game can call submit() more than once/frame).
    static constexpr int kCbRing = 3;
    VkCommandBuffer upscaleCommandBuffers[kCbRing] = {};
    int upscaleCbIndex = 0;
    long long lastRecordedCb = 0;
    // Separate ring for the interpolated-frame present blit: resetting the
    // upscale buffers (which the game's encoder submits) while they may
    // still be pending is invalid.
    VkCommandBuffer presentCommandBuffers[kCbRing] = {};
    int presentCbIndex = 0;
    // Witch patch: one semaphore pair and one fence per ring slot. A binary
    // semaphore may only be re-signaled after its previous wait executed, so
    // a slot is recycled only once its own fence has signaled.
    VkSemaphore acquireSemaphores[kCbRing] = {};
    VkSemaphore presentSemaphores[kCbRing] = {};
    VkFence presentFences[kCbRing] = {};
    // Live swapchain image list (refreshed per present; never cached across
    // a surface reconfigure).
    std::vector<VkImage> swapchainImages;
    VkSwapchainKHR cachedSwapchain = VK_NULL_HANDLE;
    // Set by the surface hooks (configure/close run on the render thread
    // before RenderPearl destroys the swapchain). The next present rebuilds
    // the sync objects; by then RenderPearl's destroy path has waited idle.
    bool resetPresentObjects = false;
    // A swapchain error stops generated presents until the surface is
    // reconfigured; the game's real frame keeps presenting (clean degrade).
    bool presentBroken = false;

    // Scratch buffer handed to ffxGetInterfaceVK.
    std::vector<uint8_t> scratch;

    // Synthetic motion vectors: host-visible staging -> device-local SRV.
    VkImage mvsStaging = VK_NULL_HANDLE;
    VkDeviceMemory mvsStagingMemory = VK_NULL_HANDLE;
    void* mvsStagingMapped = nullptr;
    VkDeviceSize mvsStagingRowPitch = 0;
    VkImage mvsDevice = VK_NULL_HANDLE;
    VkDeviceMemory mvsDeviceMemory = VK_NULL_HANDLE;

    // Constant depth (far plane) used until engine depth is available.
    VkImage depthStaging = VK_NULL_HANDLE;
    VkDeviceMemory depthStagingMemory = VK_NULL_HANDLE;
    void* depthStagingMapped = nullptr;
    VkDeviceSize depthStagingRowPitch = 0;
    VkImage depthDevice = VK_NULL_HANDLE;
    VkDeviceMemory depthDeviceMemory = VK_NULL_HANDLE;

    // FI dilate/reconstruct outputs (UAVs written by the FI pipelines).
    // dilatedDepth: R32F, dilatedMotionVectors: R16G16F, reconstructed
    // previous nearest depth: R32UINT (packed), all render-res.
    VkImage dilatedDepthDevice = VK_NULL_HANDLE;
    VkDeviceMemory dilatedDepthDeviceMemory = VK_NULL_HANDLE;
    VkImage dilatedMvsDevice = VK_NULL_HANDLE;
    VkDeviceMemory dilatedMvsDeviceMemory = VK_NULL_HANDLE;
    VkImage recDepthDevice = VK_NULL_HANDLE;
    VkDeviceMemory recDepthDeviceMemory = VK_NULL_HANDLE;

    // Upscaler outputs (double buffered; written by the FSR dispatches).
    VkImage outputs[kMaxOutputs] = {};
    VkDeviceMemory outputMemories[kMaxOutputs] = {};

    // Witch patch: FSR1 writes its upscale result through a UAV declared
    // "rgba32f" in the shader, so the output image must be
    // VK_FORMAT_R32G32B32A32_SFLOAT - a UNORM8 view does not match the
    // shader's declared format (VUID-vkCmdDispatch-None-09679) and the
    // dispatch writes garbage. The resolve pass converts the float result
    // to the swapchain format in outputs[] before it is presented.
    VkImage fsr1Float = VK_NULL_HANDLE;
    VkDeviceMemory fsr1FloatMemory = VK_NULL_HANDLE;
    // Whether the float image has been brought to GENERAL yet (FFX's
    // barrier tracking never emits the initial transition).
    bool fsr1FloatGeneralInit = false;

    // Resolve pass: reads the float FSR1 output and writes the 8-bit
    // output image the present path blits into the swapchain.
    VkShaderModule resolveShader = VK_NULL_HANDLE;
    VkPipeline resolvePipeline = VK_NULL_HANDLE;
    VkPipelineLayout resolveLayout = VK_NULL_HANDLE;
    VkDescriptorSetLayout resolveSetLayout = VK_NULL_HANDLE;
    VkDescriptorPool resolvePool = VK_NULL_HANDLE;
    VkDescriptorSet resolveDescSets[kMaxOutputs] = {};
    VkImageView resolveSrcView = VK_NULL_HANDLE;
    VkImageView resolveDstViews[kMaxOutputs] = {};

    // Whether the 8-bit output images have been transitioned to GENERAL
    // yet. The FSR dispatches leave them in GENERAL; the FSR1 resolve path
    // writes them itself and has to bring them there on first use.
    bool outputGeneralInit[kMaxOutputs] = {};

    // Interpolated outputs (one slot per generated sub-frame; written by the
    // FI dispatches). Kept separate from the upscaler outputs so both features
    // can run in combo: the upscaler writes outputs[], the interpolator
    // consumes that result and writes fgOutputs[].
    VkImage fgOutputs[kMaxFgOutputs] = {};
    VkDeviceMemory fgOutputMemories[kMaxFgOutputs] = {};

    uint64_t frameID = 0;
    uint32_t outputSlot = 0;
    uint32_t fgOutputSlot = 0;
    bool lastFrameOk = false;

    // Witch patch: frame generation multiplier M: the number of frames shown
    // per real frame (2 = classic x2, one generated frame; up to 6). The FI
    // dispatch runs (M - 1) times per real frame, each sub-frame at its own
    // interpolation phase.
    int fgMultiplier = 2;
    // Interpolated-output slots actually allocated: multiplier size (one slot
    // per generated frame + the next write). Memory matters on 3 GB devices;
    // x2 therefore gets 2 slots (~14 MB) instead of 6 (~41 MB).
    int fgSlotCount = kMaxFgOutputs;
    // Slots written by the current frame's FI dispatches (batch for the
    // present hook to display, oldest first).
    uint32_t fgBatchBase = 0;
    uint32_t fgBatchCount = 0;

    // Witch patch: frame statistics for the launcher FPS widget. Timestamps
    // are captured per event and folded into EMA rates on read.
    std::atomic<uint64_t> statRealFrames{0};
    std::atomic<uint64_t> statGenFrames{0};
    // Generated frames that were dropped because the display had no free
    // swapchain image yet (the present path must not stall the render
    // thread for a full vsync).
    std::atomic<uint64_t> statGenSkipped{0};
    double statLastRealTime = 0.0;
    double statLastGenTime = 0.0;
    float statRenderFps = 0.0f;
    float statGenFps = 0.0f;

    // Witch patch: per-stage host-side record timings (the FFX SDK's CPU cost
    // of encoding each dispatch: barrier translation, descriptor sets and the
    // MoltenVK VkCmd* calls). Folded into EMAs and logged once every
    // kPerfLogFrames successful records so the device log pinpoints which
    // stage dominates the frame budget.
    struct PerfStage {
        double emaMs = 0.0;
        uint64_t samples = 0;
    };
    static constexpr int kPerfLogFrames = 60;
    PerfStage perfCopies, perfUpscale, perfOf, perfPrepare, perfFi, perfTotal;
    int perfLogCounter = 0;
    // Present-hook wall time: acquire blocking + blit record + submit +
    // vkQueuePresentKHR. Large values with fps-throttling are expected, but
    // it distinguishes GPU-bound throttling from CPU record overhead.
    PerfStage perfPresent;

    // GPU synthetic motion vector pipeline (see synth_mvs.comp). Falls back
    // to the legacy CPU per-pixel fill when unavailable.
    VkShaderModule synthMvsShader = VK_NULL_HANDLE;
    VkPipeline synthMvsPipeline = VK_NULL_HANDLE;
    VkPipelineLayout synthMvsLayout = VK_NULL_HANDLE;
    VkDescriptorSetLayout synthMvsSetLayout = VK_NULL_HANDLE;
    VkDescriptorPool synthMvsPool = VK_NULL_HANDLE;
    VkDescriptorSet synthMvsDescSet = VK_NULL_HANDLE;
    VkImageView synthMvsView = VK_NULL_HANDLE;
    bool synthMvsFailedLogged = false;

    // Witch patch: the A11 optical-flow throttle was removed. The flow
    // field belongs to the frame pair it was computed for; re-using it for
    // the next frame warped the interpolation with the wrong motion (the
    // generated frames showed double images and smeared blocks). The flow
    // is now computed for every frame that gets interpolated.

    // Measurement probe bitmask (see ffxfg_set_probe). Zero = production
    // behavior.
    int probeMask = 0;
    unsigned probeAnnounced = 0;

    // GPU timestamp profiling: a ring of query pools, one set of markers per
    // record. Results of record N are consumed (folded into the GPU EMAs)
    // when record N + kPerfQueryPools reuses the same pool; 8 records of lag
    // guarantee the submit finished long ago. Costs ~40 bytes total.
    static constexpr int kPerfQueryPools = 8;
    static constexpr int kPerfQueryCount = 8;
    VkQueryPool perfQueryPools[kPerfQueryPools] = {};
    uint64_t perfRecordHandle = 0;
    bool perfPoolWritten[kPerfQueryPools] = {};
    double timestampPeriodNs = 1.0;
    PerfStage perfGpuCopies, perfGpuUpscale, perfGpuOf, perfGpuPrep, perfGpuFi, perfGpuTotal;

    // Previous camera pose for synthetic motion vectors.
    float prevPos[3] = {};
    float prevRight[3] = {};
    float prevUp[3] = {};
    float prevFwd[3] = {};
    bool havePrevPose = false;
};

BridgeState g_bridge;

void logBridge(const char* message)
{
    fprintf(stderr, "[Fsr3Bridge] %s\n", message);
}

// Log a dispatch-stage failure once per unique key so silent per-frame
// errors become visible without spamming the log.
void logDispatchError(const char* stage, FfxErrorCode error)
{
    static char loggedKeys[8][48] = {};
    static int loggedCount = 0;
    char key[48];
    snprintf(key, sizeof(key), "%s:%d", stage, static_cast<int>(error));
    for (int i = 0; i < loggedCount; ++i) {
        if (strcmp(loggedKeys[i], key) == 0) {
            return;
        }
    }
    if (loggedCount < 8) {
        strcpy(loggedKeys[loggedCount++], key);
    }
    char message[96];
    snprintf(message, sizeof(message), "record: %s failed (err=0x%08x)", stage, static_cast<unsigned>(error));
    logBridge(message);
}

// Fold one sample into a stage EMA (first sample becomes the seed).
void perfNote(BridgeState::PerfStage* stage, double deltaMs)
{
    stage->emaMs = (stage->samples == 0) ? deltaMs
                                         : stage->emaMs * 0.9 + deltaMs * 0.1;
    stage->samples++;
}

double perfMsSince(std::chrono::steady_clock::time_point start)
{
    return std::chrono::duration<double, std::milli>(
               std::chrono::steady_clock::now() - start).count();
}

// Fold a pool's GPU timestamps (written by a record kPerfQueryPools frames
// ago) into the GPU stage EMAs. Marker slots: 0 = record start, 1 = after
// the motion-data copies, 2 = after the upscaler dispatch, 3 = after the
// optical-flow dispatch, 4 = after the FI prepare, 5 = after the FI dispatch
// loop, 6 = record end. Every stage owns its own slot: the old layout wrote
// slot 2 twice (upscaler and optical flow) and required slot 4, so an
// upscaler-only record never produced a single sample and the whole GPU
// panel stayed at 0.0. A stage that did not run in this mode leaves its slot
// empty and is simply skipped.
void foldPerfTimestamps(BridgeState& b, int poolIndex)
{
    VkQueryPool pool = b.perfQueryPools[poolIndex];
    if (!pool || !b.perfPoolWritten[poolIndex]) {
        return;
    }
    uint64_t ts[BridgeState::kPerfQueryCount] = {};
    if (vkGetQueryPoolResults(b.device, pool, 0, BridgeState::kPerfQueryCount,
                              sizeof(ts), ts, sizeof(uint64_t),
                              VK_QUERY_RESULT_64_BIT) != VK_SUCCESS) {
        return;
    }
    b.perfPoolWritten[poolIndex] = false;

    if (ts[0] == 0) {
        return;
    }
    const double period = b.timestampPeriodNs;
    auto toMs = [&period](uint64_t last, uint64_t end) {
        return static_cast<double>(end - last) * period / 1.0e6;
    };

    // Each stage is measured from the previous marker that was actually
    // written, so a skipped stage does not inflate the next one.
    const uint64_t stageEnd[5] = {ts[1], ts[2], ts[3], ts[4], ts[5]};
    BridgeState::PerfStage* const stage[5] = {&b.perfGpuCopies, &b.perfGpuUpscale,
                                 &b.perfGpuOf, &b.perfGpuPrep, &b.perfGpuFi};
    uint64_t previous = ts[0];
    uint64_t last = ts[0];
    for (int i = 0; i < 5; ++i) {
        if (stageEnd[i] == 0) {
            continue;
        }
        perfNote(stage[i], toMs(previous, stageEnd[i]));
        previous = stageEnd[i];
        last = stageEnd[i];
    }
    if (ts[6] != 0) {
        last = ts[6];
    }
    perfNote(&b.perfGpuTotal, toMs(ts[0], last));
}

void fsr2MessageCallback(FfxMsgType /*type*/, const wchar_t* message)
{
    fprintf(stderr, "[Fsr2] %ls\n", message);
}

void fsr3UpscalerMessageCallback(FfxMsgType /*type*/, const wchar_t* message)
{
    fprintf(stderr, "[Fsr3Upscaler] %ls\n", message);
}

uint16_t floatToHalf(float value)
{
    const uint32_t bits = *reinterpret_cast<const uint32_t*>(&value);
    const uint32_t sign = (bits >> 16) & 0x8000u;
    const int32_t exponent = static_cast<int32_t>((bits >> 23) & 0xFFu) - 127 + 15;
    uint32_t mantissa = bits & 0x007FFFFFu;

    if (((bits >> 23) & 0xFFu) == 0xFFu) {
        // Inf/NaN
        return static_cast<uint16_t>(sign | 0x7C00u | (mantissa ? 0x0200u : 0u));
    }
    if (exponent <= 0) {
        if (exponent < -10) {
            return static_cast<uint16_t>(sign);
        }
        mantissa |= 0x00800000u;
        const int32_t shift = 14 - exponent;
        const uint32_t half = mantissa >> shift;
        const uint32_t remainder = mantissa << (32 - shift);
        const uint32_t rounded = half + ((remainder > 0x80000000u) ? 1u : 0u);
        return static_cast<uint16_t>(sign | rounded);
    }
    if (exponent >= 31) {
        return static_cast<uint16_t>(sign | 0x7BFFu);  // saturate
    }
    const uint32_t half = (static_cast<uint32_t>(exponent) << 10) | (mantissa >> 13);
    const uint32_t rounded = half + (((mantissa & 0x1FFFu) > 0x1000u) ? 1u : 0u);
    return static_cast<uint16_t>(sign | rounded);
}

VkImageAspectFlags imageAspectForFormat(VkFormat format)
{
    switch (format) {
        case VK_FORMAT_D16_UNORM:
        case VK_FORMAT_D32_SFLOAT:
            return VK_IMAGE_ASPECT_DEPTH_BIT;
        default:
            return VK_IMAGE_ASPECT_COLOR_BIT;
    }
}

bool findMemoryType(VkPhysicalDevice physicalDevice,
                    const VkMemoryRequirements& requirements,
                    VkMemoryPropertyFlags wantedFlags,
                    uint32_t* outTypeIndex)
{
    VkPhysicalDeviceMemoryProperties properties = {};
    vkGetPhysicalDeviceMemoryProperties(physicalDevice, &properties);
    for (uint32_t i = 0; i < properties.memoryTypeCount; ++i) {
        if ((requirements.memoryTypeBits & (1u << i)) &&
            (properties.memoryTypes[i].propertyFlags & wantedFlags) == wantedFlags) {
            *outTypeIndex = i;
            return true;
        }
    }
    return false;
}

bool createImage2D(VkDevice device,
                   VkPhysicalDevice physicalDevice,
                   uint32_t width, uint32_t height,
                   VkFormat format,
                   VkImageTiling tiling,
                   VkImageUsageFlags usage,
                   VkMemoryPropertyFlags memoryFlags,
                   VkImage* outImage,
                   VkDeviceMemory* outMemory,
                   void** outMapped,
                   VkDeviceSize* outRowPitch)
{
    VkImageCreateInfo imageInfo = {};
    imageInfo.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
    imageInfo.imageType = VK_IMAGE_TYPE_2D;
    imageInfo.format = format;
    imageInfo.extent = {width, height, 1};
    imageInfo.mipLevels = 1;
    imageInfo.arrayLayers = 1;
    imageInfo.samples = VK_SAMPLE_COUNT_1_BIT;
    imageInfo.tiling = tiling;
    imageInfo.usage = usage;
    imageInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
    imageInfo.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;

    if (vkCreateImage(device, &imageInfo, nullptr, outImage) != VK_SUCCESS) {
        return false;
    }

    VkMemoryRequirements requirements = {};
    vkGetImageMemoryRequirements(device, *outImage, &requirements);

    uint32_t memoryTypeIndex = 0;
    if (!findMemoryType(physicalDevice, requirements, memoryFlags, &memoryTypeIndex)) {
        vkDestroyImage(device, *outImage, nullptr);
        *outImage = VK_NULL_HANDLE;
        return false;
    }

    VkMemoryAllocateInfo allocInfo = {};
    allocInfo.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    allocInfo.allocationSize = requirements.size;
    allocInfo.memoryTypeIndex = memoryTypeIndex;

    if (vkAllocateMemory(device, &allocInfo, nullptr, outMemory) != VK_SUCCESS) {
        vkDestroyImage(device, *outImage, nullptr);
        *outImage = VK_NULL_HANDLE;
        return false;
    }
    if (vkBindImageMemory(device, *outImage, *outMemory, 0) != VK_SUCCESS) {
        vkFreeMemory(device, *outMemory, nullptr);
        *outMemory = VK_NULL_HANDLE;
        vkDestroyImage(device, *outImage, nullptr);
        *outImage = VK_NULL_HANDLE;
        return false;
    }

    if (outMapped && (memoryFlags & VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT)) {
        if (vkMapMemory(device, *outMemory, 0, requirements.size, 0, outMapped) != VK_SUCCESS) {
            vkFreeMemory(device, *outMemory, nullptr);
            *outMemory = VK_NULL_HANDLE;
            vkDestroyImage(device, *outImage, nullptr);
            *outImage = VK_NULL_HANDLE;
            return false;
        }
    }

    if (outRowPitch) {
        // For LINEAR-tiling staging images this is the exact row pitch.
        VkImageSubresource subresource = {};
        subresource.aspectMask = imageAspectForFormat(format);
        subresource.mipLevel = 0;
        subresource.arrayLayer = 0;
        VkSubresourceLayout layout = {};
        vkGetImageSubresourceLayout(device, *outImage, &subresource, &layout);
        *outRowPitch = layout.rowPitch;
    }

    return true;
}

void writeSyntheticMotionVectors(const float* camData, int camDataCount, bool reset)
{
    if (!g_bridge.mvsStagingMapped) {
        return;
    }

    const uint32_t width = g_bridge.renderWidth;
    const uint32_t height = g_bridge.renderHeight;

    const float* pos = &camData[0];
    const float* right = &camData[3];
    const float* up = &camData[6];
    const float* fwd = &camData[9];
    const float fovY = camData[14];
    // Height of the eye above the ground the player stands on (0 = unknown,
    // the constant reference depth is used then).
    const float eyeHeight = (camDataCount > 18) ? camData[18] : 0.0f;

    // Tangent-space half FOV tangents. The camera ray of a pixel is
    //   dir = forward + ndcX*tanHalfFovX*right - ndcY*tanHalfFovY*up
    // The up axis carries the minus sign because the render target is
    // bottom-up (RenderPearl renders OpenGL-style, the present blit flips Y),
    // so FidelityFX's ndcY = +1 sits at the screen bottom.
    const float tanHalfFovY = (fovY > 0.0f && fovY < 3.14159265f)
        ? std::tan(0.5f * fovY)
        : std::tan(0.5f * kFallbackFovYRadians);
    const float tanHalfFovX = (height > 0)
        ? tanHalfFovY * (static_cast<float>(width) / static_cast<float>(height))
        : tanHalfFovY;


    if (!g_bridge.havePrevPose || reset) {
        // First frame after a reset (or a camera cut / teleport): the previous
        // pose does not describe the same view, so there is no meaningful
        // motion. Zero vectors are the right answer - the upscaler and the
        // interpolation drop their history in the same frame.
        for (uint32_t y = 0; y < height; ++y) {
            uint16_t* line = reinterpret_cast<uint16_t*>(
                reinterpret_cast<uint8_t*>(g_bridge.mvsStagingMapped) + y * g_bridge.mvsStagingRowPitch);
            for (uint32_t x = 0; x < width; ++x) {
                line[2 * x + 0] = 0;
                line[2 * x + 1] = 0;
            }
        }
    } else {
        for (uint32_t y = 0; y < height; ++y) {
            uint16_t* line = reinterpret_cast<uint16_t*>(
                reinterpret_cast<uint8_t*>(g_bridge.mvsStagingMapped) + y * g_bridge.mvsStagingRowPitch);
            // NDC y of this row (+1 at the bottom of the render target).
            const float ndcY = 1.0f - 2.0f * (static_cast<float>(y) + 0.5f) / static_cast<float>(height);
            for (uint32_t x = 0; x < width; ++x) {
                const float ndcX = 2.0f * (static_cast<float>(x) + 0.5f) / static_cast<float>(width) - 1.0f;

                // Reference distance of this pixel. With the eye height known
                // (the player stands on the ground) the ground plane gives the
                // distance of the ground pixels, which is a far better
                // estimate than one constant for the whole screen: the
                // parallax error of a walking camera drops by 3-7x.
                float refDepth = kMotionReferenceDepth;
                if (eyeHeight > 0.0f) {
                    // Vertical component of the ray per unit of forward depth.
                    const float rayY = fwd[1] - ndcY * tanHalfFovY * up[1];
                    refDepth = (rayY < -1e-4f)
                        ? std::min(std::max(eyeHeight / (-rayY), 0.5f), kMotionFarDepth)
                        : kMotionFarDepth;
                }

                // Ray of the CURRENT camera for this pixel.
                const float dir[3] = {
                    fwd[0] + ndcX * tanHalfFovX * right[0] - ndcY * tanHalfFovY * up[0],
                    fwd[1] + ndcX * tanHalfFovX * right[1] - ndcY * tanHalfFovY * up[1],
                    fwd[2] + ndcX * tanHalfFovX * right[2] - ndcY * tanHalfFovY * up[2],
                };

                // World point at the reference forward depth along that ray.
                const float world[3] = {
                    pos[0] + refDepth * dir[0],
                    pos[1] + refDepth * dir[1],
                    pos[2] + refDepth * dir[2],
                };

                // Project it into the PREVIOUS camera: that is where the
                // content of this pixel came from.
                const float rel[3] = {
                    world[0] - g_bridge.prevPos[0],
                    world[1] - g_bridge.prevPos[1],
                    world[2] - g_bridge.prevPos[2],
                };
                float depthPrev = rel[0] * g_bridge.prevFwd[0] +
                                  rel[1] * g_bridge.prevFwd[1] +
                                  rel[2] * g_bridge.prevFwd[2];
                if (depthPrev < 1e-3f) {
                    depthPrev = 1e-3f;
                }
                const float lateralPrevX = rel[0] * g_bridge.prevRight[0] +
                                           rel[1] * g_bridge.prevRight[1] +
                                           rel[2] * g_bridge.prevRight[2];
                const float lateralPrevY = rel[0] * g_bridge.prevUp[0] +
                                           rel[1] * g_bridge.prevUp[1] +
                                           rel[2] * g_bridge.prevUp[2];

                const float ndcPrevX = (lateralPrevX / depthPrev) / tanHalfFovX;
                const float ndcPrevY = -(lateralPrevY / depthPrev) / tanHalfFovY;

                // Motion vector: current position - previous position.
                float mvX = ndcX - ndcPrevX;
                float mvY = ndcY - ndcPrevY;

                // Clamp to a sane range (one screen).
                mvX = std::max(-2.0f, std::min(2.0f, mvX));
                mvY = std::max(-2.0f, std::min(2.0f, mvY));

                const float encoded[2] = {mvX, mvY};
                line[2 * x + 0] = floatToHalf(encoded[0]);
                line[2 * x + 1] = floatToHalf(encoded[1]);
            }
        }
    }

    g_bridge.prevPos[0] = pos[0];
    g_bridge.prevPos[1] = pos[1];
    g_bridge.prevPos[2] = pos[2];
    g_bridge.prevRight[0] = right[0];
    g_bridge.prevRight[1] = right[1];
    g_bridge.prevRight[2] = right[2];
    g_bridge.prevUp[0] = up[0];
    g_bridge.prevUp[1] = up[1];
    g_bridge.prevUp[2] = up[2];
    g_bridge.prevFwd[0] = fwd[0];
    g_bridge.prevFwd[1] = fwd[1];
    g_bridge.prevFwd[2] = fwd[2];
    g_bridge.havePrevPose = true;
}

void recordImageBarrier(VkCommandBuffer cmd,
                        VkImage image,
                        VkImageAspectFlags aspect,
                        VkImageLayout oldLayout,
                        VkImageLayout newLayout,
                        VkPipelineStageFlags2 srcStage,
                        VkAccessFlags2 srcAccess,
                        VkPipelineStageFlags2 dstStage,
                        VkAccessFlags2 dstAccess);

void recordCopyHostImage(VkCommandBuffer cmd,
                         VkImage staging,
                         VkImage deviceImage,
                         uint32_t width, uint32_t height,
                         VkFormat format);

// Lazy staging for the CPU mvs fallback: only allocated when the GPU synth
// dispatch is unavailable (keeps the ~11MB host-visible allocation out of
// the process footprint while the fast path works).
bool ensureMvsStaging()
{
    BridgeState& b = g_bridge;
    if (b.mvsStagingMapped) {
        return true;
    }
    if (!createImage2D(b.device, b.physicalDevice, b.renderWidth, b.renderHeight,
                       VK_FORMAT_R16G16_SFLOAT, VK_IMAGE_TILING_LINEAR,
                       VK_IMAGE_USAGE_TRANSFER_SRC_BIT,
                       VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
                       &b.mvsStaging, &b.mvsStagingMemory,
                       &b.mvsStagingMapped, &b.mvsStagingRowPitch)) {
        logBridge("record: mvs staging lazy alloc failed");
        return false;
    }
    return true;
}

// Diagnostic: the magnitude of the synthetic motion vector at a few sample
// points of the screen, in pixels. It uses the same math as the synthesis
// shader, so the device log shows directly whether the field is sane (a
// pure mouse look of 16 degrees has to produce roughly 16/70 of the screen
// width, not a fraction of a pixel and not several screens).
float syntheticMotionMagnitude(const BridgeState& b, const float* camData, int camDataCount, bool reset)
{
    if (!b.havePrevPose || reset) {
        return 0.0f;
    }
    const float* pos = &camData[0];
    const float* right = &camData[3];
    const float* up = &camData[6];
    const float* fwd = &camData[9];
    const float fovY = camData[14];
    const float eyeHeight = (camDataCount > 18) ? camData[18] : 0.0f;
    const float tanHalfFovY = (fovY > 0.0f && fovY < 3.14159265f)
        ? std::tan(0.5f * fovY)
        : std::tan(0.5f * kFallbackFovYRadians);
    const float tanHalfFovX = (b.renderHeight > 0)
        ? tanHalfFovY * (static_cast<float>(b.renderWidth) / static_cast<float>(b.renderHeight))
        : tanHalfFovY;

    float worst = 0.0f;
    const float samples[5][2] = {
        {0.0f, 0.0f}, {-0.5f, 0.0f}, {0.5f, 0.0f}, {0.0f, -0.5f}, {0.0f, 0.5f},
    };
    for (int s = 0; s < 5; ++s) {
        const float ndcX = samples[s][0];
        const float ndcY = samples[s][1];
        float refDepth = kMotionReferenceDepth;
        if (eyeHeight > 0.0f) {
            const float rayY = fwd[1] - ndcY * tanHalfFovY * up[1];
            refDepth = (rayY < -1e-4f)
                ? std::min(std::max(eyeHeight / (-rayY), 0.5f), kMotionFarDepth)
                : kMotionFarDepth;
        }
        const float dir[3] = {
            fwd[0] + ndcX * tanHalfFovX * right[0] - ndcY * tanHalfFovY * up[0],
            fwd[1] + ndcX * tanHalfFovX * right[1] - ndcY * tanHalfFovY * up[1],
            fwd[2] + ndcX * tanHalfFovX * right[2] - ndcY * tanHalfFovY * up[2],
        };
        const float world[3] = {
            pos[0] + refDepth * dir[0],
            pos[1] + refDepth * dir[1],
            pos[2] + refDepth * dir[2],
        };
        const float rel[3] = {
            world[0] - b.prevPos[0], world[1] - b.prevPos[1], world[2] - b.prevPos[2],
        };
        float depthPrev = rel[0] * b.prevFwd[0] + rel[1] * b.prevFwd[1] + rel[2] * b.prevFwd[2];
        if (depthPrev < 1e-3f) depthPrev = 1e-3f;
        const float lateralPrevX = rel[0] * b.prevRight[0] + rel[1] * b.prevRight[1] + rel[2] * b.prevRight[2];
        const float lateralPrevY = rel[0] * b.prevUp[0] + rel[1] * b.prevUp[1] + rel[2] * b.prevUp[2];
        const float ndcPrevX = (lateralPrevX / depthPrev) / tanHalfFovX;
        const float ndcPrevY = -(lateralPrevY / depthPrev) / tanHalfFovY;
        // The same conversion the SDK applies: NDC -> UV -> pixels.
        const float mvX = ndcX - ndcPrevX;
        const float mvY = ndcY - ndcPrevY;
        const float pxX = std::fabs(mvX) * 0.5f * static_cast<float>(b.renderWidth);
        const float pxY = std::fabs(mvY) * 0.5f * static_cast<float>(b.renderHeight);
        worst = std::max(worst, std::sqrt(pxX * pxX + pxY * pxY));
    }
    return worst;
}

void recordSyntheticMotionVectors(VkCommandBuffer cmd, const float* camData, int camDataCount, bool reset)
{
    BridgeState& b = g_bridge;
    if (b.synthMvsPipeline && b.synthMvsDescSet && b.synthMvsLayout) {
        const float* pos = &camData[0];
        const float* right = &camData[3];
        const float* up = &camData[6];
        const float* fwd = &camData[9];
        const float fovY = camData[14];
        // Height of the eye above the ground the player stands on (0 = unknown,
        // the constant reference depth is used then).
        const float eyeHeight = (camDataCount > 18) ? camData[18] : 0.0f;
        // Tangent-space half FOV tangents (the shader builds the camera ray
        // from them). The up axis carries the minus sign in the shader because
        // the render target is bottom-up.
        const float tanHalfFovY = (fovY > 0.0f && fovY < 3.14159265f)
            ? std::tan(0.5f * fovY)
            : std::tan(0.5f * kFallbackFovYRadians);
        const float tanHalfFovX = (b.renderHeight > 0)
            ? tanHalfFovY * (static_cast<float>(b.renderWidth) / static_cast<float>(b.renderHeight))
            : tanHalfFovY;

        // Push constants: 10 vec4 (160 bytes), one row per block member.
        float pc[10 * 4] = {};
        const float* rows[4] = {b.prevPos, b.prevRight, b.prevUp, b.prevFwd};
        for (int r = 0; r < 4; ++r) {
            for (int c = 0; c < 3; ++c) {
                pc[r * 4 + c] = rows[r][c];
            }
        }
        for (int i = 0; i < 3; ++i) {
            pc[16 + i] = pos[i];
            pc[20 + i] = right[i];
            pc[24 + i] = up[i];
            pc[28 + i] = fwd[i];
        }
        pc[32] = tanHalfFovX;
        pc[33] = tanHalfFovY;
        pc[34] = kMotionReferenceDepth;
        pc[35] = (b.havePrevPose && !reset) ? 1.0f : 0.0f;
        pc[36] = static_cast<float>(b.renderWidth);
        pc[37] = static_cast<float>(b.renderHeight);
        // Motion vector scale: 1 = the synthetic camera reprojection. The
        // measurement probe can switch it off so the frame interpolation
        // falls back to the optical flow alone - the synthetic vectors only
        // describe the camera motion (constant depth), so they smear the
        // world and drag the HUD along. Only in FG-only mode: the upscaler
        // needs the vectors for its temporal accumulation.
        pc[38] = ((b.probeMask & 16) && b.mode == 0) ? 0.0f : 1.0f;
        // Eye height above the ground (dims.w): the shader derives the
        // distance of the ground pixels from the ground plane instead of
        // using one constant for the whole screen.
        pc[39] = eyeHeight;

        // Storage write: previous layout is discarded (the dispatch covers
        // the whole image), then hand it back to the sampling passes.
        recordImageBarrier(cmd, b.mvsDevice, VK_IMAGE_ASPECT_COLOR_BIT,
                           VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_GENERAL,
                           VK_PIPELINE_STAGE_2_NONE, VK_ACCESS_2_NONE,
                           VK_PIPELINE_STAGE_2_COMPUTE_SHADER_BIT, VK_ACCESS_2_SHADER_WRITE_BIT);
        vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, b.synthMvsPipeline);
        vkCmdPushConstants(cmd, b.synthMvsLayout, VK_SHADER_STAGE_COMPUTE_BIT,
                           0, sizeof(pc), pc);
        vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, b.synthMvsLayout,
                                0, 1, &b.synthMvsDescSet, 0, nullptr);
        vkCmdDispatch(cmd, (b.renderWidth + 7) / 8, (b.renderHeight + 7) / 8, 1);
        recordImageBarrier(cmd, b.mvsDevice, VK_IMAGE_ASPECT_COLOR_BIT,
                           VK_IMAGE_LAYOUT_GENERAL, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                           VK_PIPELINE_STAGE_2_COMPUTE_SHADER_BIT, VK_ACCESS_2_SHADER_WRITE_BIT,
                           VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT, VK_ACCESS_2_SHADER_READ_BIT);

        // Same semantics as the CPU path: the just-recorded frame becomes the
        // previous pose for the next synthesis.
        b.prevPos[0] = pos[0];
        b.prevPos[1] = pos[1];
        b.prevPos[2] = pos[2];
        b.prevRight[0] = right[0];
        b.prevRight[1] = right[1];
        b.prevRight[2] = right[2];
        b.prevUp[0] = up[0];
        b.prevUp[1] = up[1];
        b.prevUp[2] = up[2];
        b.prevFwd[0] = fwd[0];
        b.prevFwd[1] = fwd[1];
        b.prevFwd[2] = fwd[2];
        b.havePrevPose = true;
        return;
    }

    if (!b.synthMvsFailedLogged) {
        logBridge("record: gpu mvs synth unavailable, using cpu loop");
        b.synthMvsFailedLogged = true;
    }
    if (!ensureMvsStaging()) {
        return;
    }
    writeSyntheticMotionVectors(camData, camDataCount, reset);
    recordCopyHostImage(cmd, b.mvsStaging, b.mvsDevice,
                        b.renderWidth, b.renderHeight, VK_FORMAT_R16G16_SFLOAT);
}

void recordImageBarrier(VkCommandBuffer cmd,
                        VkImage image,
                        VkImageAspectFlags aspect,
                        VkImageLayout oldLayout,
                        VkImageLayout newLayout,
                        VkPipelineStageFlags2 srcStage,
                        VkAccessFlags2 srcAccess,
                        VkPipelineStageFlags2 dstStage,
                        VkAccessFlags2 dstAccess)
{
    VkImageMemoryBarrier2 barrier = {};
    barrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2;
    barrier.srcStageMask = srcStage;
    barrier.srcAccessMask = srcAccess;
    barrier.dstStageMask = dstStage;
    barrier.dstAccessMask = dstAccess;
    barrier.oldLayout = oldLayout;
    barrier.newLayout = newLayout;
    barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    barrier.image = image;
    barrier.subresourceRange.aspectMask = aspect;
    barrier.subresourceRange.baseMipLevel = 0;
    barrier.subresourceRange.levelCount = 1;
    barrier.subresourceRange.baseArrayLayer = 0;
    barrier.subresourceRange.layerCount = 1;

    VkDependencyInfo dependency = {};
    dependency.sType = VK_STRUCTURE_TYPE_DEPENDENCY_INFO;
    dependency.imageMemoryBarrierCount = 1;
    dependency.pImageMemoryBarriers = &barrier;
    vkCmdPipelineBarrier2(cmd, &dependency);
}

void recordCopyHostImage(VkCommandBuffer cmd,
                         VkImage staging,
                         VkImage deviceImage,
                         uint32_t width, uint32_t height,
                         VkFormat format)
{
    const VkImageAspectFlags aspect = imageAspectForFormat(format);

    recordImageBarrier(cmd, staging, aspect,
                       VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                       VK_PIPELINE_STAGE_2_HOST_BIT, VK_ACCESS_2_HOST_WRITE_BIT,
                       VK_PIPELINE_STAGE_2_COPY_BIT, VK_ACCESS_2_TRANSFER_READ_BIT);

    recordImageBarrier(cmd, deviceImage, aspect,
                       VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                       VK_PIPELINE_STAGE_2_NONE, VK_ACCESS_2_NONE,
                       VK_PIPELINE_STAGE_2_COPY_BIT, VK_ACCESS_2_TRANSFER_WRITE_BIT);

    VkImageCopy imageCopy = {};
    imageCopy.srcSubresource.aspectMask = aspect;
    imageCopy.srcSubresource.mipLevel = 0;
    imageCopy.srcSubresource.baseArrayLayer = 0;
    imageCopy.srcSubresource.layerCount = 1;
    imageCopy.dstSubresource.aspectMask = aspect;
    imageCopy.dstSubresource.mipLevel = 0;
    imageCopy.dstSubresource.baseArrayLayer = 0;
    imageCopy.dstSubresource.layerCount = 1;
    imageCopy.srcOffset = {0, 0, 0};
    imageCopy.dstOffset = {0, 0, 0};
    imageCopy.extent = {width, height, 1};
    vkCmdCopyImage(cmd, staging, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                   deviceImage, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                   1, &imageCopy);

    recordImageBarrier(cmd, deviceImage, aspect,
                       VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                       VK_PIPELINE_STAGE_2_COPY_BIT, VK_ACCESS_2_TRANSFER_WRITE_BIT,
                       VK_PIPELINE_STAGE_2_COMPUTE_SHADER_BIT, VK_ACCESS_2_SHADER_SAMPLED_READ_BIT);
}

FfxResource resourceFromImage(VkImage image,
                              uint32_t width, uint32_t height,
                              VkFormat format,
                              const wchar_t* name,
                              FfxResourceStates state)
{
    FfxResourceDescription desc = {};
    desc.type = FFX_RESOURCE_TYPE_TEXTURE2D;
    desc.format = ffxGetSurfaceFormatVK(format);
    desc.width = width;
    desc.height = height;
    desc.depth = 1;
    desc.mipCount = 1;
    desc.flags = FFX_RESOURCE_FLAGS_UNDEFINED;
    // The interpolation dispatch binds these images as UAVs; without the UAV
    // usage flag RegisterResourceVK never creates UAV views and the compute
    // job dereferences pResourceViews[0xFFFFFFFF] (uavViewIndex stays -1).
    desc.usage = FFX_RESOURCE_USAGE_UAV;
    return ffxGetResourceVK(reinterpret_cast<void*>(image), desc, name, state);
}

}  // namespace

// ---- public implementation -------------------------------------------------

// Witch patch: present sync-object helpers (definitions near the present
// section; the init/record paths use the same state).
static int ffxfg_create_present_objects(VkDevice device);
static void ffxfg_destroy_present_objects(VkDevice device);

// (Re)allocate the interpolated-output ring: one slot per generated frame
// plus the next write, i.e. the multiplier size. Full allocations only run
// before the first record (no in-flight submissions reference the old
// images); later changes keep the existing slots and the multiplier degrades
// to the slot count instead. Returns false only when the initial allocation
// cannot create a single image.
bool ensureFgOutputImages(BridgeState& b, int multiplier)
{
    int count = multiplier;
    if (count < 2) {
        count = 2;
    }
    if (count > kMaxFgOutputs) {
        count = kMaxFgOutputs;
    }
    if (count == b.fgSlotCount) {
        return true;
    }

    // Reallocations reference live submissions once frames have run: debounce
    // by keeping the existing ring (the multiplier caps itself to it).
    const bool ranFrames = b.frameID != 0 || b.havePrevPose || b.lastFrameOk;
    if (ranFrames) {
        if (b.fgMultiplier > b.fgSlotCount) {
            logBridge("fg multiplier slots resize deferred to next init");
        }
        return true;
    }

    if (b.device) {
        for (int i = 0; i < kMaxFgOutputs; ++i) {
            if (b.fgOutputs[i]) {
                vkDestroyImage(b.device, b.fgOutputs[i], nullptr);
                b.fgOutputs[i] = VK_NULL_HANDLE;
            }
            if (b.fgOutputMemories[i]) {
                vkFreeMemory(b.device, b.fgOutputMemories[i], nullptr);
                b.fgOutputMemories[i] = VK_NULL_HANDLE;
            }
        }
        for (int i = 0; i < count; ++i) {
            if (!createImage2D(b.device, b.physicalDevice, b.fgWidth, b.fgHeight,
                               b.colorFormat, VK_IMAGE_TILING_OPTIMAL,
                               VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_STORAGE_BIT | VK_IMAGE_USAGE_SAMPLED_BIT,
                               VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                               &b.fgOutputs[i], &b.fgOutputMemories[i],
                               nullptr, nullptr)) {
                if (i == 0) {
                    b.fgSlotCount = kMaxFgOutputs;
                    return false;
                }
                count = i;
                logBridge("fg outputs: reduced allocation");
                break;
            }
        }
    }
    b.fgSlotCount = count;
    char message[64];
    snprintf(message, sizeof(message), "fg slots: %d (%.1fMB)", count,
             count * static_cast<double>(b.fgWidth) * b.fgHeight * 4.0 / (1 << 20));
    logBridge(message);
    return true;
}

// Witch patch: build the FSR1 resolve pass. The FSR1 EASU/RCAS shaders
// write their result through an "rgba32f" UAV, so the upscale result has to
// live in a VK_FORMAT_R32G32B32A32_SFLOAT image; the swapchain (and the
// present blit) is 8-bit, so this pass converts the float result into the
// output image the present path copies out.
//
// One descriptor set per output slot: every slot needs its own destination
// image view. Returns false when the pipeline cannot be created (the FSR1
// path then has to be disabled instead of rendering garbage).
bool createFsr1ResolvePipeline(VkDevice device)
{
    BridgeState& b = g_bridge;

    VkShaderModuleCreateInfo moduleInfo = {};
    moduleInfo.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
    moduleInfo.codeSize = kFsr1ResolveSpirvSize;
    moduleInfo.pCode = reinterpret_cast<const uint32_t*>(kFsr1ResolveSpirv);
    if (vkCreateShaderModule(device, &moduleInfo, nullptr, &b.resolveShader) != VK_SUCCESS) {
        b.resolveShader = VK_NULL_HANDLE;
        return false;
    }

    // Binding 0 = the float result (read), binding 1 = the 8-bit output.
    VkDescriptorSetLayoutBinding bindings[2] = {};
    for (int i = 0; i < 2; ++i) {
        bindings[i].binding = static_cast<uint32_t>(i);
        bindings[i].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
        bindings[i].descriptorCount = 1;
        bindings[i].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;
    }
    VkDescriptorSetLayoutCreateInfo setLayoutInfo = {};
    setLayoutInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
    setLayoutInfo.bindingCount = 2;
    setLayoutInfo.pBindings = bindings;
    if (vkCreateDescriptorSetLayout(device, &setLayoutInfo, nullptr,
                                    &b.resolveSetLayout) != VK_SUCCESS) {
        return false;
    }

    // One vec4 push constant: x = width, y = height.
    VkPushConstantRange pushRange = {};
    pushRange.stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;
    pushRange.offset = 0;
    pushRange.size = 4 * sizeof(float);
    VkPipelineLayoutCreateInfo layoutInfo = {};
    layoutInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
    layoutInfo.setLayoutCount = 1;
    layoutInfo.pSetLayouts = &b.resolveSetLayout;
    layoutInfo.pushConstantRangeCount = 1;
    layoutInfo.pPushConstantRanges = &pushRange;
    if (vkCreatePipelineLayout(device, &layoutInfo, nullptr, &b.resolveLayout) != VK_SUCCESS) {
        return false;
    }

    VkComputePipelineCreateInfo pipeInfo = {};
    pipeInfo.sType = VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO;
    pipeInfo.stage.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    pipeInfo.stage.stage = VK_SHADER_STAGE_COMPUTE_BIT;
    pipeInfo.stage.module = b.resolveShader;
    pipeInfo.stage.pName = "main";
    pipeInfo.layout = b.resolveLayout;
    if (vkCreateComputePipelines(device, VK_NULL_HANDLE, 1, &pipeInfo, nullptr,
                                 &b.resolvePipeline) != VK_SUCCESS) {
        b.resolvePipeline = VK_NULL_HANDLE;
        return false;
    }

    // Source view: the float FSR1 result.
    VkImageViewCreateInfo srcViewInfo = {};
    srcViewInfo.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
    srcViewInfo.image = b.fsr1Float;
    srcViewInfo.viewType = VK_IMAGE_VIEW_TYPE_2D;
    srcViewInfo.format = VK_FORMAT_R32G32B32A32_SFLOAT;
    srcViewInfo.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    srcViewInfo.subresourceRange.levelCount = 1;
    srcViewInfo.subresourceRange.layerCount = 1;
    if (vkCreateImageView(device, &srcViewInfo, nullptr, &b.resolveSrcView) != VK_SUCCESS) {
        return false;
    }

    // Destination views: one per output slot (the same format the present
    // path blits from).
    for (int i = 0; i < kMaxOutputs; ++i) {
        VkImageViewCreateInfo dstViewInfo = {};
        dstViewInfo.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
        dstViewInfo.image = b.outputs[i];
        dstViewInfo.viewType = VK_IMAGE_VIEW_TYPE_2D;
        dstViewInfo.format = b.colorFormat;
        dstViewInfo.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        dstViewInfo.subresourceRange.levelCount = 1;
        dstViewInfo.subresourceRange.layerCount = 1;
        if (vkCreateImageView(device, &dstViewInfo, nullptr,
                              &b.resolveDstViews[i]) != VK_SUCCESS) {
            return false;
        }
    }

    VkDescriptorPoolSize poolSize = {};
    poolSize.type = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
    poolSize.descriptorCount = 2 * kMaxOutputs;
    VkDescriptorPoolCreateInfo poolCreateInfo = {};
    poolCreateInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
    poolCreateInfo.maxSets = kMaxOutputs;
    poolCreateInfo.poolSizeCount = 1;
    poolCreateInfo.pPoolSizes = &poolSize;
    if (vkCreateDescriptorPool(device, &poolCreateInfo, nullptr,
                               &b.resolvePool) != VK_SUCCESS) {
        return false;
    }

    VkDescriptorSetAllocateInfo setAllocInfo = {};
    setAllocInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
    setAllocInfo.descriptorPool = b.resolvePool;
    setAllocInfo.descriptorSetCount = kMaxOutputs;
    // pSetLayouts must have descriptorSetCount entries - passing a single
    // layout pointer makes the driver read past the end of the array and
    // dereference a garbage layout (MoltenVK crashed inside
    // vkAllocateDescriptorSets).
    VkDescriptorSetLayout setLayouts[kMaxOutputs] = {};
    for (int i = 0; i < kMaxOutputs; ++i) {
        setLayouts[i] = b.resolveSetLayout;
    }
    setAllocInfo.pSetLayouts = setLayouts;
    if (vkAllocateDescriptorSets(device, &setAllocInfo, b.resolveDescSets) != VK_SUCCESS) {
        return false;
    }

    for (int i = 0; i < kMaxOutputs; ++i) {
        VkDescriptorImageInfo imageInfos[2] = {};
        imageInfos[0].imageLayout = VK_IMAGE_LAYOUT_GENERAL;
        imageInfos[0].imageView = b.resolveSrcView;
        imageInfos[1].imageLayout = VK_IMAGE_LAYOUT_GENERAL;
        imageInfos[1].imageView = b.resolveDstViews[i];
        VkWriteDescriptorSet writes[2] = {};
        for (int k = 0; k < 2; ++k) {
            writes[k].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
            writes[k].dstSet = b.resolveDescSets[i];
            // dstBinding defaults to 0 - without it both writes land on
            // binding 0 and binding 1 (the output image) stays undefined:
            // the resolve pass then wrote nowhere and the screen stayed
            // black.
            writes[k].dstBinding = static_cast<uint32_t>(k);
            writes[k].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
            writes[k].descriptorCount = 1;
            writes[k].pImageInfo = &imageInfos[k];
        }
        vkUpdateDescriptorSets(device, 2, writes, 0, nullptr);
    }
    return true;
}

// Witch patch: resolve the float FSR1 result into the 8-bit output image the
// present path blits into the swapchain.
void recordFsr1Resolve(VkCommandBuffer cmd, int slot)
{
    BridgeState& b = g_bridge;
    if (!b.resolvePipeline || slot < 0 || slot >= kMaxOutputs ||
        !b.resolveDescSets[slot] || !b.outputs[slot] || !b.fsr1Float) {
        return;
    }

    // The float result was written by the FSR1 dispatch: make it readable.
    recordImageBarrier(cmd, b.fsr1Float, VK_IMAGE_ASPECT_COLOR_BIT,
                       VK_IMAGE_LAYOUT_GENERAL, VK_IMAGE_LAYOUT_GENERAL,
                       VK_PIPELINE_STAGE_2_COMPUTE_SHADER_BIT, VK_ACCESS_2_SHADER_WRITE_BIT,
                       VK_PIPELINE_STAGE_2_COMPUTE_SHADER_BIT, VK_ACCESS_2_SHADER_READ_BIT);

    // This pass writes the output image itself (the FFX dispatch does not
    // touch it), so it has to be in GENERAL - the first use still starts
    // from UNDEFINED. Afterwards the present blit restores GENERAL.
    if (!b.outputGeneralInit[slot]) {
        recordImageBarrier(cmd, b.outputs[slot], VK_IMAGE_ASPECT_COLOR_BIT,
                           VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_GENERAL,
                           VK_PIPELINE_STAGE_2_NONE, VK_ACCESS_2_NONE,
                           VK_PIPELINE_STAGE_2_COMPUTE_SHADER_BIT, VK_ACCESS_2_SHADER_WRITE_BIT);
        b.outputGeneralInit[slot] = true;
    }

    vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, b.resolvePipeline);
    vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, b.resolveLayout,
                            0, 1, &b.resolveDescSets[slot], 0, nullptr);
    float dims[4] = {static_cast<float>(b.displayWidth),
                      static_cast<float>(b.displayHeight), 0.0f, 0.0f};
    vkCmdPushConstants(cmd, b.resolveLayout, VK_SHADER_STAGE_COMPUTE_BIT,
                       0, sizeof(dims), dims);
    vkCmdDispatch(cmd, (b.displayWidth + 7) / 8, (b.displayHeight + 7) / 8, 1);

    // Hand the resolved image over to the present path (it copies it out).
    recordImageBarrier(cmd, b.outputs[slot], VK_IMAGE_ASPECT_COLOR_BIT,
                       VK_IMAGE_LAYOUT_GENERAL, VK_IMAGE_LAYOUT_GENERAL,
                       VK_PIPELINE_STAGE_2_COMPUTE_SHADER_BIT, VK_ACCESS_2_SHADER_WRITE_BIT,
                       VK_PIPELINE_STAGE_2_COPY_BIT, VK_ACCESS_2_TRANSFER_READ_BIT);
}

int ffxfg_init(long long vkDeviceHandle,
               long long vkPhysicalDeviceHandle,
               long long vkGetDeviceProcAddrHandle,
               long long vkQueueHandle,
               int queueFamilyIndex,
               int mode,
               int fgEnabled,
               float sharpness,
               int renderWidth, int renderHeight,
               int displayWidth, int displayHeight,
               int colorFormatInt,
               int srcColorFormatInt,
               int depthInverted)
{
    (void)depthInverted;  // TODO: pass through to the context flags

    // Always start from a clean slate: a previous init attempt that failed
    // midway may have left FFX contexts/shared resources behind even though
    // initialized is false, and those must not survive a re-init.
    ffxfg_destroy();

    VkDevice device = reinterpret_cast<VkDevice>(static_cast<uintptr_t>(vkDeviceHandle));
    VkPhysicalDevice physicalDevice = reinterpret_cast<VkPhysicalDevice>(
        static_cast<uintptr_t>(vkPhysicalDeviceHandle));
    PFN_vkGetDeviceProcAddr getDeviceProcAddr = reinterpret_cast<PFN_vkGetDeviceProcAddr>(
        static_cast<uintptr_t>(vkGetDeviceProcAddrHandle));
    VkQueue queue = reinterpret_cast<VkQueue>(static_cast<uintptr_t>(vkQueueHandle));
    VkFormat colorFormat = static_cast<VkFormat>(colorFormatInt);
    VkFormat srcColorFormat = static_cast<VkFormat>(srcColorFormatInt);
    if (srcColorFormat == VK_FORMAT_UNDEFINED) {
        srcColorFormat = colorFormat;
    }

    if (!getDeviceProcAddr) {
        // Fallback: the Vulkan loader (MoltenVK) is already loaded in-process.
        getDeviceProcAddr = reinterpret_cast<PFN_vkGetDeviceProcAddr>(
            dlsym(RTLD_DEFAULT, "vkGetDeviceProcAddr"));
    }

    if (!device || !physicalDevice || !getDeviceProcAddr) {
        logBridge("init: null device handles");
        ffxfg_destroy();
        return -1;
    }

    // Legacy pure-FG mode: FFXFX_MODE_FRAMEGEN means "no upscaler, FG on".
    if (mode == FFXFX_MODE_FRAMEGEN) {
        mode = 0;
        fgEnabled = 1;
    }
    if (mode != 0 && mode != FFXFX_MODE_FSR1 &&
        mode != FFXFX_MODE_FSR2 && mode != FFXFX_MODE_FSR3UPSCALE) {
        logBridge("init: unknown mode");
        ffxfg_destroy();
        return -1;
    }
    if (mode == 0 && fgEnabled == 0) {
        logBridge("init: nothing enabled");
        ffxfg_destroy();
        return -1;
    }

    g_bridge.device = device;
    g_bridge.physicalDevice = physicalDevice;
    g_bridge.queue = queue;
    g_bridge.queueFamilyIndex = static_cast<uint32_t>(queueFamilyIndex);
    g_bridge.mode = mode;
    g_bridge.fg = (fgEnabled != 0);
    g_bridge.sharpness = sharpness < 0.0f ? 0.0f : (sharpness > 1.0f ? 1.0f : sharpness);
    g_bridge.renderWidth = static_cast<uint32_t>(renderWidth);
    g_bridge.renderHeight = static_cast<uint32_t>(renderHeight);
    g_bridge.displayWidth = static_cast<uint32_t>(displayWidth);
    g_bridge.displayHeight = static_cast<uint32_t>(displayHeight);
    // The frame interpolation consumes the upscaler's output when an
    // upscaler is active (display resolution) and the game's own colour
    // texture otherwise (render resolution).
    g_bridge.fgWidth = (mode != 0) ? g_bridge.displayWidth : g_bridge.renderWidth;
    g_bridge.fgHeight = (mode != 0) ? g_bridge.displayHeight : g_bridge.renderHeight;
    g_bridge.colorFormat = colorFormat;
    g_bridge.srcColorFormat = srcColorFormat;

    // Size the scratch from the SDK's own contract instead of a hardcoded
    // guess, and log the computed requirement so a mismatch is visible in
    // the device log (ffxGetInterfaceVK rejects undersized buffers with a
    // generic error code).
    const size_t requiredScratch = ffxGetScratchMemorySizeVK(physicalDevice, 4);
    g_bridge.scratch.resize(requiredScratch);

    {
        char buf[256];
        snprintf(buf, sizeof(buf),
                 "init: dev=%p phys=%p gdpa=%p color=%d src=%d mode=%d fg=%d scratch=%zu",
                 device, physicalDevice, reinterpret_cast<void*>(getDeviceProcAddr),
                 static_cast<int>(colorFormat), static_cast<int>(srcColorFormat),
                 mode, fgEnabled, requiredScratch);
        logBridge(buf);
    }

    VkDeviceContext deviceContext = {};
    deviceContext.vkDevice = device;
    deviceContext.vkPhysicalDevice = physicalDevice;
    deviceContext.vkDeviceProcAddr = getDeviceProcAddr;

    FfxDevice ffxDevice = ffxGetDeviceVK(&deviceContext);
    if (!ffxDevice) {
        logBridge("init: ffxGetDeviceVK failed");
        ffxfg_destroy();
        return -1;
    }

    FfxErrorCode error = ffxGetInterfaceVK(&g_bridge.ffxInterface,
                                           ffxDevice,
                                           g_bridge.scratch.data(),
                                           g_bridge.scratch.size(),
                                           4);
    if (error != FFX_OK) {
        char buf[128];
        snprintf(buf, sizeof(buf), "init: ffxGetInterfaceVK failed (0x%x)",
                 static_cast<unsigned>(error));
        logBridge(buf);
        ffxfg_destroy();
        return -1;
    }

    // Frame interpolation context (frame generation).
    //
    // Witch patch: maxRenderSize has to be the RENDER resolution, not the
    // display size. The SDK's internal frame-interpolation surfaces (the
    // game motion vector field, the optical-flow field, the disocclusion
    // mask) are allocated at maxRenderSize, while the dilated depth and
    // motion vectors the app hands over live at the render resolution. With
    // the display size the two did not match: the interpolation sampled the
    // motion vector field with a wrong factor (RenderSize()/MaxRenderSize())
    // and warped the frame with garbage motion - the generated frames showed
    // double images, smeared blocks and a steadily shrinking picture.
    // This mirrors the SDK's FSR3 composite driver, where the frame
    // interpolation context gets the upscaler's maxRenderSize (the render
    // resolution) and displaySize (the display resolution).
    if (g_bridge.fg) {
        FfxFrameInterpolationContextDescription fiDesc = {};
        fiDesc.flags = 0;
        fiDesc.maxRenderSize.width = g_bridge.renderWidth;
        fiDesc.maxRenderSize.height = g_bridge.renderHeight;
        fiDesc.displaySize.width = g_bridge.fgWidth;
        fiDesc.displaySize.height = g_bridge.fgHeight;
        fiDesc.backBufferFormat = ffxGetSurfaceFormatVK(
            g_bridge.mode != 0 ? colorFormat : srcColorFormat);
        fiDesc.previousInterpolationSourceFormat = fiDesc.backBufferFormat;
        fiDesc.backendInterface = g_bridge.ffxInterface;

        error = ffxFrameInterpolationContextCreate(&g_bridge.fiContext, &fiDesc);
        if (error != FFX_OK) {
            logBridge("init: ffxFrameInterpolationContextCreate failed");
            ffxfg_destroy();
            return -1;
        }
        g_bridge.fiContextValid = true;

        // Optical flow context + shared resources (same wiring as the SDK's
        // FSR3 composite driver: the OF dispatch writes the vectors the FI
        // dispatch consumes).
        FfxOpticalflowContextDescription ofDesc = {};
        ofDesc.backendInterface = g_bridge.ffxInterface;
        ofDesc.resolution.width = g_bridge.fgWidth;
        ofDesc.resolution.height = g_bridge.fgHeight;
        error = ffxOpticalflowContextCreate(&g_bridge.ofContext, &ofDesc);
        if (error != FFX_OK) {
            logBridge("init: ffxOpticalflowContextCreate failed");
            ffxfg_destroy();
            return -1;
        }
        g_bridge.ofContextValid = true;

        const uint32_t ofSharedContextId =
            reinterpret_cast<FfxOpticalflowContext_Private*>(&g_bridge.ofContext)->effectContextId;
        FfxOpticalflowSharedResourceDescriptions ofShared = {};
        error = ffxOpticalflowGetSharedResourceDescriptions(&g_bridge.ofContext, &ofShared);
        if (error != FFX_OK) {
            logBridge("init: ffxOpticalflowGetSharedResourceDescriptions failed");
            ffxfg_destroy();
            return -1;
        }
        FfxCreateResourceDescription ofVec = ofShared.opticalFlowVector;
        error = g_bridge.ffxInterface.fpCreateResource(&g_bridge.ffxInterface, &ofVec, ofSharedContextId, &g_bridge.ofVectorInternal);
        FfxCreateResourceDescription ofScd = ofShared.opticalFlowSCD;
        if (error == FFX_OK) {
            error = g_bridge.ffxInterface.fpCreateResource(&g_bridge.ffxInterface, &ofScd, ofSharedContextId, &g_bridge.ofScdInternal);
        }
        if (error != FFX_OK) {
            logBridge("init: optical flow shared resources failed");
            ffxfg_destroy();
            return -1;
        }
        g_bridge.ofVector = g_bridge.ffxInterface.fpGetResource(&g_bridge.ffxInterface, g_bridge.ofVectorInternal);
        g_bridge.ofScd = g_bridge.ffxInterface.fpGetResource(&g_bridge.ffxInterface, g_bridge.ofScdInternal);
    }

    // Per-mode upscaler context.
    if (mode == FFXFX_MODE_FSR1) {
        FfxFsr1ContextDescription fsr1Desc = {};
        // RCAS has to be enabled in the context flags: the SDK's
        // fsr1Dispatch only runs the sharpening pass when
        // (flags & FFX_FSR1_ENABLE_RCAS) is set, so without it the
        // sharpness slider would silently do nothing for FSR1.
        fsr1Desc.flags = FFX_FSR1_ENABLE_RCAS | FFX_FSR1_RCAS_PASSTHROUGH_ALPHA;
        // The EASU/RCAS shaders write the upscale result through a UAV
        // declared "rgba32f", so the output format must be the float one -
        // a UNORM8 surface does not match the shader's declared format and
        // the dispatch writes garbage (or is rejected by validation).
        fsr1Desc.outputFormat = FFX_SURFACE_FORMAT_R32G32B32A32_FLOAT;
        // The context has to be able to hold the biggest size the render
        // target can reach: the surface is reconfigured when the launcher
        // changes the resolution scale, and a context that was created for
        // the current size rejects every dispatch afterwards ("FSR1 does
        // not work" after a resolution change).
        fsr1Desc.maxRenderSize.width = std::max(g_bridge.renderWidth, g_bridge.displayWidth);
        fsr1Desc.maxRenderSize.height = std::max(g_bridge.renderHeight, g_bridge.displayHeight);
        fsr1Desc.displaySize.width = g_bridge.displayWidth;
        fsr1Desc.displaySize.height = g_bridge.displayHeight;
        fsr1Desc.backendInterface = g_bridge.ffxInterface;

        error = ffxFsr1ContextCreate(&g_bridge.fsr1Context, &fsr1Desc);
        if (error != FFX_OK) {
            logBridge("init: ffxFsr1ContextCreate failed");
            ffxfg_destroy();
            return -1;
        }
        g_bridge.fsr1Valid = true;
    } else if (mode == FFXFX_MODE_FSR2) {
        FfxFsr2ContextDescription fsr2Desc = {};
        fsr2Desc.flags = 0;
        fsr2Desc.maxRenderSize.width = std::max(g_bridge.renderWidth, g_bridge.displayWidth);
        fsr2Desc.maxRenderSize.height = std::max(g_bridge.renderHeight, g_bridge.displayHeight);
        fsr2Desc.displaySize.width = g_bridge.displayWidth;
        fsr2Desc.displaySize.height = g_bridge.displayHeight;
        fsr2Desc.fpMessage = fsr2MessageCallback;
        fsr2Desc.backendInterface = g_bridge.ffxInterface;

        error = ffxFsr2ContextCreate(&g_bridge.fsr2Context, &fsr2Desc);
        if (error != FFX_OK) {
            logBridge("init: ffxFsr2ContextCreate failed");
            ffxfg_destroy();
            return -1;
        }
        g_bridge.fsr2Valid = true;
    } else if (mode == FFXFX_MODE_FSR3UPSCALE) {
        FfxFsr3UpscalerContextDescription fsr3uDesc = {};
        fsr3uDesc.flags = 0;
        fsr3uDesc.maxRenderSize.width = std::max(g_bridge.renderWidth, g_bridge.displayWidth);
        fsr3uDesc.maxRenderSize.height = std::max(g_bridge.renderHeight, g_bridge.displayHeight);
        fsr3uDesc.maxUpscaleSize.width = g_bridge.displayWidth;
        fsr3uDesc.maxUpscaleSize.height = g_bridge.displayHeight;
        fsr3uDesc.fpMessage = fsr3UpscalerMessageCallback;
        fsr3uDesc.backendInterface = g_bridge.ffxInterface;

        error = ffxFsr3UpscalerContextCreate(&g_bridge.fsr3uContext, &fsr3uDesc);
        if (error != FFX_OK) {
            logBridge("init: ffxFsr3UpscalerContextCreate failed");
            ffxfg_destroy();
            return -1;
        }
        g_bridge.fsr3uValid = true;

        // Allocate the shared resources the upscaler dispatch requires
        // (same pattern as the SDK's FSR3 composite driver).
        const uint32_t sharedContextId =
            reinterpret_cast<FfxFsr3UpscalerContext_Private*>(&g_bridge.fsr3uContext)->effectContextId;
        FfxFsr3UpscalerSharedResourceDescriptions sharedDescs = {};
        error = ffxFsr3UpscalerGetSharedResourceDescriptions(&g_bridge.fsr3uContext, &sharedDescs);
        if (error != FFX_OK) {
            logBridge("init: ffxFsr3UpscalerGetSharedResourceDescriptions failed");
            ffxfg_destroy();
            return -1;
        }
        FfxCreateResourceDescription dilD = sharedDescs.dilatedDepth;
        error = g_bridge.ffxInterface.fpCreateResource(&g_bridge.ffxInterface, &dilD, sharedContextId, &g_bridge.fsr3uDilatedDepthInternal);
        FfxCreateResourceDescription dilMVs = sharedDescs.dilatedMotionVectors;
        if (error == FFX_OK) {
            error = g_bridge.ffxInterface.fpCreateResource(&g_bridge.ffxInterface, &dilMVs, sharedContextId, &g_bridge.fsr3uDilatedMVsInternal);
        }
        FfxCreateResourceDescription recND = sharedDescs.reconstructedPrevNearestDepth;
        if (error == FFX_OK) {
            error = g_bridge.ffxInterface.fpCreateResource(&g_bridge.ffxInterface, &recND, sharedContextId, &g_bridge.fsr3uRecPrevNearestDepthInternal);
        }
        if (error != FFX_OK) {
            logBridge("init: fsr3 upscaler shared resources failed");
            ffxfg_destroy();
            return -1;
        }
        g_bridge.fsr3uDilatedDepth = g_bridge.ffxInterface.fpGetResource(&g_bridge.ffxInterface, g_bridge.fsr3uDilatedDepthInternal);
        g_bridge.fsr3uDilatedMVs = g_bridge.ffxInterface.fpGetResource(&g_bridge.ffxInterface, g_bridge.fsr3uDilatedMVsInternal);
        g_bridge.fsr3uRecPrevNearestDepth = g_bridge.ffxInterface.fpGetResource(&g_bridge.ffxInterface, g_bridge.fsr3uRecPrevNearestDepthInternal);
    }

    // Bridge-owned command/sync infrastructure.
    if (queue) {
        VkCommandPoolCreateInfo poolInfo = {};
        poolInfo.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
        poolInfo.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
        poolInfo.queueFamilyIndex = g_bridge.queueFamilyIndex;
        if (vkCreateCommandPool(device, &poolInfo, nullptr, &g_bridge.commandPool) == VK_SUCCESS) {
            VkCommandBufferAllocateInfo cbInfo = {};
            cbInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
            cbInfo.commandPool = g_bridge.commandPool;
            cbInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
            cbInfo.commandBufferCount = BridgeState::kCbRing;
            VkCommandBuffer commandBuffers[BridgeState::kCbRing] = {};
            if (vkAllocateCommandBuffers(device, &cbInfo, commandBuffers) == VK_SUCCESS) {
                for (int i = 0; i < BridgeState::kCbRing; ++i) {
                    g_bridge.upscaleCommandBuffers[i] = commandBuffers[i];
                }
            }

            // Witch patch: the paced-present worker records from its own
            // pool - Vulkan command pools are not internally synchronized,
            // so two threads must never record from the same pool (crashed
            // inside MVKImage::applyImageMemoryBarrier before this).
            VkCommandPoolCreateInfo presentPoolInfo = {};
            presentPoolInfo.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
            presentPoolInfo.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
            presentPoolInfo.queueFamilyIndex = g_bridge.queueFamilyIndex;
            if (vkCreateCommandPool(device, &presentPoolInfo, nullptr,
                                    &g_bridge.presentCommandPool) == VK_SUCCESS) {
                VkCommandBufferAllocateInfo presentCbInfo = {};
                presentCbInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
                presentCbInfo.commandPool = g_bridge.presentCommandPool;
                presentCbInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
                presentCbInfo.commandBufferCount = BridgeState::kCbRing;
                VkCommandBuffer presentBuffers[BridgeState::kCbRing] = {};
                if (vkAllocateCommandBuffers(device, &presentCbInfo, presentBuffers) == VK_SUCCESS) {
                    for (int i = 0; i < BridgeState::kCbRing; ++i) {
                        g_bridge.presentCommandBuffers[i] = presentBuffers[i];
                    }
                }
            }

            VkSemaphoreCreateInfo semInfo = {};
            semInfo.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;
            VkFenceCreateInfo presentFenceInfo = {};
            presentFenceInfo.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
            // Signaled: a slot is usable before its first submission.
            presentFenceInfo.flags = VK_FENCE_CREATE_SIGNALED_BIT;
            for (int i = 0; i < BridgeState::kCbRing; ++i) {
                vkCreateSemaphore(device, &semInfo, nullptr,
                                  &g_bridge.acquireSemaphores[i]);
                vkCreateSemaphore(device, &semInfo, nullptr,
                                  &g_bridge.presentSemaphores[i]);
                vkCreateFence(device, &presentFenceInfo, nullptr,
                              &g_bridge.presentFences[i]);
            }

            // GPU timestamp query pools for the record stages. Created
            // feature-detected: if the pool cannot be created the profiling
            // silently degrades to host-side timings only.
            VkPhysicalDeviceProperties deviceProps = {};
            vkGetPhysicalDeviceProperties(physicalDevice, &deviceProps);
            g_bridge.timestampPeriodNs = deviceProps.limits.timestampPeriod;

            VkQueryPoolCreateInfo qpInfo = {};
            qpInfo.sType = VK_STRUCTURE_TYPE_QUERY_POOL_CREATE_INFO;
            qpInfo.queryType = VK_QUERY_TYPE_TIMESTAMP;
            qpInfo.queryCount = BridgeState::kPerfQueryCount;
            int poolsCreated = 0;
            for (int i = 0; i < BridgeState::kPerfQueryPools; ++i) {
                if (vkCreateQueryPool(device, &qpInfo, nullptr,
                                      &g_bridge.perfQueryPools[i]) != VK_SUCCESS) {
                    g_bridge.perfQueryPools[i] = VK_NULL_HANDLE;
                    break;
                }
                poolsCreated++;
            }
            VkQueueFamilyProperties queueProps[8] = {};
            uint32_t queuePropCount = 8;
            vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, &queuePropCount, queueProps);
            const uint32_t validBits = (g_bridge.queueFamilyIndex < queuePropCount)
                ? queueProps[g_bridge.queueFamilyIndex].timestampValidBits : 0;
            char perfInfo[128];
            snprintf(perfInfo, sizeof(perfInfo),
                     "perf-gpu: period=%.1fns valid=%u pools=%d/8",
                     g_bridge.timestampPeriodNs, validBits, poolsCreated);
            logBridge(perfInfo);
        }
    }

    // Staging images (LINEAR tiling, host visible) + device SRV images.

    // GPU motion-vector synthesis: STORAGE usage lets the compute pass write
    // the field in place (falls back to the staging+copy path when the format
    // cannot back a storage image).
    VkFormatProperties mvsFormatProps = {};
    vkGetPhysicalDeviceFormatProperties(physicalDevice, VK_FORMAT_R16G16_SFLOAT,
                                        &mvsFormatProps);
    const bool mvsStorageOk =
        (mvsFormatProps.optimalTilingFeatures & VK_FORMAT_FEATURE_STORAGE_IMAGE_BIT) != 0;

    // The staging image is only needed by the CPU fallback; with the GPU
    // synth path active the ~11MB host-visible allocation stays out of the
    // process footprint unless the fallback actually fires (it is created
    // lazily by ensureMvsStaging at first use).
    if (!mvsStorageOk &&
        !createImage2D(device, physicalDevice, g_bridge.renderWidth, g_bridge.renderHeight,
                       VK_FORMAT_R16G16_SFLOAT, VK_IMAGE_TILING_LINEAR,
                       VK_IMAGE_USAGE_TRANSFER_SRC_BIT,
                       VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
                       &g_bridge.mvsStaging, &g_bridge.mvsStagingMemory,
                       &g_bridge.mvsStagingMapped, &g_bridge.mvsStagingRowPitch)) {
        logBridge("init: mvs staging failed");
        ffxfg_destroy();
        return -1;
    }

    if (!createImage2D(device, physicalDevice, g_bridge.renderWidth, g_bridge.renderHeight,
                       VK_FORMAT_R16G16_SFLOAT, VK_IMAGE_TILING_OPTIMAL,
                       VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_SAMPLED_BIT |
                           (mvsStorageOk ? VK_IMAGE_USAGE_STORAGE_BIT : 0),
                       VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                       &g_bridge.mvsDevice, &g_bridge.mvsDeviceMemory,
                       nullptr, nullptr)) {
        logBridge("init: mvs device image failed");
        ffxfg_destroy();
        return -1;
    }

    if (!createImage2D(device, physicalDevice, g_bridge.renderWidth, g_bridge.renderHeight,
                       VK_FORMAT_R32_SFLOAT, VK_IMAGE_TILING_LINEAR,
                       VK_IMAGE_USAGE_TRANSFER_SRC_BIT,
                       VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
                       &g_bridge.depthStaging, &g_bridge.depthStagingMemory,
                       &g_bridge.depthStagingMapped, &g_bridge.depthStagingRowPitch)) {
        logBridge("init: depth staging failed");
        ffxfg_destroy();
        return -1;
    }

    if (!createImage2D(device, physicalDevice, g_bridge.renderWidth, g_bridge.renderHeight,
                       VK_FORMAT_R32_SFLOAT, VK_IMAGE_TILING_OPTIMAL,
                       VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_SAMPLED_BIT,
                       VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                       &g_bridge.depthDevice, &g_bridge.depthDeviceMemory,
                       nullptr, nullptr)) {
        logBridge("init: depth device image failed");
        ffxfg_destroy();
        return -1;
    }

    // Witch patch: synthetic motion vector pipeline. The CPU per-pixel loop
    // measured 400-860 ms/frame at full render resolution on A11; the shader
    // is a single dispatch. Handled feature-detected and falls back to the
    // legacy CPU fill when pipeline creation or the storage format fails.
    if (mvsStorageOk) {
        VkShaderModuleCreateInfo moduleInfo = {};
        moduleInfo.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
        moduleInfo.codeSize = kSynthMvsSpirvSize;
        moduleInfo.pCode = reinterpret_cast<const uint32_t*>(kSynthMvsSpirv);
        if (vkCreateShaderModule(device, &moduleInfo, nullptr,
                                 &g_bridge.synthMvsShader) == VK_SUCCESS) {
            VkDescriptorSetLayoutBinding mvsBinding = {};
            mvsBinding.binding = 0;
            mvsBinding.descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
            mvsBinding.descriptorCount = 1;
            mvsBinding.stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;
            VkDescriptorSetLayoutCreateInfo setLayoutInfo = {};
            setLayoutInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
            setLayoutInfo.bindingCount = 1;
            setLayoutInfo.pBindings = &mvsBinding;
            if (vkCreateDescriptorSetLayout(device, &setLayoutInfo, nullptr,
                                            &g_bridge.synthMvsSetLayout) == VK_SUCCESS) {
                // 10 vec4 worlds, 160 bytes.
                VkPushConstantRange pushRange = {};
                pushRange.stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;
                pushRange.offset = 0;
                pushRange.size = 10 * sizeof(float) * 4;
                VkPipelineLayoutCreateInfo layoutInfo = {};
                layoutInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
                layoutInfo.setLayoutCount = 1;
                layoutInfo.pSetLayouts = &g_bridge.synthMvsSetLayout;
                layoutInfo.pushConstantRangeCount = 1;
                layoutInfo.pPushConstantRanges = &pushRange;
                if (vkCreatePipelineLayout(device, &layoutInfo, nullptr,
                                           &g_bridge.synthMvsLayout) == VK_SUCCESS) {
                    VkComputePipelineCreateInfo pipeInfo = {};
                    pipeInfo.sType = VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO;
                    pipeInfo.stage.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
                    pipeInfo.stage.stage = VK_SHADER_STAGE_COMPUTE_BIT;
                    pipeInfo.stage.module = g_bridge.synthMvsShader;
                    pipeInfo.stage.pName = "main";
                    pipeInfo.layout = g_bridge.synthMvsLayout;
                    if (vkCreateComputePipelines(device, VK_NULL_HANDLE, 1, &pipeInfo,
                                                 nullptr,
                                                 &g_bridge.synthMvsPipeline) != VK_SUCCESS) {
                        g_bridge.synthMvsPipeline = VK_NULL_HANDLE;
                    }
                }
            }
        }
        if (g_bridge.synthMvsPipeline) {
            VkImageViewCreateInfo viewInfo = {};
            viewInfo.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
            viewInfo.image = g_bridge.mvsDevice;
            viewInfo.viewType = VK_IMAGE_VIEW_TYPE_2D;
            viewInfo.format = VK_FORMAT_R16G16_SFLOAT;
            viewInfo.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
            viewInfo.subresourceRange.levelCount = 1;
            viewInfo.subresourceRange.layerCount = 1;
            if (vkCreateImageView(device, &viewInfo, nullptr,
                                  &g_bridge.synthMvsView) == VK_SUCCESS) {
                VkDescriptorPoolSize poolSize = {};
                poolSize.type = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
                poolSize.descriptorCount = 1;
                VkDescriptorPoolCreateInfo poolCreateInfo = {};
                poolCreateInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
                poolCreateInfo.maxSets = 1;
                poolCreateInfo.poolSizeCount = 1;
                poolCreateInfo.pPoolSizes = &poolSize;
                if (vkCreateDescriptorPool(device, &poolCreateInfo, nullptr,
                                           &g_bridge.synthMvsPool) == VK_SUCCESS) {
                    VkDescriptorSetAllocateInfo setAllocInfo = {};
                    setAllocInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
                    setAllocInfo.descriptorPool = g_bridge.synthMvsPool;
                    setAllocInfo.descriptorSetCount = 1;
                    setAllocInfo.pSetLayouts = &g_bridge.synthMvsSetLayout;
                    if (vkAllocateDescriptorSets(device, &setAllocInfo,
                                                 &g_bridge.synthMvsDescSet) == VK_SUCCESS) {
                        VkDescriptorImageInfo imageInfo = {};
                        imageInfo.imageLayout = VK_IMAGE_LAYOUT_GENERAL;
                        imageInfo.imageView = g_bridge.synthMvsView;
                        VkWriteDescriptorSet write = {};
                        write.sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
                        write.dstSet = g_bridge.synthMvsDescSet;
                        write.descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
                        write.descriptorCount = 1;
                        write.pImageInfo = &imageInfo;
                        vkUpdateDescriptorSets(device, 1, &write, 0, nullptr);
                    }
                }
            }
        }
        if (!g_bridge.synthMvsPipeline) {
            logBridge("init: gpu mvs synthesis unavailable, cpu fallback");
        }
    }

    // FI dilate/reconstruct UAVs. The interpolation pipelines write these as
    // storage images, so they need STORAGE usage; TRANSFER_DST lets the
    // layout warm-up copy below run if needed.
    if (!createImage2D(device, physicalDevice, g_bridge.renderWidth, g_bridge.renderHeight,
                       VK_FORMAT_R32_SFLOAT, VK_IMAGE_TILING_OPTIMAL,
                       VK_IMAGE_USAGE_STORAGE_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT,
                       VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                       &g_bridge.dilatedDepthDevice, &g_bridge.dilatedDepthDeviceMemory,
                       nullptr, nullptr)) {
        logBridge("init: dilated depth image failed");
        ffxfg_destroy();
        return -1;
    }
    if (!createImage2D(device, physicalDevice, g_bridge.renderWidth, g_bridge.renderHeight,
                       VK_FORMAT_R16G16_SFLOAT, VK_IMAGE_TILING_OPTIMAL,
                       VK_IMAGE_USAGE_STORAGE_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT,
                       VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                       &g_bridge.dilatedMvsDevice, &g_bridge.dilatedMvsDeviceMemory,
                       nullptr, nullptr)) {
        logBridge("init: dilated mvs image failed");
        ffxfg_destroy();
        return -1;
    }
    if (!createImage2D(device, physicalDevice, g_bridge.renderWidth, g_bridge.renderHeight,
                       VK_FORMAT_R32_UINT, VK_IMAGE_TILING_OPTIMAL,
                       VK_IMAGE_USAGE_STORAGE_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT,
                       VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                       &g_bridge.recDepthDevice, &g_bridge.recDepthDeviceMemory,
                       nullptr, nullptr)) {
        logBridge("init: rec depth image failed");
        ffxfg_destroy();
        return -1;
    }

    // Fill the constant depth with the far plane value.
    {
        const size_t floatsPerRow = static_cast<size_t>(g_bridge.depthStagingRowPitch / sizeof(float));
        for (uint32_t y = 0; y < g_bridge.renderHeight; ++y) {
            float* line = reinterpret_cast<float*>(
                reinterpret_cast<uint8_t*>(g_bridge.depthStagingMapped) + y * g_bridge.depthStagingRowPitch);
            for (uint32_t x = 0; x < g_bridge.renderWidth && x < floatsPerRow; ++x) {
                line[x] = 0.999999f;  // far plane (non-inverted depth)
            }
        }
    }

    // Transition the FI UAVs to GENERAL once: the interpolation pipelines
    // write them as storage images, and FFX's barrier tracking starts from
    // the state claimed at registration (UNORDERED_ACCESS), which never
    // emits the initial UNDEFINED -> GENERAL transition itself.
    //
    // The constant depth is uploaded here as well: its content never
    // changes, so re-copying it every frame only burned a full-render-
    // resolution transfer (about 4 MB/frame at 1324x744). It is left in
    // SHADER_READ_ONLY_OPTIMAL, which is the layout FFX expects for a
    // FFX_RESOURCE_STATE_COMPUTE_READ resource.
    if (g_bridge.commandPool) {
        VkCommandBuffer warmup = VK_NULL_HANDLE;
        VkCommandBufferAllocateInfo wi = {};
        wi.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
        wi.commandPool = g_bridge.commandPool;
        wi.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
        wi.commandBufferCount = 1;
        if (vkAllocateCommandBuffers(device, &wi, &warmup) == VK_SUCCESS) {
            VkCommandBufferBeginInfo bi = {};
            bi.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
            bi.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
            if (vkBeginCommandBuffer(warmup, &bi) == VK_SUCCESS) {
                recordImageBarrier(warmup, g_bridge.dilatedDepthDevice, VK_IMAGE_ASPECT_COLOR_BIT,
                                   VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_GENERAL,
                                   VK_PIPELINE_STAGE_2_NONE, VK_ACCESS_2_NONE,
                                   VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT,
                                   VK_ACCESS_2_MEMORY_READ_BIT | VK_ACCESS_2_MEMORY_WRITE_BIT);
                recordImageBarrier(warmup, g_bridge.dilatedMvsDevice, VK_IMAGE_ASPECT_COLOR_BIT,
                                   VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_GENERAL,
                                   VK_PIPELINE_STAGE_2_NONE, VK_ACCESS_2_NONE,
                                   VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT,
                                   VK_ACCESS_2_MEMORY_READ_BIT | VK_ACCESS_2_MEMORY_WRITE_BIT);
                recordImageBarrier(warmup, g_bridge.recDepthDevice, VK_IMAGE_ASPECT_COLOR_BIT,
                                   VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_GENERAL,
                                   VK_PIPELINE_STAGE_2_NONE, VK_ACCESS_2_NONE,
                                   VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT,
                                   VK_ACCESS_2_MEMORY_READ_BIT | VK_ACCESS_2_MEMORY_WRITE_BIT);
                recordCopyHostImage(warmup, g_bridge.depthStaging, g_bridge.depthDevice,
                                    g_bridge.renderWidth, g_bridge.renderHeight, VK_FORMAT_R32_SFLOAT);
                vkEndCommandBuffer(warmup);
                VkSubmitInfo si = {};
                si.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
                si.commandBufferCount = 1;
                si.pCommandBuffers = &warmup;
                if (vkQueueSubmit(g_bridge.queue, 1, &si, VK_NULL_HANDLE) == VK_SUCCESS) {
                    vkQueueWaitIdle(g_bridge.queue);
                }
            }
            vkFreeCommandBuffers(device, g_bridge.commandPool, 1, &warmup);
        }
    }

    // Outputs: upscaler results (mode != 0) and interpolated results (fg).
    if (g_bridge.mode != 0) {
        for (int i = 0; i < kMaxOutputs; ++i) {
            if (!createImage2D(device, physicalDevice, g_bridge.displayWidth, g_bridge.displayHeight,
                               colorFormat, VK_IMAGE_TILING_OPTIMAL,
                               VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_STORAGE_BIT | VK_IMAGE_USAGE_SAMPLED_BIT,
                               VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                               &g_bridge.outputs[i], &g_bridge.outputMemories[i],
                               nullptr, nullptr)) {
                logBridge("init: output image failed");
                ffxfg_destroy();
                return -1;
            }
        }
    }
    // Witch patch: FSR1 writes its upscale result through an "rgba32f" UAV
    // (the EASU/RCAS shaders declare the output as rgba32f), so the result
    // needs a float image of its own; the resolve pass converts it into the
    // 8-bit output image the present path blits into the swapchain.
    if (g_bridge.mode == FFXFX_MODE_FSR1) {
        if (!createImage2D(device, physicalDevice, g_bridge.displayWidth, g_bridge.displayHeight,
                           VK_FORMAT_R32G32B32A32_SFLOAT, VK_IMAGE_TILING_OPTIMAL,
                           VK_IMAGE_USAGE_STORAGE_BIT | VK_IMAGE_USAGE_SAMPLED_BIT,
                           VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                           &g_bridge.fsr1Float, &g_bridge.fsr1FloatMemory,
                           nullptr, nullptr)) {
            logBridge("init: fsr1 float image failed");
            ffxfg_destroy();
            return -1;
        }
        if (!createFsr1ResolvePipeline(device)) {
            logBridge("init: fsr1 resolve pipeline failed");
            ffxfg_destroy();
            return -1;
        }
    }
    if (g_bridge.fg) {
        if (!ensureFgOutputImages(g_bridge, g_bridge.fgMultiplier)) {
            logBridge("init: fg output image failed");
            ffxfg_destroy();
            return -1;
        }
    }

    g_bridge.initialized = true;
    g_bridge.enabled = true;
    g_bridge.frameID = 0;
    g_bridge.outputSlot = 0;
    g_bridge.fgOutputSlot = 0;
    g_bridge.havePrevPose = false;
    g_bridge.lastFrameOk = false;
    for (int i = 0; i < kMaxOutputs; ++i) {
        g_bridge.outputGeneralInit[i] = false;
    }

    logBridge(g_bridge.fg && g_bridge.mode != 0 ? "init: ok (upscaler + framegen combo)"
              : g_bridge.fg ? "init: ok (framegen only)"
              : "init: ok (upscaler only)");

    // The upscaler only upscales when the game's colour target is SMALLER
    // than the swapchain. Both follow the game's framebuffer size, so with
    // the default configuration the upscale factor is 1:1 and the feature
    // degenerates into a temporal filter (accumulation + RCAS) at the
    // framebuffer resolution. Say so explicitly instead of leaving the user
    // wondering why the picture is soft.
    if (g_bridge.mode != 0) {
        char info[192];
        snprintf(info, sizeof(info),
                 "init: render=%ux%u display=%ux%u upscale=%.2fx%s",
                 g_bridge.renderWidth, g_bridge.renderHeight,
                 g_bridge.displayWidth, g_bridge.displayHeight,
                 (g_bridge.displayWidth && g_bridge.renderWidth)
                     ? (double) g_bridge.displayWidth / (double) g_bridge.renderWidth : 1.0,
                 (g_bridge.displayWidth <= g_bridge.renderWidth)
                     ? "  (1:1 - the upscaler only acts as a temporal filter; "
                       "the render target and the swapchain have the same size)"
                     : "");
        logBridge(info);
    }
    return 0;
}

void ffxfg_destroy(void)
{
    BridgeState& b = g_bridge;

    if (b.fiContextValid) {
        ffxFrameInterpolationContextDestroy(&b.fiContext);
        b.fiContextValid = false;
    }
    if (b.ofContextValid) {
        ffxOpticalflowContextDestroy(&b.ofContext);
        b.ofContextValid = false;
        b.ofVector = {};
        b.ofScd = {};
        b.ofVectorInternal = {};
        b.ofScdInternal = {};
    }
    if (b.fsr1Valid) {
        ffxFsr1ContextDestroy(&b.fsr1Context);
        b.fsr1Valid = false;
    }
    if (b.fsr2Valid) {
        ffxFsr2ContextDestroy(&b.fsr2Context);
        b.fsr2Valid = false;
    }
    if (b.fsr3uValid) {
        ffxFsr3UpscalerContextDestroy(&b.fsr3uContext);
        b.fsr3uValid = false;
    }
    b.fsr3uDilatedDepth = {};
    b.fsr3uDilatedMVs = {};
    b.fsr3uRecPrevNearestDepth = {};
    b.fsr3uDilatedDepthInternal = {};
    b.fsr3uDilatedMVsInternal = {};
    b.fsr3uRecPrevNearestDepthInternal = {};
    if (b.ffxInterface.device) {
        if (b.ffxInterface.fpDestroyBackendContext) {
            b.ffxInterface.fpDestroyBackendContext(&b.ffxInterface, 0);
        }
        b.ffxInterface.device = nullptr;
    }

    VkDevice device = b.device;
    if (device) {
        if (b.synthMvsDescSet) {
            b.synthMvsDescSet = VK_NULL_HANDLE;
        }
        if (b.synthMvsPool) {
            vkDestroyDescriptorPool(device, b.synthMvsPool, nullptr);
            b.synthMvsPool = VK_NULL_HANDLE;
        }
        if (b.synthMvsView) {
            vkDestroyImageView(device, b.synthMvsView, nullptr);
            b.synthMvsView = VK_NULL_HANDLE;
        }
        if (b.synthMvsPipeline) {
            vkDestroyPipeline(device, b.synthMvsPipeline, nullptr);
            b.synthMvsPipeline = VK_NULL_HANDLE;
        }
        if (b.synthMvsLayout) {
            vkDestroyPipelineLayout(device, b.synthMvsLayout, nullptr);
            b.synthMvsLayout = VK_NULL_HANDLE;
        }
        if (b.synthMvsSetLayout) {
            vkDestroyDescriptorSetLayout(device, b.synthMvsSetLayout, nullptr);
            b.synthMvsSetLayout = VK_NULL_HANDLE;
        }
        if (b.synthMvsShader) {
            vkDestroyShaderModule(device, b.synthMvsShader, nullptr);
            b.synthMvsShader = VK_NULL_HANDLE;
        }
        // Witch patch: the FSR1 resolve pass.
        if (b.resolvePool) {
            vkDestroyDescriptorPool(device, b.resolvePool, nullptr);
            b.resolvePool = VK_NULL_HANDLE;
        }
        for (int i = 0; i < kMaxOutputs; ++i) {
            b.resolveDescSets[i] = VK_NULL_HANDLE;
            if (b.resolveDstViews[i]) {
                vkDestroyImageView(device, b.resolveDstViews[i], nullptr);
                b.resolveDstViews[i] = VK_NULL_HANDLE;
            }
        }
        if (b.resolveSrcView) {
            vkDestroyImageView(device, b.resolveSrcView, nullptr);
            b.resolveSrcView = VK_NULL_HANDLE;
        }
        if (b.resolvePipeline) {
            vkDestroyPipeline(device, b.resolvePipeline, nullptr);
            b.resolvePipeline = VK_NULL_HANDLE;
        }
        if (b.resolveLayout) {
            vkDestroyPipelineLayout(device, b.resolveLayout, nullptr);
            b.resolveLayout = VK_NULL_HANDLE;
        }
        if (b.resolveSetLayout) {
            vkDestroyDescriptorSetLayout(device, b.resolveSetLayout, nullptr);
            b.resolveSetLayout = VK_NULL_HANDLE;
        }
        if (b.resolveShader) {
            vkDestroyShaderModule(device, b.resolveShader, nullptr);
            b.resolveShader = VK_NULL_HANDLE;
        }
        for (int i = 0; i < BridgeState::kPerfQueryPools; ++i) {
            if (b.perfQueryPools[i]) {
                vkDestroyQueryPool(device, b.perfQueryPools[i], nullptr);
                b.perfQueryPools[i] = VK_NULL_HANDLE;
            }
        }
        if (b.mvsStagingMapped) {
            vkUnmapMemory(device, b.mvsStagingMemory);
            b.mvsStagingMapped = nullptr;
        }
        if (b.depthStagingMapped) {
            vkUnmapMemory(device, b.depthStagingMemory);
            b.depthStagingMapped = nullptr;
        }
        // Witch patch: the present path submits to the game's queue, so drain
        // it before destroying the sync objects it may still reference.
        if (b.queue) {
            vkQueueWaitIdle(b.queue);
        }
        for (int i = 0; i < BridgeState::kCbRing; ++i) {
            if (b.acquireSemaphores[i]) {
                vkDestroySemaphore(device, b.acquireSemaphores[i], nullptr);
                b.acquireSemaphores[i] = VK_NULL_HANDLE;
            }
            if (b.presentSemaphores[i]) {
                vkDestroySemaphore(device, b.presentSemaphores[i], nullptr);
                b.presentSemaphores[i] = VK_NULL_HANDLE;
            }
            if (b.presentFences[i]) {
                vkDestroyFence(device, b.presentFences[i], nullptr);
                b.presentFences[i] = VK_NULL_HANDLE;
            }
        }
        b.swapchainImages.clear();
        b.cachedSwapchain = VK_NULL_HANDLE;
        b.presentBroken = false;
        b.resetPresentObjects = false;
        if (b.commandPool) {
            vkDestroyCommandPool(device, b.commandPool, nullptr);
            b.commandPool = VK_NULL_HANDLE;
            for (int i = 0; i < BridgeState::kCbRing; ++i) {
                b.upscaleCommandBuffers[i] = VK_NULL_HANDLE;
                b.presentCommandBuffers[i] = VK_NULL_HANDLE;
            }
            b.upscaleCbIndex = 0;
            b.presentCbIndex = 0;
            b.lastRecordedCb = 0;
        }
        if (b.presentCommandPool) {
            vkDestroyCommandPool(device, b.presentCommandPool, nullptr);
            b.presentCommandPool = VK_NULL_HANDLE;
        }
        vkDestroyImage(device, b.mvsStaging, nullptr);
        vkFreeMemory(device, b.mvsStagingMemory, nullptr);
        vkDestroyImage(device, b.mvsDevice, nullptr);
        vkFreeMemory(device, b.mvsDeviceMemory, nullptr);
        vkDestroyImage(device, b.depthStaging, nullptr);
        vkFreeMemory(device, b.depthStagingMemory, nullptr);
        vkDestroyImage(device, b.depthDevice, nullptr);
        vkFreeMemory(device, b.depthDeviceMemory, nullptr);
        vkDestroyImage(device, b.dilatedDepthDevice, nullptr);
        vkFreeMemory(device, b.dilatedDepthDeviceMemory, nullptr);
        vkDestroyImage(device, b.dilatedMvsDevice, nullptr);
        vkFreeMemory(device, b.dilatedMvsDeviceMemory, nullptr);
        vkDestroyImage(device, b.recDepthDevice, nullptr);
        vkFreeMemory(device, b.recDepthDeviceMemory, nullptr);
        for (int i = 0; i < kMaxOutputs; ++i) {
            vkDestroyImage(device, b.outputs[i], nullptr);
            vkFreeMemory(device, b.outputMemories[i], nullptr);
            b.outputs[i] = VK_NULL_HANDLE;
            b.outputMemories[i] = VK_NULL_HANDLE;
            b.outputGeneralInit[i] = false;
        }
        vkDestroyImage(device, b.fsr1Float, nullptr);
        vkFreeMemory(device, b.fsr1FloatMemory, nullptr);
        b.fsr1Float = VK_NULL_HANDLE;
        b.fsr1FloatMemory = VK_NULL_HANDLE;
        b.fsr1FloatGeneralInit = false;
        for (int i = 0; i < kMaxFgOutputs; ++i) {
            vkDestroyImage(device, b.fgOutputs[i], nullptr);
            vkFreeMemory(device, b.fgOutputMemories[i], nullptr);
            b.fgOutputs[i] = VK_NULL_HANDLE;
            b.fgOutputMemories[i] = VK_NULL_HANDLE;
        }
        b.mvsStaging = VK_NULL_HANDLE;
        b.mvsStagingMemory = VK_NULL_HANDLE;
        b.mvsDevice = VK_NULL_HANDLE;
        b.mvsDeviceMemory = VK_NULL_HANDLE;
        b.depthStaging = VK_NULL_HANDLE;
        b.depthStagingMemory = VK_NULL_HANDLE;
        b.depthDevice = VK_NULL_HANDLE;
        b.depthDeviceMemory = VK_NULL_HANDLE;
        b.dilatedDepthDevice = VK_NULL_HANDLE;
        b.dilatedDepthDeviceMemory = VK_NULL_HANDLE;
        b.dilatedMvsDevice = VK_NULL_HANDLE;
        b.dilatedMvsDeviceMemory = VK_NULL_HANDLE;
        b.recDepthDevice = VK_NULL_HANDLE;
        b.recDepthDeviceMemory = VK_NULL_HANDLE;
    }
    // The FFX interface no longer references scratch after the backend
    // context is destroyed; return the (potentially several hundred MB)
    // vector to the CRT instead of keeping it alive until the next init.
    b.scratch.clear();
    b.scratch.shrink_to_fit();
    b.device = VK_NULL_HANDLE;
    b.physicalDevice = VK_NULL_HANDLE;
    b.queue = VK_NULL_HANDLE;
    b.mode = 0;
    b.fg = false;
    b.sharpness = 0.0f;
    b.initialized = false;
    b.lastFrameOk = false;
}

int ffxfg_isSupported(void)
{
    return g_bridge.initialized ? 1 : 0;
}

long long ffxfg_get_output_image(int slot)
{
    if (slot < 0 || slot >= kMaxOutputs) {
        return 0;
    }
    return static_cast<long long>(reinterpret_cast<uintptr_t>(g_bridge.outputs[slot]));
}

long long ffxfg_get_fg_output_image(int slot)
{
    if (slot < 0 || slot >= kMaxOutputs) {
        return 0;
    }
    return static_cast<long long>(reinterpret_cast<uintptr_t>(g_bridge.fgOutputs[slot]));
}

int ffxfg_output_slot_count(void)
{
    return kMaxOutputs;
}

// Witch patch: fold a frame event into an EMA rate for the FPS widget.
static void ffxfg_note_frame_time(double& lastTime, float& emaFps)
{
    using namespace std::chrono;
    double now = duration_cast<duration<double>>(steady_clock::now().time_since_epoch()).count();
    if (lastTime > 0.0) {
        double dt = now - lastTime;
        if (dt > 0.0) {
            float inst = static_cast<float>(1.0 / dt);
            emaFps = emaFps > 0.0f ? (0.9f * emaFps + 0.1f * inst) : inst;
        }
    }
    lastTime = now;
}

int ffxfg_set_fg_multiplier(int multiplier)
{
    BridgeState& b = g_bridge;
    if (multiplier < 2 || multiplier > kMaxFgOutputs) {
        return -1;
    }
    b.fgMultiplier = multiplier;
    // Only allocate the interpolated-output ring when frame generation is
    // actually running: the multiplier is a configuration value that is
    // pushed even with FG off, and the ring costs ~14 MB on a phone.
    if (b.fg) {
        ensureFgOutputImages(b, multiplier);
    }
    return 0;
}

int ffxfg_set_probe(int probeMask)
{
    BridgeState& b = g_bridge;
    b.probeMask = probeMask & 0x1f;
    char info[96];
    snprintf(info, sizeof(info), "probe mask set: 0x%x", b.probeMask);
    logBridge(info);
    return b.probeMask;
}

int ffxfg_pending_fg_slot_count(void)
{
    BridgeState& b = g_bridge;
    if (!b.initialized || !b.enabled || !b.fg || b.fgBatchCount == 0) {
        return 0;
    }
    return static_cast<int>(b.fgBatchCount);
}

int ffxfg_pending_fg_slot(int index)
{
    BridgeState& b = g_bridge;
    if (!b.initialized || !b.enabled || !b.fg || index < 0 ||
        static_cast<uint32_t>(index) >= b.fgBatchCount) {
        return -1;
    }
    return static_cast<int>((b.fgBatchBase + static_cast<uint32_t>(index)) % b.fgSlotCount);
}

void ffxfg_get_frame_stats(float* outFps)
{
    BridgeState& b = g_bridge;
    if (outFps) {
        outFps[0] = b.statRenderFps;
        outFps[1] = b.statGenFps;
    }
}

int ffxfg_last_frame_ok(void)
{
    return g_bridge.lastFrameOk ? 1 : 0;
}

int ffxfg_record_frame(long long vkCommandBufferHandle,
                       long long srcColorImageHandle,
                       int srcWidth, int srcHeight,
                       const float* camData, int camDataCount,
                       int reset)
{
    BridgeState& b = g_bridge;
    b.lastFrameOk = false;

    // Legacy pure-FG path only: in combo mode the record_upscale path owns
    // both dispatches.
    if (!b.initialized || !b.enabled || !b.fiContextValid || !b.fg || b.mode != 0) {
        return -1;
    }
    if (!vkCommandBufferHandle || !srcColorImageHandle || !camData || camDataCount < 16) {
        return -1;
    }

    VkCommandBuffer cmd = reinterpret_cast<VkCommandBuffer>(
        static_cast<uintptr_t>(vkCommandBufferHandle));
    VkImage srcColor = reinterpret_cast<VkImage>(static_cast<uintptr_t>(srcColorImageHandle));

    recordSyntheticMotionVectors(cmd, camData, camDataCount, reset != 0);

    // The constant depth was uploaded once during init; its content never
    // changes, so there is nothing to copy here.

    // Register the current frame's resources.
    FfxResource presentColor = resourceFromImage(
        srcColor, static_cast<uint32_t>(srcWidth), static_cast<uint32_t>(srcHeight),
        b.srcColorFormat, L"PresentColor", FFX_RESOURCE_STATE_COMPUTE_READ);
    FfxResource mvsResource = resourceFromImage(
        b.mvsDevice, b.renderWidth, b.renderHeight,
        VK_FORMAT_R16G16_SFLOAT, L"MotionVectors", FFX_RESOURCE_STATE_COMPUTE_READ);
    FfxResource depthResource = resourceFromImage(
        b.depthDevice, b.renderWidth, b.renderHeight,
        VK_FORMAT_R32_SFLOAT, L"Depth", FFX_RESOURCE_STATE_COMPUTE_READ);

    FfxFrameInterpolationPrepareDescription prepare = {};
    prepare.flags = 0;
    prepare.commandList = ffxGetCommandListVK(cmd);
    prepare.renderSize.width = b.renderWidth;
    prepare.renderSize.height = b.renderHeight;
    // The jitter the agent applied to the game's projection: the SDK cancels
    // the jitter difference in the motion vectors with it.
    prepare.jitterOffset.x = (camDataCount > 16) ? camData[16] : 0.0f;
    prepare.jitterOffset.y = (camDataCount > 17) ? camData[17] : 0.0f;
    // The synthetic motion vectors hold NDC displacements (x right, y up,
    // forward). The interpolation divides this scale by the render size and
    // adds the result to the current UV, so it expects the backward vector
    // (prev - cur) in UV space: -size/2 on x and +size/2 on y.
    prepare.motionVectorScale.x = -0.5f * static_cast<float>(b.renderWidth);
    prepare.motionVectorScale.y = 0.5f * static_cast<float>(b.renderHeight);
    prepare.frameTimeDelta = camData[15];
    prepare.cameraNear = camData[12];
    prepare.cameraFar = camData[13];
    prepare.viewSpaceToMetersFactor = 1.0f;
    prepare.cameraFovAngleVertical = camData[14];
    prepare.depth = depthResource;
    prepare.motionVectors = mvsResource;
    // The interpolation pipelines write the dilated data into these
    // app-provided UAVs every frame (same contract as the SDK's FSR3
    // composite driver). Leaving them empty registers NULL identifiers and
    // the "Clear Reconstructed Previous Nearest Depth" job then executes
    // against an empty resource slot (vkCmdFillBuffer with a null buffer).
    prepare.dilatedDepth = resourceFromImage(
        b.dilatedDepthDevice, b.renderWidth, b.renderHeight,
        VK_FORMAT_R32_SFLOAT, L"DilatedDepth", FFX_RESOURCE_STATE_UNORDERED_ACCESS);
    prepare.dilatedMotionVectors = resourceFromImage(
        b.dilatedMvsDevice, b.renderWidth, b.renderHeight,
        VK_FORMAT_R16G16_SFLOAT, L"DilatedMotionVectors", FFX_RESOURCE_STATE_UNORDERED_ACCESS);
    prepare.reconstructedPrevDepth = resourceFromImage(
        b.recDepthDevice, b.renderWidth, b.renderHeight,
        VK_FORMAT_R32_UINT, L"ReconstructedPrevNearestDepth", FFX_RESOURCE_STATE_UNORDERED_ACCESS);
    prepare.frameID = b.frameID;
    prepare.cameraPosition[0] = camData[0];
    prepare.cameraPosition[1] = camData[1];
    prepare.cameraPosition[2] = camData[2];
    prepare.cameraUp[0] = camData[6];
    prepare.cameraUp[1] = camData[7];
    prepare.cameraUp[2] = camData[8];
    prepare.cameraRight[0] = camData[3];
    prepare.cameraRight[1] = camData[4];
    prepare.cameraRight[2] = camData[5];
    prepare.cameraForward[0] = camData[9];
    prepare.cameraForward[1] = camData[10];
    prepare.cameraForward[2] = camData[11];

    FfxErrorCode error = ffxFrameInterpolationPrepare(&b.fiContext, &prepare);
    if (error != FFX_OK) {
        logDispatchError("fg prepare", error);
        return -1;
    }

    FfxFrameInterpolationDispatchDescription dispatch = {};
    dispatch.flags = 0;
    dispatch.commandList = ffxGetCommandListVK(cmd);
    dispatch.displaySize.width = b.fgWidth;
    dispatch.displaySize.height = b.fgHeight;
    dispatch.renderSize.width = b.renderWidth;
    dispatch.renderSize.height = b.renderHeight;
    dispatch.currentBackBuffer = presentColor;
    dispatch.output = resourceFromImage(
        b.fgOutputs[b.fgOutputSlot], b.fgWidth, b.fgHeight,
        b.colorFormat, L"InterpolatedOutput", FFX_RESOURCE_STATE_UNORDERED_ACCESS);
    // Optical flow must run before the interpolation dispatch and feed it
    // (composite driver contract); empty OF resources wedge the GPU.
    {
        FfxOpticalflowDispatchDescription ofDispatch = {};
        ofDispatch.commandList = ffxGetCommandListVK(cmd);
        ofDispatch.color = presentColor;
        ofDispatch.reset = (reset != 0);
        ofDispatch.backbufferTransferFunction = 0; // SDR
        ofDispatch.minMaxLuminance.x = 0.0001f;
        ofDispatch.minMaxLuminance.y = 1.0f;
        ofDispatch.opticalFlowVector = b.ofVector;
        ofDispatch.opticalFlowSCD = b.ofScd;
        error = ffxOpticalflowContextDispatch(&b.ofContext, &ofDispatch);
        if (error != FFX_OK) {
            logDispatchError("fg of", error);
            return -1;
        }
    }
    dispatch.opticalFlowVector = b.ofVector;
    dispatch.opticalFlowSceneChangeDetection = b.ofScd;
    dispatch.opticalFlowBlockSize = 8;
    dispatch.opticalFlowScale.x = 1.0f / static_cast<float>(b.fgWidth);
    dispatch.opticalFlowScale.y = 1.0f / static_cast<float>(b.fgHeight);
    dispatch.cameraNear = camData[12];
    dispatch.cameraFar = camData[13];
    dispatch.cameraFovAngleVertical = camData[14];
    dispatch.viewSpaceToMetersFactor = 1.0f;
    dispatch.frameTimeDelta = camData[15];
    dispatch.reset = (reset != 0);
    // Same resources the prepare registered: the interpolation passes read
    // the dilated depth/MVs and the previous reconstructed depth from them.
    dispatch.dilatedDepth = prepare.dilatedDepth;
    dispatch.dilatedMotionVectors = prepare.dilatedMotionVectors;
    dispatch.reconstructedPrevDepth = prepare.reconstructedPrevDepth;
    dispatch.interpolationRect.left = 0;
    dispatch.interpolationRect.top = 0;
    dispatch.interpolationRect.width = static_cast<int32_t>(b.fgWidth);
    dispatch.interpolationRect.height = static_cast<int32_t>(b.fgHeight);

    // Witch patch: frame generation multiplier. The optical flow pass above
    // computed the displacement between the two real frames once; each
    // sub-frame dispatch re-scales it to its own phase and writes its own
    // output slot.
    const int genCap = std::min(b.fgMultiplier, b.fgSlotCount);
    const int genCount = std::max(1, std::min(kMaxFgOutputs, genCap) - 1);
    b.fgBatchBase = b.fgOutputSlot;
    b.fgBatchCount = 0;
    for (int k = 0; k < genCount; ++k) {
        dispatch.interpolationPhase =
            static_cast<float>(k + 1) / static_cast<float>(genCount + 1);
        dispatch.flags = (k + 1 < genCount)
            ? FFX_FRAMEINTERPOLATION_DISPATCH_INTERMEDIATE_SUBFRAME : 0u;
        dispatch.output = resourceFromImage(
            b.fgOutputs[b.fgOutputSlot], b.fgWidth, b.fgHeight,
            b.colorFormat, L"InterpolatedOutput", FFX_RESOURCE_STATE_UNORDERED_ACCESS);
        dispatch.frameID = b.frameID;
        error = ffxFrameInterpolationDispatch(&b.fiContext, &dispatch);
        b.frameID++;
        if (error != FFX_OK) {
            logDispatchError("fg fi", error);
            return -1;
        }
        b.fgOutputSlot = (b.fgOutputSlot + 1) % b.fgSlotCount;
        b.fgBatchCount++;
        b.statGenFrames.fetch_add(1, std::memory_order_relaxed);
    }
    ffxfg_note_frame_time(b.statLastRealTime, b.statRenderFps);
    b.statRealFrames.fetch_add(1, std::memory_order_relaxed);

    b.lastFrameOk = true;
    return static_cast<int>((b.fgOutputSlot + b.fgSlotCount - 1) % b.fgSlotCount);
}

long long ffxfg_record_upscale(long long srcColorImageHandle,
                               int srcWidth, int srcHeight,
                               long long swapchainImageHandle,
                               int srcColorFormatInt,
                               const float* camData, int camDataCount,
                               int reset)
{
    BridgeState& b = g_bridge;
    b.lastFrameOk = false;

    if (!b.initialized || !b.enabled || !b.commandPool || !b.upscaleCommandBuffers[0]) {
        return -1;
    }
    if (!srcColorImageHandle || !camData || camDataCount < 16) {
        return -1;
    }
    // Sub-pixel jitter of the frame, in render-resolution pixels. The agent
    // skews the game's projection matrix by the same amount, so the scene is
    // really rendered at a different sub-pixel position every frame - that is
    // what lets the FidelityFX temporal accumulation resolve the aliasing
    // instead of just blurring it.
    const float jitterX = (camDataCount > 16) ? camData[16] : 0.0f;
    const float jitterY = (camDataCount > 17) ? camData[17] : 0.0f;
    if (b.mode != 0 && !swapchainImageHandle) {
        return -1;
    }

    const VkFormat srcColorFormat =
        srcColorFormatInt > 0 ? static_cast<VkFormat>(srcColorFormatInt)
                              : b.srcColorFormat;
    const bool needsMotionData = (b.mode != FFXFX_MODE_FSR1) || b.fg;
    const bool needsBlit = (b.mode != 0 && swapchainImageHandle != 0);

    // Performance instrumentation: measure the host-side cost of each stage
    // (motion synthesis, data copies and each FFX dispatch's record overhead)
    // so the device log pinpoints what dominates the frame budget.
    const auto perfStart = std::chrono::steady_clock::now();
    auto stageStart = perfStart;

    VkCommandBuffer cmd = b.upscaleCommandBuffers[b.upscaleCbIndex];
    b.lastRecordedCb = 0;
    VkImage srcColor = reinterpret_cast<VkImage>(static_cast<uintptr_t>(srcColorImageHandle));
    VkImage swapchainImage = reinterpret_cast<VkImage>(static_cast<uintptr_t>(swapchainImageHandle));

    VkCommandBufferBeginInfo beginInfo = {};
    beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    vkResetCommandBuffer(cmd, 0);
    if (vkBeginCommandBuffer(cmd, &beginInfo) != VK_SUCCESS) {
        return -1;
    }

    // GPU stage timestamps: consume the pool this record reuses (its markers
    // are kPerfQueryPools records old, long finished by now), reset it, then
    // start the trace. Every stage owns a slot: 1 = motion copies, 2 =
    // upscaler dispatch, 3 = optical flow, 4 = FI prepare, 5 = FI dispatch,
    // 6 = record end.
    const int perfPoolSlot =
        static_cast<int>(b.perfRecordHandle++ % BridgeState::kPerfQueryPools);
    VkQueryPool perfPool = b.perfQueryPools[perfPoolSlot];
    auto writeTs = [&](unsigned slot) {
        if (perfPool) {
            vkCmdWriteTimestamp(cmd, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
                                perfPool, slot);
        }
    };
    if (perfPool) {
        foldPerfTimestamps(b, perfPoolSlot);
        vkResetQueryPool(b.device, perfPool, 0, BridgeState::kPerfQueryCount);
        writeTs(0);
    }

    if (needsBlit) {
        // The game's own blit already ran (image is PRESENT_SRC); flip it back to
        // TRANSFER_DST, replace its contents entirely, then flip to PRESENT_SRC.
        recordImageBarrier(cmd, swapchainImage, VK_IMAGE_ASPECT_COLOR_BIT,
                           VK_IMAGE_LAYOUT_PRESENT_SRC_KHR, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                           VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT, VK_ACCESS_2_MEMORY_READ_BIT | VK_ACCESS_2_MEMORY_WRITE_BIT,
                           VK_PIPELINE_STAGE_2_COPY_BIT, VK_ACCESS_2_TRANSFER_WRITE_BIT);
    }

    if (needsMotionData) {
        recordSyntheticMotionVectors(cmd, camData, camDataCount, reset != 0);
        // The constant depth was uploaded once during init (its content never
        // changes), so there is nothing to copy here.
        writeTs(1);
        perfNote(&b.perfCopies, perfMsSince(stageStart));
        stageStart = std::chrono::steady_clock::now();
    }

    // No upscaler to dispatch in pure-FG mode; the placeholder previously
    // left INVALID_ARGUMENT here, which the check below then turned into a
    // spurious failure before the frame generation section could ever run.
    FfxErrorCode error = FFX_OK;

    // ---- upscaler dispatch (mode != 0) ----
    if (b.mode != 0) {
        // Witch patch: FSR1 writes its result through an "rgba32f" UAV, so
        // the dispatch output has to be the float image; the resolve pass
        // below converts it into the 8-bit output image the present path
        // blits into the swapchain.
        const bool fsr1FloatPath = (b.mode == FFXFX_MODE_FSR1);
        if (!fsr1FloatPath && !b.outputGeneralInit[b.outputSlot]) {
            // The FFX dispatch writes the output image as a UAV. FFX's
            // barrier tracking claims the UAV state at registration and
            // never emits the initial transition, so the first write has to
            // bring the image from UNDEFINED to GENERAL.
            recordImageBarrier(cmd, b.outputs[b.outputSlot], VK_IMAGE_ASPECT_COLOR_BIT,
                               VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_GENERAL,
                               VK_PIPELINE_STAGE_2_NONE, VK_ACCESS_2_NONE,
                               VK_PIPELINE_STAGE_2_COMPUTE_SHADER_BIT,
                               VK_ACCESS_2_SHADER_WRITE_BIT);
            b.outputGeneralInit[b.outputSlot] = true;
        }
        FfxResource output = fsr1FloatPath
            ? resourceFromImage(b.fsr1Float, b.displayWidth, b.displayHeight,
                                VK_FORMAT_R32G32B32A32_SFLOAT, L"UpscaleOutputFloat",
                                FFX_RESOURCE_STATE_UNORDERED_ACCESS)
            : resourceFromImage(b.outputs[b.outputSlot], b.displayWidth, b.displayHeight,
                                b.colorFormat, L"UpscaleOutput", FFX_RESOURCE_STATE_UNORDERED_ACCESS);

        if (b.mode == FFXFX_MODE_FSR1) {
            if (!b.fsr1FloatGeneralInit) {
                // The FSR1 dispatch writes the float image as a UAV; FFX
                // never emits the initial transition, so the first write
                // has to bring the image from UNDEFINED to GENERAL.
                recordImageBarrier(cmd, b.fsr1Float, VK_IMAGE_ASPECT_COLOR_BIT,
                                   VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_GENERAL,
                                   VK_PIPELINE_STAGE_2_NONE, VK_ACCESS_2_NONE,
                                   VK_PIPELINE_STAGE_2_COMPUTE_SHADER_BIT,
                                   VK_ACCESS_2_SHADER_WRITE_BIT);
                b.fsr1FloatGeneralInit = true;
            }
            FfxFsr1DispatchDescription dispatch = {};
            dispatch.commandList = ffxGetCommandListVK(cmd);
            dispatch.color = resourceFromImage(
                srcColor, static_cast<uint32_t>(srcWidth), static_cast<uint32_t>(srcHeight),
                srcColorFormat, L"Color", FFX_RESOURCE_STATE_COMPUTE_READ);
            dispatch.output = output;
            dispatch.renderSize.width = static_cast<uint32_t>(srcWidth);
            dispatch.renderSize.height = static_cast<uint32_t>(srcHeight);
            dispatch.enableSharpening = (b.sharpness > 0.001f);
            dispatch.sharpness = b.sharpness;
            error = ffxFsr1ContextDispatch(&b.fsr1Context, &dispatch);
            if (error == FFX_OK) {
                recordFsr1Resolve(cmd, b.outputSlot);
            }
        } else if (b.mode == FFXFX_MODE_FSR2) {
            FfxFsr2DispatchDescription dispatch = {};
            dispatch.commandList = ffxGetCommandListVK(cmd);
            dispatch.color = resourceFromImage(
                srcColor, static_cast<uint32_t>(srcWidth), static_cast<uint32_t>(srcHeight),
                srcColorFormat, L"Color", FFX_RESOURCE_STATE_COMPUTE_READ);
            dispatch.depth = resourceFromImage(
                b.depthDevice, b.renderWidth, b.renderHeight,
                VK_FORMAT_R32_SFLOAT, L"Depth", FFX_RESOURCE_STATE_COMPUTE_READ);
            dispatch.motionVectors = resourceFromImage(
                b.mvsDevice, b.renderWidth, b.renderHeight,
                VK_FORMAT_R16G16_SFLOAT, L"MotionVectors", FFX_RESOURCE_STATE_COMPUTE_READ);
            dispatch.output = output;
            // The jitter the agent applied to the game's projection.
            dispatch.jitterOffset.x = jitterX;
            dispatch.jitterOffset.y = jitterY;
            // The synthetic motion vectors hold NDC displacements (x right,
            // y up, forward). The SDK divides this scale by the render size
            // and adds the result to the current UV, so it expects the
            // backward vector (prev - cur) in UV space: -size/2 on x and
            // +size/2 on y.
            dispatch.motionVectorScale.x = -0.5f * static_cast<float>(srcWidth);
            dispatch.motionVectorScale.y = 0.5f * static_cast<float>(srcHeight);
            dispatch.renderSize.width = static_cast<uint32_t>(srcWidth);
            dispatch.renderSize.height = static_cast<uint32_t>(srcHeight);
            dispatch.enableSharpening = (b.sharpness > 0.001f);
            dispatch.sharpness = b.sharpness;
            dispatch.frameTimeDelta = camData[15];
            dispatch.preExposure = 1.0f;
            dispatch.reset = (reset != 0);
            dispatch.cameraNear = camData[12];
            dispatch.cameraFar = camData[13];
            dispatch.cameraFovAngleVertical = camData[14];
            dispatch.viewSpaceToMetersFactor = 1.0f;
            error = ffxFsr2ContextDispatch(&b.fsr2Context, &dispatch);
        } else if (b.mode == FFXFX_MODE_FSR3UPSCALE) {
            FfxFsr3UpscalerDispatchDescription dispatch = {};
            dispatch.commandList = ffxGetCommandListVK(cmd);
            dispatch.color = resourceFromImage(
                srcColor, static_cast<uint32_t>(srcWidth), static_cast<uint32_t>(srcHeight),
                srcColorFormat, L"Color", FFX_RESOURCE_STATE_COMPUTE_READ);
            dispatch.depth = resourceFromImage(
                b.depthDevice, b.renderWidth, b.renderHeight,
                VK_FORMAT_R32_SFLOAT, L"Depth", FFX_RESOURCE_STATE_COMPUTE_READ);
            dispatch.motionVectors = resourceFromImage(
                b.mvsDevice, b.renderWidth, b.renderHeight,
                VK_FORMAT_R16G16_SFLOAT, L"MotionVectors", FFX_RESOURCE_STATE_COMPUTE_READ);
            dispatch.dilatedDepth = b.fsr3uDilatedDepth;
            dispatch.dilatedMotionVectors = b.fsr3uDilatedMVs;
            dispatch.reconstructedPrevNearestDepth = b.fsr3uRecPrevNearestDepth;
            dispatch.output = output;
            // The jitter the agent applied to the game's projection.
            dispatch.jitterOffset.x = jitterX;
            dispatch.jitterOffset.y = jitterY;
            // Same convention as the FSR2 path (the upscaler forwards the
            // scale to its internal FSR2 dispatch, which divides it by the
            // render size).
            dispatch.motionVectorScale.x = -0.5f * static_cast<float>(srcWidth);
            dispatch.motionVectorScale.y = 0.5f * static_cast<float>(srcHeight);
            dispatch.renderSize.width = static_cast<uint32_t>(srcWidth);
            dispatch.renderSize.height = static_cast<uint32_t>(srcHeight);
            dispatch.upscaleSize.width = b.displayWidth;
            dispatch.upscaleSize.height = b.displayHeight;
            dispatch.enableSharpening = (b.sharpness > 0.001f);
            dispatch.sharpness = b.sharpness;
            dispatch.frameTimeDelta = camData[15];
            dispatch.preExposure = 1.0f;
            dispatch.reset = (reset != 0);
            dispatch.cameraNear = camData[12];
            dispatch.cameraFar = camData[13];
            dispatch.cameraFovAngleVertical = camData[14];
            dispatch.viewSpaceToMetersFactor = 1.0f;
            dispatch.flags = 0;
            error = ffxFsr3UpscalerContextDispatch(&b.fsr3uContext, &dispatch);
        }
        perfNote(&b.perfUpscale, perfMsSince(stageStart));
        stageStart = std::chrono::steady_clock::now();
        writeTs(2);
    }

    if (error != FFX_OK) {
        logDispatchError("upscale", error);
        vkEndCommandBuffer(cmd);
        return -1;
    }

    // Blit the upscaled output over the whole swapchain image.
    if (needsBlit) {
        recordImageBarrier(cmd, b.outputs[b.outputSlot], VK_IMAGE_ASPECT_COLOR_BIT,
                           VK_IMAGE_LAYOUT_GENERAL, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                           VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT, VK_ACCESS_2_MEMORY_WRITE_BIT,
                           VK_PIPELINE_STAGE_2_COPY_BIT, VK_ACCESS_2_TRANSFER_READ_BIT);

        VkImageBlit blit = {};
        blit.srcSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        blit.srcSubresource.layerCount = 1;
        blit.srcOffsets[0] = {0, 0, 0};
        blit.srcOffsets[1] = {static_cast<int32_t>(b.displayWidth), static_cast<int32_t>(b.displayHeight), 1};
        // Mirror vertically: the game's render texture content is bottom-up
        // and the game's own blit flips Y (dstOffsets[0].y = h,
        // dstOffsets[1].y = 0) when presenting - ours must do the same.
        blit.dstSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
        blit.dstSubresource.layerCount = 1;
        blit.dstOffsets[0] = {0, static_cast<int32_t>(b.displayHeight), 0};
        blit.dstOffsets[1] = {static_cast<int32_t>(b.displayWidth), 0, 1};
        vkCmdBlitImage(cmd, b.outputs[b.outputSlot], VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                       swapchainImage, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                       1, &blit, VK_FILTER_LINEAR);

        recordImageBarrier(cmd, swapchainImage, VK_IMAGE_ASPECT_COLOR_BIT,
                           VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
                           VK_PIPELINE_STAGE_2_COPY_BIT, VK_ACCESS_2_TRANSFER_WRITE_BIT,
                           VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT, VK_ACCESS_2_NONE);

        // Restore the upscaled output to GENERAL so the next frame's dispatch
        // (which declares this image as a UAV) sees the layout it expects.
        recordImageBarrier(cmd, b.outputs[b.outputSlot], VK_IMAGE_ASPECT_COLOR_BIT,
                           VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, VK_IMAGE_LAYOUT_GENERAL,
                           VK_PIPELINE_STAGE_2_COPY_BIT, VK_ACCESS_2_TRANSFER_READ_BIT,
                           VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT, VK_ACCESS_2_MEMORY_READ_BIT | VK_ACCESS_2_MEMORY_WRITE_BIT);
    }

    // ---- frame interpolation (fg) ----
    // Combo: FI consumes the upscaler's display-res output (kept as the real
    // frame in the swapchain); pure FG: FI consumes the game's full-res back
    // buffer. The interpolated result lands in fgOutputs[] and is presented
    // by ffxfg_present_interpolated() before the real frame (FIFO).
    if (b.fg) {
        FfxResource presentColor;
        bool fgSourceUsable = true;
        if (b.mode != 0) {
            // The needsBlit section restored the upscaled output to GENERAL,
            // which is the layout the FI dispatch reads it in.
            presentColor = resourceFromImage(
                b.outputs[b.outputSlot], b.fgWidth, b.fgHeight,
                b.colorFormat, L"PresentColor", FFX_RESOURCE_STATE_COMPUTE_READ);
        } else {
            // Pure FG: the source is the game's own colour texture. The FI
            // context (and its internal previous-frame copy) was created for
            // the render resolution, so a source of a different size would
            // only partially update that history and the interpolation would
            // blend against stale pixels. Skip the generated frames instead.
            fgSourceUsable =
                (static_cast<uint32_t>(srcWidth) == b.fgWidth &&
                 static_cast<uint32_t>(srcHeight) == b.fgHeight);
            if (!fgSourceUsable) {
                if (!(b.probeAnnounced & 32)) {
                    b.probeAnnounced |= 32;
                    logBridge("fg: source size changed, generated frames paused");
                }
                // No generated frame for this pass; make sure the present
                // hook does not re-present the previous batch.
                b.fgBatchBase = b.fgOutputSlot;
                b.fgBatchCount = 0;
            }
            presentColor = resourceFromImage(
                srcColor, static_cast<uint32_t>(srcWidth), static_cast<uint32_t>(srcHeight),
                srcColorFormat, L"PresentColor", FFX_RESOURCE_STATE_COMPUTE_READ);
        }
        FfxResource mvsResource = resourceFromImage(
            b.mvsDevice, b.renderWidth, b.renderHeight,
            VK_FORMAT_R16G16_SFLOAT, L"MotionVectors", FFX_RESOURCE_STATE_COMPUTE_READ);
        FfxResource depthResource = resourceFromImage(
            b.depthDevice, b.renderWidth, b.renderHeight,
            VK_FORMAT_R32_SFLOAT, L"Depth", FFX_RESOURCE_STATE_COMPUTE_READ);

        // Optical flow must run before the interpolation dispatch and feed
        // it (composite driver contract). Running the FI with empty
        // optical-flow resources binds empty views and wedges the GPU.
        FfxOpticalflowDispatchDescription ofDispatch = {};
        ofDispatch.commandList = ffxGetCommandListVK(cmd);
        ofDispatch.color = presentColor;
        ofDispatch.reset = (reset != 0);
        ofDispatch.backbufferTransferFunction = 0; // SDR
        ofDispatch.minMaxLuminance.x = 0.0001f;
        ofDispatch.minMaxLuminance.y = 1.0f;
        ofDispatch.opticalFlowVector = b.ofVector;
        ofDispatch.opticalFlowSCD = b.ofScd;
        // Witch patch: the optical flow must be computed for the frame that
        // is going to be interpolated. The old A11 experiment ran it only
        // every other record and re-used the previous flow field - that
        // field describes the motion of an older frame pair, so the
        // interpolation warped the frame with the wrong motion. The
        // interpolated image showed up as double images (ghosting) and
        // smeared blocks. The flow is therefore either computed for this
        // frame or the interpolation is skipped entirely; a stale flow
        // field must never reach the interpolation dispatch.
        //
        // Probe bit 1 skips the OF (and with it the interpolation).
        bool skipOf = !fgSourceUsable;
        if (b.probeMask & 1) {
            if (!(b.probeAnnounced & 1)) {
                b.probeAnnounced |= 1;
                logBridge("perf: OF skipped by probe");
            }
            skipOf = true;
        }
        if (!skipOf) {
            error = ffxOpticalflowContextDispatch(&b.ofContext, &ofDispatch);
            if (error != FFX_OK) {
                logDispatchError("fg of", error);
                vkEndCommandBuffer(cmd);
                return -1;
            }
        }
        perfNote(&b.perfOf, perfMsSince(stageStart));
        stageStart = std::chrono::steady_clock::now();
        writeTs(3);

        FfxFrameInterpolationPrepareDescription prepare = {};
        prepare.flags = 0;
        prepare.commandList = ffxGetCommandListVK(cmd);
        prepare.renderSize.width = b.renderWidth;
        prepare.renderSize.height = b.renderHeight;
        // The jitter the agent applied to the game's projection: the SDK
        // cancels the jitter difference in the motion vectors with it.
        prepare.jitterOffset.x = jitterX;
        prepare.jitterOffset.y = jitterY;
        // Same convention as the legacy prepare path: NDC displacements have
        // to become a backward UV vector.
        prepare.motionVectorScale.x = -0.5f * static_cast<float>(b.renderWidth);
        prepare.motionVectorScale.y = 0.5f * static_cast<float>(b.renderHeight);
        prepare.frameTimeDelta = camData[15];
        prepare.cameraNear = camData[12];
        prepare.cameraFar = camData[13];
        prepare.viewSpaceToMetersFactor = 1.0f;
        prepare.cameraFovAngleVertical = camData[14];
        prepare.depth = depthResource;
        prepare.motionVectors = mvsResource;
        // App-provided UAVs the interpolation pipelines write every frame
        // (same contract as the SDK's FSR3 composite driver). Empty values
        // register NULL identifiers and the reconstruct-depth clear job then
        // executes against an empty resource slot.
        prepare.dilatedDepth = resourceFromImage(
            b.dilatedDepthDevice, b.renderWidth, b.renderHeight,
            VK_FORMAT_R32_SFLOAT, L"DilatedDepth", FFX_RESOURCE_STATE_UNORDERED_ACCESS);
        prepare.dilatedMotionVectors = resourceFromImage(
            b.dilatedMvsDevice, b.renderWidth, b.renderHeight,
            VK_FORMAT_R16G16_SFLOAT, L"DilatedMotionVectors", FFX_RESOURCE_STATE_UNORDERED_ACCESS);
        prepare.reconstructedPrevDepth = resourceFromImage(
            b.recDepthDevice, b.renderWidth, b.renderHeight,
            VK_FORMAT_R32_UINT, L"ReconstructedPrevNearestDepth", FFX_RESOURCE_STATE_UNORDERED_ACCESS);
        prepare.frameID = b.frameID;
        prepare.cameraPosition[0] = camData[0];
        prepare.cameraPosition[1] = camData[1];
        prepare.cameraPosition[2] = camData[2];
        prepare.cameraUp[0] = camData[6];
        prepare.cameraUp[1] = camData[7];
        prepare.cameraUp[2] = camData[8];
        prepare.cameraRight[0] = camData[3];
        prepare.cameraRight[1] = camData[4];
        prepare.cameraRight[2] = camData[5];
        prepare.cameraForward[0] = camData[9];
        prepare.cameraForward[1] = camData[10];
        prepare.cameraForward[2] = camData[11];
        if (fgSourceUsable) {
            error = ffxFrameInterpolationPrepare(&b.fiContext, &prepare);
            if (error != FFX_OK) {
                logDispatchError("fg prepare", error);
            }
        }
        perfNote(&b.perfPrepare, perfMsSince(stageStart));
        stageStart = std::chrono::steady_clock::now();
        writeTs(4);
        if (error == FFX_OK && fgSourceUsable) {
            FfxFrameInterpolationDispatchDescription dispatch = {};
            dispatch.flags = 0;
            dispatch.commandList = ffxGetCommandListVK(cmd);
            dispatch.displaySize.width = b.fgWidth;
            dispatch.displaySize.height = b.fgHeight;
            dispatch.renderSize.width = b.renderWidth;
            dispatch.renderSize.height = b.renderHeight;
            dispatch.currentBackBuffer = presentColor;
            dispatch.opticalFlowVector = b.ofVector;
            dispatch.opticalFlowSceneChangeDetection = b.ofScd;
            dispatch.opticalFlowBlockSize = 8;
            dispatch.opticalFlowScale.x = 1.0f / static_cast<float>(b.fgWidth);
            dispatch.opticalFlowScale.y = 1.0f / static_cast<float>(b.fgHeight);
            dispatch.cameraNear = camData[12];
            dispatch.cameraFar = camData[13];
            dispatch.cameraFovAngleVertical = camData[14];
            dispatch.viewSpaceToMetersFactor = 1.0f;
            dispatch.frameTimeDelta = camData[15];
            dispatch.reset = (reset != 0);
            dispatch.dilatedDepth = prepare.dilatedDepth;
            dispatch.dilatedMotionVectors = prepare.dilatedMotionVectors;
            dispatch.reconstructedPrevDepth = prepare.reconstructedPrevDepth;
            dispatch.interpolationRect.left = 0;
            dispatch.interpolationRect.top = 0;
            dispatch.interpolationRect.width = static_cast<int32_t>(b.fgWidth);
            dispatch.interpolationRect.height = static_cast<int32_t>(b.fgHeight);

            // Witch patch: frame generation multiplier, same loop as the
            // legacy FG path. Optical flow ran once above; each sub-frame
            // re-scales the flow to its own phase.
            const int genCap = std::min(b.fgMultiplier, b.fgSlotCount);
            int genCount = std::max(1, std::min(kMaxFgOutputs, genCap) - 1);
            if (skipOf) {
                // No fresh flow field for this frame: interpolating anyway
                // would warp the image with a stale motion vector.
                genCount = 0;
            }
            if (b.probeMask & 4) {
                genCount = 0;
                if (!(b.probeAnnounced & 4)) {
                    b.probeAnnounced |= 4;
                    logBridge("perf: interpolation skipped by probe (gen=0)");
                }
            }
            // Generated frames are presented synchronously from the game's
            // present() call, so the previous batch was already consumed.
            b.fgBatchBase = b.fgOutputSlot;
            b.fgBatchCount = 0;
            for (int k = 0; k < genCount; ++k) {
                dispatch.interpolationPhase =
                    static_cast<float>(k + 1) / static_cast<float>(genCount + 1);
                dispatch.flags = (k + 1 < genCount)
                    ? FFX_FRAMEINTERPOLATION_DISPATCH_INTERMEDIATE_SUBFRAME : 0u;
                dispatch.output = resourceFromImage(
                    b.fgOutputs[b.fgOutputSlot], b.fgWidth, b.fgHeight,
                    b.colorFormat, L"InterpolatedOutput", FFX_RESOURCE_STATE_UNORDERED_ACCESS);
                dispatch.frameID = b.frameID;
                error = ffxFrameInterpolationDispatch(&b.fiContext, &dispatch);
                b.frameID++;
                if (error != FFX_OK) {
                    break;
                }
                b.fgOutputSlot = (b.fgOutputSlot + 1) % b.fgSlotCount;
                b.fgBatchCount++;
                b.statGenFrames.fetch_add(1, std::memory_order_relaxed);
            }
            perfNote(&b.perfFi, perfMsSince(stageStart));
            writeTs(5);
        }
        if (error != FFX_OK) {
            logDispatchError("fg fi", error);
            vkEndCommandBuffer(cmd);
            return -1;
        }
    }

    // The FPS widget counts real frames in every mode: the upscaler-only
    // path used to update the counter inside the frame-generation branch
    // only, so the widget showed 0 fps whenever frame generation was off.
    ffxfg_note_frame_time(b.statLastRealTime, b.statRenderFps);
    b.statRealFrames.fetch_add(1, std::memory_order_relaxed);

    if (perfPool) {
        writeTs(6);
    }

    if (vkEndCommandBuffer(cmd) != VK_SUCCESS) {
        return -1;
    }
    if (perfPool) {
        b.perfPoolWritten[perfPoolSlot] = true;
    }

    perfNote(&b.perfTotal, perfMsSince(perfStart));
    b.perfLogCounter++;
    if (b.perfLogCounter % BridgeState::kPerfLogFrames == 0) {
        char message[288];
        snprintf(message, sizeof(message),
                 "perf: copy=%.1f up=%.1f of=%.1f prep=%.1f fi=%.1f total=%.1fms"
                 " gpu: copy=%.1f up=%.1f of=%.1f prep=%.1f fi=%.1f total=%.1fms"
                 " present=%.1f fps=%.1f gen=%.1f (fgx=%d) mv=%.1fpx skip=%llu",
                 b.perfCopies.emaMs, b.perfUpscale.emaMs, b.perfOf.emaMs,
                 b.perfPrepare.emaMs, b.perfFi.emaMs, b.perfTotal.emaMs,
                 b.perfGpuCopies.emaMs, b.perfGpuUpscale.emaMs, b.perfGpuOf.emaMs,
                 b.perfGpuPrep.emaMs, b.perfGpuFi.emaMs, b.perfGpuTotal.emaMs,
                 b.perfPresent.emaMs,
                 b.statRenderFps, b.statGenFps,
                 b.fgMultiplier,
                 syntheticMotionMagnitude(b, camData, camDataCount, reset != 0),
                 (unsigned long long)b.statGenSkipped.load(std::memory_order_relaxed));
        logBridge(message);
    }

    b.lastRecordedCb = static_cast<long long>(reinterpret_cast<uintptr_t>(cmd));
    b.upscaleCbIndex = (b.upscaleCbIndex + 1) % BridgeState::kCbRing;
    b.lastFrameOk = true;
    int writtenSlot = 0;
    if (b.mode != 0) {
        writtenSlot = static_cast<int>(b.outputSlot);
        b.outputSlot = (b.outputSlot + 1) % kMaxOutputs;
    }
    if (b.fg) {
        // The FI loop consumed the fg slots; report the last written one.
        writtenSlot = static_cast<int>((b.fgOutputSlot + b.fgSlotCount - 1) % b.fgSlotCount);
    }
    return writtenSlot;
}

long long ffxfg_last_recorded_command_buffer(void)
{
    BridgeState& b = g_bridge;
    return b.lastRecordedCb;
}

int ffxfg_last_upscale_slot(void)
{
    BridgeState& b = g_bridge;
    if (!b.lastFrameOk || b.mode == 0) {
        return -1;
    }
    return static_cast<int>((b.outputSlot + kMaxOutputs - 1) % kMaxOutputs);
}

int ffxfg_last_fg_slot(void)
{
    BridgeState& b = g_bridge;
    if (!b.lastFrameOk || !b.fg) {
        return -1;
    }
    return static_cast<int>((b.fgOutputSlot + b.fgSlotCount - 1) % b.fgSlotCount);
}

static int ffxfg_create_present_objects(VkDevice device)
{
    BridgeState& b = g_bridge;
    VkSemaphoreCreateInfo semInfo = {};
    semInfo.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;
    VkFenceCreateInfo fenceInfo = {};
    fenceInfo.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
    // Signaled: a slot is usable before its first submission.
    fenceInfo.flags = VK_FENCE_CREATE_SIGNALED_BIT;
    for (int i = 0; i < BridgeState::kCbRing; ++i) {
        if (vkCreateSemaphore(device, &semInfo, nullptr,
                              &b.acquireSemaphores[i]) != VK_SUCCESS) {
            return -1;
        }
        if (vkCreateSemaphore(device, &semInfo, nullptr,
                              &b.presentSemaphores[i]) != VK_SUCCESS) {
            return -1;
        }
        if (vkCreateFence(device, &fenceInfo, nullptr,
                          &b.presentFences[i]) != VK_SUCCESS) {
            return -1;
        }
    }
    return 0;
}

static void ffxfg_destroy_present_objects(VkDevice device)
{
    BridgeState& b = g_bridge;
    for (int i = 0; i < BridgeState::kCbRing; ++i) {
        if (b.acquireSemaphores[i]) {
            vkDestroySemaphore(device, b.acquireSemaphores[i], nullptr);
            b.acquireSemaphores[i] = VK_NULL_HANDLE;
        }
        if (b.presentSemaphores[i]) {
            vkDestroySemaphore(device, b.presentSemaphores[i], nullptr);
            b.presentSemaphores[i] = VK_NULL_HANDLE;
        }
        if (b.presentFences[i]) {
            vkDestroyFence(device, b.presentFences[i], nullptr);
            b.presentFences[i] = VK_NULL_HANDLE;
        }
    }
    b.presentCbIndex = 0;
}

// Witch patch: synchronous presentation of one generated sub-frame.
//
// The Vulkan swapchain, its images and the graphics queue are externally
// synchronized: they may only be used from the thread that also runs the
// game's own acquire/present (the render thread). RenderPearl destroys the
// swapchain - and with it every image - from configure()/close() on that same
// thread, so presenting from a worker thread races with the destroy, which is
// a use after free inside MoltenVK's deferred command encoding.
//
// Generated frames are therefore presented here, still on the render thread,
// right before the game presents the real frame. The presentation engine
// paces them: acquiring the next image blocks until the display releases one,
// so the sub-frames land on consecutive vsyncs without extra pacing math.
//
// Returns 0 when the sub-frame was presented or intentionally skipped
// (timeout / probe) and -1 on a swapchain error; the caller then stops
// presenting the rest of the batch and the real frame still shows.
int ffxfg_present_interpolated(long long vkSwapchainHandle, int slot)
{
    BridgeState& b = g_bridge;
    if (!b.initialized || !b.enabled || !b.queue || !b.device ||
        !b.presentCommandPool || !b.presentCommandBuffers[0] ||
        slot < 0 || slot >= b.fgSlotCount || slot >= kMaxFgOutputs) {
        return -1;
    }
    if (b.probeMask & 8) {
        if (!(b.probeAnnounced & 8)) {
            b.probeAnnounced |= 8;
            logBridge("perf: gen present skipped by probe");
        }
        return 0;
    }

    VkSwapchainKHR swapchain = reinterpret_cast<VkSwapchainKHR>(
        static_cast<uintptr_t>(vkSwapchainHandle));
    if (!swapchain) {
        return -1;
    }
    VkResult result = VK_SUCCESS;

    // RenderPearl reconfigured or closed the surface: the swapchain we last
    // presented on is being destroyed. Its waitIdle already ran, so the sync
    // objects can be replaced safely and a previous swapchain error is gone.
    if (b.resetPresentObjects ||
        (b.cachedSwapchain && b.cachedSwapchain != swapchain)) {
        ffxfg_destroy_present_objects(b.device);
        if (ffxfg_create_present_objects(b.device) != 0) {
            logBridge("present: sync object recreate failed");
            b.presentBroken = true;
            return -1;
        }
        b.resetPresentObjects = false;
        b.presentBroken = false;
        b.swapchainImages.clear();
        b.cachedSwapchain = VK_NULL_HANDLE;
    }
    if (b.presentBroken) {
        return -1;
    }

    // The image list only changes when the swapchain itself is recreated,
    // and ffxfg_swapchain_destroyed() drops the cache in that case. Querying
    // it again for every generated frame was two driver round trips per
    // presented frame for nothing.
    if (b.cachedSwapchain != swapchain || b.swapchainImages.empty()) {
        uint32_t imageCount = 0;
        VkResult result = vkGetSwapchainImagesKHR(b.device, swapchain, &imageCount, nullptr);
        if (result != VK_SUCCESS || imageCount == 0) {
            b.presentBroken = true;
            return -1;
        }
        b.swapchainImages.resize(imageCount);
        result = vkGetSwapchainImagesKHR(b.device, swapchain, &imageCount,
                                         b.swapchainImages.data());
        if (result != VK_SUCCESS || imageCount == 0) {
            b.swapchainImages.clear();
            b.presentBroken = true;
            return -1;
        }
        b.swapchainImages.resize(imageCount);
        b.cachedSwapchain = swapchain;
    }

    const int cbIndex = b.presentCbIndex;
    b.presentCbIndex = (b.presentCbIndex + 1) % BridgeState::kCbRing;
    VkCommandBuffer cmd = b.presentCommandBuffers[cbIndex];
    VkSemaphore acquireSemaphore = b.acquireSemaphores[cbIndex];
    VkSemaphore presentSemaphore = b.presentSemaphores[cbIndex];
    VkFence fence = b.presentFences[cbIndex];
    if (!cmd || !acquireSemaphore || !presentSemaphore || !fence) {
        b.presentBroken = true;
        return -1;
    }

    // Recycle this slot only after its previous submission (including the
    // acquire wait that belongs to it) completed.
    //
    // Witch patch: the check is non-blocking. vkWaitForFences waited for the
    // previous generated frame, and that submission only finishes when the
    // display has consumed it - so the wait was a full vsync (~16 ms) per
    // generated frame, and with x2 that is ~32 ms added to every real frame:
    // the game ran at 17-23 fps (see "present=" in the perf log) instead of
    // the ~60 fps it renders at. A slot that is still in flight is simply
    // skipped: the real frame that follows keeps the display fed, and the
    // next round presents the generated frame as soon as the slot is free.
    const auto presentStart = std::chrono::steady_clock::now();
    result = vkGetFenceStatus(b.device, fence);
    if (result == VK_NOT_READY) {
        b.statGenSkipped.fetch_add(1, std::memory_order_relaxed);
        return 0;
    }
    if (result != VK_SUCCESS) {
        b.presentBroken = true;
        return -1;
    }

    // Bounded wait: the display releases an image at the next vsync, so this
    // only times out when the surface stops consuming frames (backgrounded)
    // and must not freeze the render thread for long.
    //
    // Witch patch: the timeout is short on purpose. vkAcquireNextImageKHR
    // blocks until the display hands out an image, and the display only
    // releases one every vsync (16.7 ms on this device). Blocking for a full
    // frame time here added ~13 ms to every generated frame - the render
    // thread then needed 2 x 13 ms of waiting per real frame on top of the
    // render itself and the whole game ran at 23 fps instead of ~35. The
    // generated frame is simply skipped when no image is free yet: the real
    // frame that follows keeps the display fed, and the next round presents
    // the generated frame as soon as the display has an image again.
    uint32_t imageIndex = 0;
    result = vkAcquireNextImageKHR(b.device, swapchain, kPresentAcquireTimeoutNs,
                                   acquireSemaphore, VK_NULL_HANDLE, &imageIndex);
    if (result == VK_ERROR_OUT_OF_DATE_KHR || result == VK_ERROR_SURFACE_LOST_KHR) {
        b.presentBroken = true;
        logBridge("present: swapchain out of date (generated frames paused)");
        return -1;
    }
    if (result != VK_SUCCESS && result != VK_SUBOPTIMAL_KHR) {
        // VK_TIMEOUT: the display has no free image yet. The generated frame
        // is skipped instead of blocking the render thread for a whole vsync.
        if (result == VK_TIMEOUT) {
            b.statGenSkipped.fetch_add(1, std::memory_order_relaxed);
        }
        return 0;
    }
    if (imageIndex >= b.swapchainImages.size()) {
        b.presentBroken = true;
        return -1;
    }
    VkImage swapchainImage = b.swapchainImages[imageIndex];

    VkCommandBufferBeginInfo beginInfo = {};
    beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    vkResetCommandBuffer(cmd, 0);
    if (vkBeginCommandBuffer(cmd, &beginInfo) != VK_SUCCESS) {
        // The acquire already signaled the semaphore; the only safe recovery
        // is to stop using this swapchain.
        b.presentBroken = true;
        return -1;
    }

    recordImageBarrier(cmd, swapchainImage, VK_IMAGE_ASPECT_COLOR_BIT,
                       VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                       VK_PIPELINE_STAGE_2_NONE, VK_ACCESS_2_NONE,
                       VK_PIPELINE_STAGE_2_COPY_BIT, VK_ACCESS_2_TRANSFER_WRITE_BIT);

    recordImageBarrier(cmd, b.fgOutputs[slot], VK_IMAGE_ASPECT_COLOR_BIT,
                       VK_IMAGE_LAYOUT_GENERAL, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                       VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT, VK_ACCESS_2_MEMORY_WRITE_BIT,
                       VK_PIPELINE_STAGE_2_COPY_BIT, VK_ACCESS_2_TRANSFER_READ_BIT);

    VkImageBlit blit = {};
    blit.srcSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    blit.srcSubresource.layerCount = 1;
    blit.srcOffsets[0] = {0, 0, 0};
    blit.srcOffsets[1] = {static_cast<int32_t>(b.fgWidth), static_cast<int32_t>(b.fgHeight), 1};
    // Mirror vertically: same convention as the game's own present blit.
    blit.dstSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    blit.dstSubresource.layerCount = 1;
    blit.dstOffsets[0] = {0, static_cast<int32_t>(b.displayHeight), 0};
    blit.dstOffsets[1] = {static_cast<int32_t>(b.displayWidth), 0, 1};
    vkCmdBlitImage(cmd, b.fgOutputs[slot], VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                   swapchainImage, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                   1, &blit, VK_FILTER_LINEAR);

    // Restore the interpolated output to GENERAL so the next frame's
    // interpolation dispatch (which declares it as a UAV) sees the layout it
    // expects; leaving it in TRANSFER_SRC would corrupt the barrier chain.
    recordImageBarrier(cmd, b.fgOutputs[slot], VK_IMAGE_ASPECT_COLOR_BIT,
                       VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, VK_IMAGE_LAYOUT_GENERAL,
                       VK_PIPELINE_STAGE_2_COPY_BIT, VK_ACCESS_2_TRANSFER_READ_BIT,
                       VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT, VK_ACCESS_2_MEMORY_READ_BIT | VK_ACCESS_2_MEMORY_WRITE_BIT);

    recordImageBarrier(cmd, swapchainImage, VK_IMAGE_ASPECT_COLOR_BIT,
                       VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
                       VK_PIPELINE_STAGE_2_COPY_BIT, VK_ACCESS_2_TRANSFER_WRITE_BIT,
                       VK_PIPELINE_STAGE_2_NONE, VK_ACCESS_2_NONE);

    if (vkEndCommandBuffer(cmd) != VK_SUCCESS) {
        b.presentBroken = true;
        return -1;
    }

    VkCommandBufferSubmitInfo cmdInfo = {};
    cmdInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_SUBMIT_INFO;
    cmdInfo.commandBuffer = cmd;

    VkSemaphoreSubmitInfo waitInfo = {};
    waitInfo.sType = VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO;
    waitInfo.semaphore = acquireSemaphore;
    waitInfo.stageMask = VK_PIPELINE_STAGE_2_COPY_BIT;

    VkSemaphoreSubmitInfo signalInfo = {};
    signalInfo.sType = VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO;
    signalInfo.semaphore = presentSemaphore;
    signalInfo.stageMask = VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT;

    VkSubmitInfo2 submitInfo = {};
    submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO_2;
    submitInfo.commandBufferInfoCount = 1;
    submitInfo.pCommandBufferInfos = &cmdInfo;
    submitInfo.waitSemaphoreInfoCount = 1;
    submitInfo.pWaitSemaphoreInfos = &waitInfo;
    submitInfo.signalSemaphoreInfoCount = 1;
    submitInfo.pSignalSemaphoreInfos = &signalInfo;
    if (vkResetFences(b.device, 1, &fence) != VK_SUCCESS ||
        vkQueueSubmit2(b.queue, 1, &submitInfo, fence) != VK_SUCCESS) {
        b.presentBroken = true;
        return -1;
    }

    VkPresentInfoKHR presentInfo = {};
    presentInfo.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
    presentInfo.waitSemaphoreCount = 1;
    presentInfo.pWaitSemaphores = &presentSemaphore;
    presentInfo.swapchainCount = 1;
    presentInfo.pSwapchains = &swapchain;
    presentInfo.pImageIndices = &imageIndex;
    result = vkQueuePresentKHR(b.queue, &presentInfo);
    if (result != VK_SUCCESS && result != VK_SUBOPTIMAL_KHR) {
        b.presentBroken = true;
        logBridge("present: swapchain present failed (generated frames paused)");
        return -1;
    }
    perfNote(&b.perfPresent, perfMsSince(presentStart));
    ffxfg_note_frame_time(b.statLastGenTime, b.statGenFps);
    return 0;
}

// Witch patch: the extent of the surface's current drawable.
//
// The launcher draws the game into a CAMetalLayer whose drawable is the
// physical screen size when the FidelityFX upscaler is active, so the
// swapchain has to be created with that size - the game only asks for its
// (smaller) framebuffer size. The current extent of the surface is exactly
// the drawable size, so the agent can ask for it and force the swapchain
// configuration to it.
//
// Returns 0 on success, -1 when the query is not possible (the caller then
// keeps the game's own configuration, which is always safe).
int ffxfg_query_surface_extent(long long vkInstanceHandle,
                               long long vkPhysicalDeviceHandle,
                               long long vkSurfaceHandle,
                               int* outWidth, int* outHeight)
{
    if (!vkInstanceHandle || !vkPhysicalDeviceHandle || !vkSurfaceHandle ||
        !outWidth || !outHeight) {
        return -1;
    }
    // The instance level entry point is not part of the FFX interface in this
    // SDK version, but the loader exports it and the app links MoltenVK.
    typedef void* (*PFN_vkGetInstanceProcAddr)(void*, const char*);
    static PFN_vkGetInstanceProcAddr getInstanceProcAddr =
        reinterpret_cast<PFN_vkGetInstanceProcAddr>(
            dlsym(RTLD_DEFAULT, "vkGetInstanceProcAddr"));
    if (!getInstanceProcAddr) {
        return -1;
    }
    typedef VkResult (*PFN_vkGetPhysicalDeviceSurfaceCapabilitiesKHR)(
        VkPhysicalDevice, VkSurfaceKHR, VkSurfaceCapabilitiesKHR*);
    PFN_vkGetPhysicalDeviceSurfaceCapabilitiesKHR getCaps =
        reinterpret_cast<PFN_vkGetPhysicalDeviceSurfaceCapabilitiesKHR>(
            getInstanceProcAddr(reinterpret_cast<void*>(vkInstanceHandle),
                                "vkGetPhysicalDeviceSurfaceCapabilitiesKHR"));
    if (!getCaps) {
        return -1;
    }
    VkSurfaceCapabilitiesKHR caps = {};
    if (getCaps(reinterpret_cast<VkPhysicalDevice>(vkPhysicalDeviceHandle),
                reinterpret_cast<VkSurfaceKHR>(vkSurfaceHandle), &caps) != VK_SUCCESS) {
        return -1;
    }
    // currentExtent is the drawable size; when the surface reports 0xFFFFFFFF
    // the extent is free and the caller's size is fine.
    if (caps.currentExtent.width == 0 || caps.currentExtent.height == 0) {
        return -1;
    }
    *outWidth = static_cast<int>(caps.currentExtent.width);
    *outHeight = static_cast<int>(caps.currentExtent.height);
    return 0;
}

// Called from the surface hooks before RenderPearl destroys the swapchain.
void ffxfg_swapchain_destroyed(long long vkSwapchainHandle)
{
    BridgeState& b = g_bridge;
    VkSwapchainKHR swapchain = reinterpret_cast<VkSwapchainKHR>(
        static_cast<uintptr_t>(vkSwapchainHandle));
    if (!swapchain || b.cachedSwapchain == swapchain) {
        b.cachedSwapchain = VK_NULL_HANDLE;
        b.swapchainImages.clear();
    }
    // configure()/close() wait idle before destroying: the next present may
    // rebuild the sync objects without touching anything in flight.
    b.resetPresentObjects = true;
    b.presentBroken = false;
    if (b.initialized) {
        logBridge("surface: swapchain destroyed (present state reset)");
    }
}

// ---- JNI surface ------------------------------------------------------------

JNIEXPORT jint JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_init(
    JNIEnv* env, jclass clazz,
    jlong vkDevice, jlong vkPhysicalDevice, jlong vkGetDeviceProcAddr,
    jlong vkQueue, jint queueFamilyIndex, jint mode,
    jint fgEnabled, jfloat sharpness,
    jint renderWidth, jint renderHeight,
    jint displayWidth, jint displayHeight,
    jint colorFormat, jint srcColorFormat, jint depthInverted)
{
    (void)env;
    (void)clazz;
    return ffxfg_init(vkDevice, vkPhysicalDevice, vkGetDeviceProcAddr,
                      vkQueue, queueFamilyIndex, mode,
                      fgEnabled, sharpness,
                      renderWidth, renderHeight, displayWidth, displayHeight,
                      colorFormat, srcColorFormat, depthInverted);
}

JNIEXPORT void JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_destroy(
    JNIEnv* env, jclass clazz)
{
    (void)env;
    (void)clazz;
    ffxfg_destroy();
}

JNIEXPORT jboolean JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_isSupported(
    JNIEnv* env, jclass clazz)
{
    (void)env;
    (void)clazz;
    return ffxfg_isSupported() ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jint JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_recordFrame(
    JNIEnv* env, jclass clazz,
    jlong vkCommandBuffer, jlong srcColorImage,
    jint srcWidth, jint srcHeight,
    jfloatArray camData, jint reset)
{
    (void)clazz;
    if (!env || !camData) {
        return -1;
    }
    jsize length = env->GetArrayLength(camData);
    if (length < 16) {
        return -1;
    }
    jfloat* elements = env->GetFloatArrayElements(camData, nullptr);
    if (!elements) {
        return -1;
    }
    const int result = ffxfg_record_frame(vkCommandBuffer, srcColorImage,
                                          srcWidth, srcHeight,
                                          elements, length, reset);
    env->ReleaseFloatArrayElements(camData, elements, JNI_ABORT);
    return result;
}

JNIEXPORT jint JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_recordUpscale(
    JNIEnv* env, jclass clazz,
    jlong srcColorImage, jint srcWidth, jint srcHeight,
    jlong swapchainImage, jint srcColorFormat, jfloatArray camData, jint reset)
{
    (void)clazz;
    if (!env || !camData) {
        return -1;
    }
    jsize length = env->GetArrayLength(camData);
    if (length < 16) {
        return -1;
    }
    jfloat* elements = env->GetFloatArrayElements(camData, nullptr);
    if (!elements) {
        return -1;
    }
    // >= 0: the fg output slot written this frame (the VkCommandBuffer with
    // the recorded work is fetched via lastRecordedCommandBuffer); < 0:
    // nothing was recorded, do not submit the bridge command buffer.
    const long long result = ffxfg_record_upscale(
        srcColorImage, srcWidth, srcHeight, swapchainImage, srcColorFormat,
        elements, length, reset);
    env->ReleaseFloatArrayElements(camData, elements, JNI_ABORT);
    return static_cast<jint>(result);
}

JNIEXPORT jint JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_lastUpscaleSlot(
    JNIEnv* env, jclass clazz)
{
    (void)env;
    (void)clazz;
    return ffxfg_last_upscale_slot();
}

JNIEXPORT jint JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_lastFgSlot(
    JNIEnv* env, jclass clazz)
{
    (void)env;
    (void)clazz;
    return ffxfg_last_fg_slot();
}

JNIEXPORT jlong JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_lastRecordedCommandBuffer(
    JNIEnv* env, jclass clazz)
{
    (void)env;
    (void)clazz;
    return ffxfg_last_recorded_command_buffer();
}

JNIEXPORT jint JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_presentInterpolated(
    JNIEnv* env, jclass clazz, jlong vkSwapchain, jint slot)
{
    (void)env;
    (void)clazz;
    return ffxfg_present_interpolated(vkSwapchain, slot);
}

JNIEXPORT void JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_swapchainDestroyed(
    JNIEnv* env, jclass clazz, jlong vkSwapchain)
{
    (void)env;
    (void)clazz;
    ffxfg_swapchain_destroyed(vkSwapchain);
}

// Witch patch: the drawable size of the surface (the physical screen size
// when the launcher renders the game at a lower resolution).
JNIEXPORT jint JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_surfaceExtent(
    JNIEnv* env, jclass clazz, jlong vkInstance, jlong vkPhysicalDevice,
    jlong vkSurface, jintArray out)
{
    (void)clazz;
    if (!out) {
        return -1;
    }
    jint values[2] = {0, 0};
    int rc = ffxfg_query_surface_extent(vkInstance, vkPhysicalDevice, vkSurface,
                                        &values[0], &values[1]);
    if (rc == 0) {
        env->SetIntArrayRegion(out, 0, 2, values);
    }
    return rc;
}

JNIEXPORT jlong JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_getOutputImage(
    JNIEnv* env, jclass clazz, jint slot)
{
    (void)env;
    (void)clazz;
    return ffxfg_get_output_image(slot);
}

JNIEXPORT jlong JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_getFgOutputImage(
    JNIEnv* env, jclass clazz, jint slot)
{
    (void)env;
    (void)clazz;
    return ffxfg_get_fg_output_image(slot);
}

JNIEXPORT jint JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_outputSlotCount(
    JNIEnv* env, jclass clazz)
{
    (void)env;
    (void)clazz;
    return ffxfg_output_slot_count();
}

JNIEXPORT jint JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_setFgMultiplier(
    JNIEnv* env, jclass clazz, jint multiplier)
{
    (void)env;
    (void)clazz;
    return ffxfg_set_fg_multiplier(static_cast<int>(multiplier));
}

JNIEXPORT jint JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_setProbe(
    JNIEnv* env, jclass clazz, jint probe)
{
    (void)env;
    (void)clazz;
    return ffxfg_set_probe(static_cast<int>(probe));
}

JNIEXPORT jint JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_pendingFgSlotCount(
    JNIEnv* env, jclass clazz)
{
    (void)env;
    (void)clazz;
    return ffxfg_pending_fg_slot_count();
}

JNIEXPORT jint JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_pendingFgSlot(
    JNIEnv* env, jclass clazz, jint index)
{
    (void)env;
    (void)clazz;
    return ffxfg_pending_fg_slot(static_cast<int>(index));
}

JNIEXPORT void JNICALL Java_net_vda_witchlaunch_fsr3_Fsr3Native_getFrameStats(
    JNIEnv* env, jclass clazz, jfloatArray stats)
{
    (void)clazz;
    if (!env || !stats) {
        return;
    }
    jsize len = env->GetArrayLength(stats);
    if (len < 2) {
        return;
    }
    jfloat buf[2] = {0.0f, 0.0f};
    ffxfg_get_frame_stats(buf);
    env->SetFloatArrayRegion(stats, 0, 2, buf);
}
