// FSR3 Frame Generation bridge implementation on top of the AMD FidelityFX
// SDK (Vulkan backend). See ffx_bridge.h for the contract.
//
// Design notes:
//  - We use the direct FrameInterpolation API (ffxFrameInterpolationPrepare +
//    ffxFrameInterpolationDispatch), NOT the FrameInterpolationSwapchain
//    wrapper: the launcher owns present pacing through the patched
//    RenderPearl surface.
//  - Motion vectors are synthesized on the CPU from the camera pose delta
//    (constant-depth reprojection, same quality model as the previous framegen
//    core) and uploaded through a host-visible staging image. FidelityFX
//    disocclusion refinement is limited by the synthetic depth (constant far
//    plane) until engine depth can be captured.
//  - Outputs are double buffered: slot s is written by the real frame and
//    presented on the next vsync by the agent.

#include "ffx_bridge.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <vector>

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
    // Ring of primary command buffers for the per-frame FidelityFX work.
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
    VkSemaphore acquireSemaphore = VK_NULL_HANDLE;
    VkSemaphore presentSemaphore = VK_NULL_HANDLE;

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
    // Slots written by the current frame's FI dispatches (batch for the
    // present hook to display, oldest first).
    uint32_t fgBatchBase = 0;
    uint32_t fgBatchCount = 0;

    // Witch patch: frame statistics for the launcher FPS widget. Timestamps
    // are captured per event and folded into EMA rates on read.
    std::atomic<uint64_t> statRealFrames{0};
    std::atomic<uint64_t> statGenFrames{0};
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
    PerfStage perfGpuCopies, perfGpuOf, perfGpuPrep, perfGpuFi, perfGpuTotal;

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
// motion-data copies, 2 = after optical flow (pure FG) or the upscaler
// dispatch (combo), 3 = after the FI prepare, 4 = after the FI dispatch loop.
void foldPerfTimestamps(BridgeState& b, int poolIndex)
{
    VkQueryPool pool = b.perfQueryPools[poolIndex];
    if (!pool || !b.perfPoolWritten[poolIndex]) {
        return;
    }
    b.perfPoolWritten[poolIndex] = false;

    uint64_t ts[BridgeState::kPerfQueryCount] = {};
    if (vkGetQueryPoolResults(b.device, pool, 0, BridgeState::kPerfQueryCount,
                              sizeof(ts), ts, sizeof(uint64_t),
                              VK_QUERY_RESULT_64_BIT) != VK_SUCCESS) {
        return;
    }
    if (ts[0] == 0 || ts[1] == 0 || ts[4] == 0) {
        return;
    }
    const double period = b.timestampPeriodNs;
    auto toMs = [&period](uint64_t last, uint64_t end) {
        return static_cast<double>(end - last) * period / 1.0e6;
    };
    perfNote(&b.perfGpuCopies, toMs(ts[0], ts[1]));
    if (ts[2]) {
        perfNote(&b.perfGpuOf, toMs(ts[1], ts[2]));
        if (ts[3]) {
            perfNote(&b.perfGpuPrep, toMs(ts[2], ts[3]));
            if (ts[4]) {
                perfNote(&b.perfGpuFi, toMs(ts[3], ts[4]));
            }
        } else if (ts[4]) {
            perfNote(&b.perfGpuFi, toMs(ts[2], ts[4]));
        }
    } else if (ts[4]) {
        perfNote(&b.perfGpuFi, toMs(ts[1], ts[4]));
    }
    perfNote(&b.perfGpuTotal, toMs(ts[0], ts[4]));
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

void writeSyntheticMotionVectors(const float* camData)
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
    const float referenceDepth = 8.0f;  // meters; ~typical MC view distance

    const float focalY = (height > 0 && fovY > 0.0f)
        ? (0.5f * static_cast<float>(height) / std::tan(0.5f * fovY))
        : 0.0f;
    const float focalX = focalY;

    if (!g_bridge.havePrevPose) {
        // First frame after reset: zero vectors.
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
            // NDC y of this row (+1 at the top).
            const float ndcY = 1.0f - 2.0f * (static_cast<float>(y) + 0.5f) / static_cast<float>(height);
            for (uint32_t x = 0; x < width; ++x) {
                const float ndcX = 2.0f * (static_cast<float>(x) + 0.5f) / static_cast<float>(width) - 1.0f;

                // Ray in the previous camera frame for this pixel.
                float ray[3] = {
                    g_bridge.prevFwd[0] + ndcX * g_bridge.prevRight[0] + ndcY * g_bridge.prevUp[0],
                    g_bridge.prevFwd[1] + ndcX * g_bridge.prevRight[1] + ndcY * g_bridge.prevUp[1],
                    g_bridge.prevFwd[2] + ndcX * g_bridge.prevRight[2] + ndcY * g_bridge.prevUp[2],
                };
                float rayLength = std::sqrt(ray[0] * ray[0] + ray[1] * ray[1] + ray[2] * ray[2]);
                if (rayLength > 1e-6f) {
                    ray[0] /= rayLength;
                    ray[1] /= rayLength;
                    ray[2] /= rayLength;
                }

                // World position of the reference-depth point along that ray.
                const float world[3] = {
                    g_bridge.prevPos[0] + ray[0] * referenceDepth,
                    g_bridge.prevPos[1] + ray[1] * referenceDepth,
                    g_bridge.prevPos[2] + ray[2] * referenceDepth,
                };

                // Into the new camera space.
                const float rel[3] = {
                    world[0] - pos[0],
                    world[1] - pos[1],
                    world[2] - pos[2],
                };
                float depthNew = rel[0] * fwd[0] + rel[1] * fwd[1] + rel[2] * fwd[2];
                const float lateralNewX = rel[0] * right[0] + rel[1] * right[1] + rel[2] * right[2];
                const float lateralNewY = rel[0] * up[0] + rel[1] * up[1] + rel[2] * up[2];
                if (depthNew < 0.05f) {
                    depthNew = 0.05f;
                }

                // NDC of the same world point in the new frame.
                const float ndcNewX = (lateralNewX / depthNew) * focalX * 2.0f / static_cast<float>(width);
                const float ndcNewY = (lateralNewY / depthNew) * focalY * 2.0f / static_cast<float>(height);

                float mvX = ndcNewX - ndcX;
                float mvY = ndcNewY - ndcY;

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

    if (g_bridge.initialized) {
        ffxfg_destroy();
    }

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
        return -1;
    }
    if (mode == 0 && fgEnabled == 0) {
        logBridge("init: nothing enabled");
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
    g_bridge.colorFormat = colorFormat;
    g_bridge.srcColorFormat = srcColorFormat;

    // Size the scratch from the SDK's own contract instead of a hardcoded
    // guess, and log the computed requirement so a mismatch is visible in
    // the device log (ffxGetInterfaceVK rejects undersized buffers with a
    // generic error code).
    const size_t requiredScratch = ffxGetScratchMemorySizeVK(physicalDevice, 4);
    g_bridge.scratch.resize(requiredScratch + (8u << 20));

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
        return -1;
    }

    // Frame interpolation context (frame generation). In combo mode the FI
    // consumes the upscaler's display-res output, so the max render size must
    // cover the display size; the per-frame dispatch renderSize stays at the
    // (scaled) render resolution. In pure-FG mode the back buffer is the
    // game's render texture, so its format is used there.
    if (g_bridge.fg) {
        FfxFrameInterpolationContextDescription fiDesc = {};
        fiDesc.flags = 0;
        fiDesc.maxRenderSize.width = g_bridge.displayWidth;
        fiDesc.maxRenderSize.height = g_bridge.displayHeight;
        fiDesc.displaySize.width = g_bridge.displayWidth;
        fiDesc.displaySize.height = g_bridge.displayHeight;
        fiDesc.backBufferFormat = ffxGetSurfaceFormatVK(
            g_bridge.mode != 0 ? colorFormat : srcColorFormat);
        fiDesc.previousInterpolationSourceFormat = fiDesc.backBufferFormat;
        fiDesc.backendInterface = g_bridge.ffxInterface;

        error = ffxFrameInterpolationContextCreate(&g_bridge.fiContext, &fiDesc);
        if (error != FFX_OK) {
            logBridge("init: ffxFrameInterpolationContextCreate failed");
            return -1;
        }
        g_bridge.fiContextValid = true;

        // Optical flow context + shared resources (same wiring as the SDK's
        // FSR3 composite driver: the OF dispatch writes the vectors the FI
        // dispatch consumes).
        FfxOpticalflowContextDescription ofDesc = {};
        ofDesc.backendInterface = g_bridge.ffxInterface;
        ofDesc.resolution.width = g_bridge.displayWidth;
        ofDesc.resolution.height = g_bridge.displayHeight;
        error = ffxOpticalflowContextCreate(&g_bridge.ofContext, &ofDesc);
        if (error != FFX_OK) {
            logBridge("init: ffxOpticalflowContextCreate failed");
            return -1;
        }
        g_bridge.ofContextValid = true;

        const uint32_t ofSharedContextId =
            reinterpret_cast<FfxOpticalflowContext_Private*>(&g_bridge.ofContext)->effectContextId;
        FfxOpticalflowSharedResourceDescriptions ofShared = {};
        error = ffxOpticalflowGetSharedResourceDescriptions(&g_bridge.ofContext, &ofShared);
        if (error != FFX_OK) {
            logBridge("init: ffxOpticalflowGetSharedResourceDescriptions failed");
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
            return -1;
        }
        g_bridge.ofVector = g_bridge.ffxInterface.fpGetResource(&g_bridge.ffxInterface, g_bridge.ofVectorInternal);
        g_bridge.ofScd = g_bridge.ffxInterface.fpGetResource(&g_bridge.ffxInterface, g_bridge.ofScdInternal);
    }

    // Per-mode upscaler context.
    if (mode == FFXFX_MODE_FSR1) {
        FfxFsr1ContextDescription fsr1Desc = {};
        fsr1Desc.flags = 0;
        fsr1Desc.outputFormat = ffxGetSurfaceFormatVK(colorFormat);
        fsr1Desc.maxRenderSize.width = g_bridge.renderWidth;
        fsr1Desc.maxRenderSize.height = g_bridge.renderHeight;
        fsr1Desc.displaySize.width = g_bridge.displayWidth;
        fsr1Desc.displaySize.height = g_bridge.displayHeight;
        fsr1Desc.backendInterface = g_bridge.ffxInterface;

        error = ffxFsr1ContextCreate(&g_bridge.fsr1Context, &fsr1Desc);
        if (error != FFX_OK) {
            logBridge("init: ffxFsr1ContextCreate failed");
            return -1;
        }
        g_bridge.fsr1Valid = true;
    } else if (mode == FFXFX_MODE_FSR2) {
        FfxFsr2ContextDescription fsr2Desc = {};
        fsr2Desc.flags = 0;
        fsr2Desc.maxRenderSize.width = g_bridge.renderWidth;
        fsr2Desc.maxRenderSize.height = g_bridge.renderHeight;
        fsr2Desc.displaySize.width = g_bridge.displayWidth;
        fsr2Desc.displaySize.height = g_bridge.displayHeight;
        fsr2Desc.fpMessage = fsr2MessageCallback;
        fsr2Desc.backendInterface = g_bridge.ffxInterface;

        error = ffxFsr2ContextCreate(&g_bridge.fsr2Context, &fsr2Desc);
        if (error != FFX_OK) {
            logBridge("init: ffxFsr2ContextCreate failed");
            return -1;
        }
        g_bridge.fsr2Valid = true;
    } else if (mode == FFXFX_MODE_FSR3UPSCALE) {
        FfxFsr3UpscalerContextDescription fsr3uDesc = {};
        fsr3uDesc.flags = 0;
        fsr3uDesc.maxRenderSize.width = g_bridge.renderWidth;
        fsr3uDesc.maxRenderSize.height = g_bridge.renderHeight;
        fsr3uDesc.maxUpscaleSize.width = g_bridge.displayWidth;
        fsr3uDesc.maxUpscaleSize.height = g_bridge.displayHeight;
        fsr3uDesc.fpMessage = fsr3UpscalerMessageCallback;
        fsr3uDesc.backendInterface = g_bridge.ffxInterface;

        error = ffxFsr3UpscalerContextCreate(&g_bridge.fsr3uContext, &fsr3uDesc);
        if (error != FFX_OK) {
            logBridge("init: ffxFsr3UpscalerContextCreate failed");
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
            cbInfo.commandBufferCount = 2 * BridgeState::kCbRing;
            VkCommandBuffer commandBuffers[2 * BridgeState::kCbRing] = {};
            if (vkAllocateCommandBuffers(device, &cbInfo, commandBuffers) == VK_SUCCESS) {
                for (int i = 0; i < BridgeState::kCbRing; ++i) {
                    g_bridge.upscaleCommandBuffers[i] = commandBuffers[i];
                    g_bridge.presentCommandBuffers[i] = commandBuffers[BridgeState::kCbRing + i];
                }
            }

            VkSemaphoreCreateInfo semInfo = {};
            semInfo.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;
            vkCreateSemaphore(device, &semInfo, nullptr, &g_bridge.acquireSemaphore);
            vkCreateSemaphore(device, &semInfo, nullptr, &g_bridge.presentSemaphore);

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
            for (int i = 0; i < BridgeState::kPerfQueryPools; ++i) {
                if (vkCreateQueryPool(device, &qpInfo, nullptr,
                                      &g_bridge.perfQueryPools[i]) != VK_SUCCESS) {
                    g_bridge.perfQueryPools[i] = VK_NULL_HANDLE;
                    break;
                }
            }
        }
    }

    // Staging images (LINEAR tiling, host visible) + device SRV images.
    if (!createImage2D(device, physicalDevice, g_bridge.renderWidth, g_bridge.renderHeight,
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
                       VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_SAMPLED_BIT,
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

    // Transition the FI UAVs to GENERAL once: the interpolation pipelines
    // write them as storage images, and FFX's barrier tracking starts from
    // the state claimed at registration (UNORDERED_ACCESS), which never
    // emits the initial UNDEFINED -> GENERAL transition itself.
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
    if (g_bridge.fg) {
        for (int i = 0; i < kMaxFgOutputs; ++i) {
            if (!createImage2D(device, physicalDevice, g_bridge.displayWidth, g_bridge.displayHeight,
                               colorFormat, VK_IMAGE_TILING_OPTIMAL,
                               VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_STORAGE_BIT | VK_IMAGE_USAGE_SAMPLED_BIT,
                               VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
                               &g_bridge.fgOutputs[i], &g_bridge.fgOutputMemories[i],
                               nullptr, nullptr)) {
                logBridge("init: fg output image failed");
                ffxfg_destroy();
                return -1;
            }
        }
    }

    g_bridge.initialized = true;
    g_bridge.enabled = true;
    g_bridge.frameID = 0;
    g_bridge.outputSlot = 0;
    g_bridge.fgOutputSlot = 0;
    g_bridge.havePrevPose = false;
    g_bridge.lastFrameOk = false;

    logBridge(g_bridge.fg && g_bridge.mode != 0 ? "init: ok (upscaler + framegen combo)"
              : g_bridge.fg ? "init: ok (framegen only)"
              : "init: ok (upscaler only)");
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
        if (b.mvsStagingMapped) {
            vkUnmapMemory(device, b.mvsStagingMemory);
            b.mvsStagingMapped = nullptr;
        }
        if (b.depthStagingMapped) {
            vkUnmapMemory(device, b.depthStagingMemory);
            b.depthStagingMapped = nullptr;
        }
        if (b.acquireSemaphore) {
            vkDestroySemaphore(device, b.acquireSemaphore, nullptr);
            b.acquireSemaphore = VK_NULL_HANDLE;
        }
        if (b.presentSemaphore) {
            vkDestroySemaphore(device, b.presentSemaphore, nullptr);
            b.presentSemaphore = VK_NULL_HANDLE;
        }
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
        }
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
    return 0;
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
    return static_cast<int>((b.fgBatchBase + static_cast<uint32_t>(index)) % kMaxFgOutputs);
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

    writeSyntheticMotionVectors(camData);

    // Upload the motion vectors into the device image.
    recordCopyHostImage(cmd, b.mvsStaging, b.mvsDevice,
                        b.renderWidth, b.renderHeight, VK_FORMAT_R16G16_SFLOAT);
    // Depth upload is only needed once; harmless to repeat.
    recordCopyHostImage(cmd, b.depthStaging, b.depthDevice,
                        b.renderWidth, b.renderHeight, VK_FORMAT_R32_SFLOAT);

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
    prepare.jitterOffset.x = 0.0f;
    prepare.jitterOffset.y = 0.0f;
    prepare.motionVectorScale.x = 1.0f;
    prepare.motionVectorScale.y = -1.0f;  // NDC y-up conversion
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
    dispatch.displaySize.width = b.displayWidth;
    dispatch.displaySize.height = b.displayHeight;
    dispatch.renderSize.width = b.renderWidth;
    dispatch.renderSize.height = b.renderHeight;
    dispatch.currentBackBuffer = presentColor;
    dispatch.output = resourceFromImage(
        b.fgOutputs[b.fgOutputSlot], b.displayWidth, b.displayHeight,
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
    dispatch.opticalFlowScale.x = 1.0f / static_cast<float>(b.displayWidth);
    dispatch.opticalFlowScale.y = 1.0f / static_cast<float>(b.displayHeight);
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
    dispatch.interpolationRect.width = static_cast<int32_t>(b.displayWidth);
    dispatch.interpolationRect.height = static_cast<int32_t>(b.displayHeight);

    // Witch patch: frame generation multiplier. The optical flow pass above
    // computed the displacement between the two real frames once; each
    // sub-frame dispatch re-scales it to its own phase and writes its own
    // output slot.
    const int genCount = std::max(1, std::min(kMaxFgOutputs, b.fgMultiplier) - 1);
    b.fgBatchBase = b.fgOutputSlot;
    b.fgBatchCount = 0;
    for (int k = 0; k < genCount; ++k) {
        dispatch.interpolationPhase =
            static_cast<float>(k + 1) / static_cast<float>(genCount + 1);
        dispatch.flags = (k + 1 < genCount)
            ? FFX_FRAMEINTERPOLATION_DISPATCH_INTERMEDIATE_SUBFRAME : 0u;
        dispatch.output = resourceFromImage(
            b.fgOutputs[b.fgOutputSlot], b.displayWidth, b.displayHeight,
            b.colorFormat, L"InterpolatedOutput", FFX_RESOURCE_STATE_UNORDERED_ACCESS);
        dispatch.frameID = b.frameID;
        error = ffxFrameInterpolationDispatch(&b.fiContext, &dispatch);
        b.frameID++;
        if (error != FFX_OK) {
            logDispatchError("fg fi", error);
            return -1;
        }
        b.fgOutputSlot = (b.fgOutputSlot + 1) % kMaxFgOutputs;
        b.fgBatchCount++;
        b.statGenFrames.fetch_add(1, std::memory_order_relaxed);
    }
    ffxfg_note_frame_time(b.statLastRealTime, b.statRenderFps);
    b.statRealFrames.fetch_add(1, std::memory_order_relaxed);

    b.lastFrameOk = true;
    return static_cast<int>((b.fgOutputSlot + kMaxFgOutputs - 1) % kMaxFgOutputs);
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

    if (needsMotionData) {
        writeSyntheticMotionVectors(camData);
    }

    VkCommandBufferBeginInfo beginInfo = {};
    beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    vkResetCommandBuffer(cmd, 0);
    if (vkBeginCommandBuffer(cmd, &beginInfo) != VK_SUCCESS) {
        return -1;
    }

    // GPU stage timestamps: consume the pool this record reuses (its markers
    // are kPerfQueryPools records old, long finished by now), reset it, then
    // start the trace. Slot 2 lands after the OF dispatch (pure FG) or after
    // the upscaler dispatch (combo), payload labels differ per mode.
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
        recordCopyHostImage(cmd, b.mvsStaging, b.mvsDevice,
                            b.renderWidth, b.renderHeight, VK_FORMAT_R16G16_SFLOAT);
        recordCopyHostImage(cmd, b.depthStaging, b.depthDevice,
                            b.renderWidth, b.renderHeight, VK_FORMAT_R32_SFLOAT);
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
        FfxResource output = resourceFromImage(
            b.outputs[b.outputSlot], b.displayWidth, b.displayHeight,
            b.colorFormat, L"UpscaleOutput", FFX_RESOURCE_STATE_UNORDERED_ACCESS);

        if (b.mode == FFXFX_MODE_FSR1) {
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
            dispatch.jitterOffset.x = 0.0f;
            dispatch.jitterOffset.y = 0.0f;
            dispatch.motionVectorScale.x = 1.0f;
            dispatch.motionVectorScale.y = -1.0f;
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
            dispatch.jitterOffset.x = 0.0f;
            dispatch.jitterOffset.y = 0.0f;
            dispatch.motionVectorScale.x = 1.0f;
            dispatch.motionVectorScale.y = -1.0f;
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
        if (b.mode != 0) {
            // The needsBlit section restored the upscaled output to GENERAL,
            // which is the layout the FI dispatch reads it in.
            presentColor = resourceFromImage(
                b.outputs[b.outputSlot], b.displayWidth, b.displayHeight,
                b.colorFormat, L"PresentColor", FFX_RESOURCE_STATE_COMPUTE_READ);
        } else {
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
        error = ffxOpticalflowContextDispatch(&b.ofContext, &ofDispatch);
        if (error != FFX_OK) {
            logDispatchError("fg of", error);
            vkEndCommandBuffer(cmd);
            return -1;
        }
        perfNote(&b.perfOf, perfMsSince(stageStart));
        stageStart = std::chrono::steady_clock::now();
        writeTs(2);

        FfxFrameInterpolationPrepareDescription prepare = {};
        prepare.flags = 0;
        prepare.commandList = ffxGetCommandListVK(cmd);
        prepare.renderSize.width = b.renderWidth;
        prepare.renderSize.height = b.renderHeight;
        prepare.jitterOffset.x = 0.0f;
        prepare.jitterOffset.y = 0.0f;
        prepare.motionVectorScale.x = 1.0f;
        prepare.motionVectorScale.y = -1.0f;
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
        error = ffxFrameInterpolationPrepare(&b.fiContext, &prepare);
        if (error != FFX_OK) {
            logDispatchError("fg prepare", error);
        }
        perfNote(&b.perfPrepare, perfMsSince(stageStart));
        stageStart = std::chrono::steady_clock::now();
        writeTs(3);
        if (error == FFX_OK) {
            FfxFrameInterpolationDispatchDescription dispatch = {};
            dispatch.flags = 0;
            dispatch.commandList = ffxGetCommandListVK(cmd);
            dispatch.displaySize.width = b.displayWidth;
            dispatch.displaySize.height = b.displayHeight;
            dispatch.renderSize.width = b.renderWidth;
            dispatch.renderSize.height = b.renderHeight;
            dispatch.currentBackBuffer = presentColor;
            dispatch.opticalFlowVector = b.ofVector;
            dispatch.opticalFlowSceneChangeDetection = b.ofScd;
            dispatch.opticalFlowBlockSize = 8;
            dispatch.opticalFlowScale.x = 1.0f / static_cast<float>(b.displayWidth);
            dispatch.opticalFlowScale.y = 1.0f / static_cast<float>(b.displayHeight);
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
            dispatch.interpolationRect.width = static_cast<int32_t>(b.displayWidth);
            dispatch.interpolationRect.height = static_cast<int32_t>(b.displayHeight);

            // Witch patch: frame generation multiplier, same loop as the
            // legacy FG path. Optical flow ran once above; each sub-frame
            // re-scales the flow to its own phase.
            const int genCount = std::max(1, std::min(kMaxFgOutputs, b.fgMultiplier) - 1);
            b.fgBatchBase = b.fgOutputSlot;
            b.fgBatchCount = 0;
            for (int k = 0; k < genCount; ++k) {
                dispatch.interpolationPhase =
                    static_cast<float>(k + 1) / static_cast<float>(genCount + 1);
                dispatch.flags = (k + 1 < genCount)
                    ? FFX_FRAMEINTERPOLATION_DISPATCH_INTERMEDIATE_SUBFRAME : 0u;
                dispatch.output = resourceFromImage(
                    b.fgOutputs[b.fgOutputSlot], b.displayWidth, b.displayHeight,
                    b.colorFormat, L"InterpolatedOutput", FFX_RESOURCE_STATE_UNORDERED_ACCESS);
                dispatch.frameID = b.frameID;
                error = ffxFrameInterpolationDispatch(&b.fiContext, &dispatch);
                b.frameID++;
                if (error != FFX_OK) {
                    break;
                }
                b.fgOutputSlot = (b.fgOutputSlot + 1) % kMaxFgOutputs;
                b.fgBatchCount++;
                b.statGenFrames.fetch_add(1, std::memory_order_relaxed);
            }
            perfNote(&b.perfFi, perfMsSince(stageStart));
            writeTs(4);
            ffxfg_note_frame_time(b.statLastRealTime, b.statRenderFps);
            b.statRealFrames.fetch_add(1, std::memory_order_relaxed);
        }
        if (error != FFX_OK) {
            logDispatchError("fg fi", error);
            vkEndCommandBuffer(cmd);
            return -1;
        }
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
        char message[256];
        snprintf(message, sizeof(message),
                 "perf: copy=%.1f up=%.1f of=%.1f prep=%.1f fi=%.1f total=%.1fms"
                 " gpu: copy=%.1f of=%.1f prep=%.1f fi=%.1f total=%.1fms"
                 " present=%.1f (fgx=%d)",
                 b.perfCopies.emaMs, b.perfUpscale.emaMs, b.perfOf.emaMs,
                 b.perfPrepare.emaMs, b.perfFi.emaMs, b.perfTotal.emaMs,
                 b.perfGpuCopies.emaMs, b.perfGpuOf.emaMs, b.perfGpuPrep.emaMs,
                 b.perfGpuFi.emaMs, b.perfGpuTotal.emaMs, b.perfPresent.emaMs,
                 b.fgMultiplier);
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
        writtenSlot = static_cast<int>((b.fgOutputSlot + kMaxFgOutputs - 1) % kMaxFgOutputs);
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
    return static_cast<int>((b.fgOutputSlot + kMaxFgOutputs - 1) % kMaxFgOutputs);
}

int ffxfg_present_interpolated(long long vkSwapchainHandle, int slot)
{
    BridgeState& b = g_bridge;
    if (!b.initialized || !b.enabled || !b.queue || !b.commandPool ||
        !b.acquireSemaphore || !b.presentSemaphore || !b.presentCommandBuffers[0] ||
        slot < 0 || slot >= kMaxFgOutputs) {
        return -1;
    }

    VkSwapchainKHR swapchain = reinterpret_cast<VkSwapchainKHR>(
        static_cast<uintptr_t>(vkSwapchainHandle));
    if (!swapchain) {
        return -1;
    }
    const auto presentStart = std::chrono::steady_clock::now();

    // Resolve the swapchain image array (cheap; cached by swapchain handle).
    static VkSwapchainKHR cachedSwapchain = VK_NULL_HANDLE;
    static std::vector<VkImage> cachedImages;
    if (cachedSwapchain != swapchain) {
        uint32_t count = 0;
        if (vkGetSwapchainImagesKHR(b.device, swapchain, &count, nullptr) != VK_SUCCESS || count == 0) {
            return -1;
        }
        cachedImages.resize(count);
        if (vkGetSwapchainImagesKHR(b.device, swapchain, &count, cachedImages.data()) != VK_SUCCESS) {
            return -1;
        }
        cachedSwapchain = swapchain;
    }

    uint32_t imageIndex = 0;
    VkResult result = vkAcquireNextImageKHR(b.device, swapchain, 100000000ull,
                                            b.acquireSemaphore, VK_NULL_HANDLE, &imageIndex);
    if (result != VK_SUCCESS && result != VK_SUBOPTIMAL_KHR) {
        return -1;
    }
    if (imageIndex >= cachedImages.size()) {
        return -1;
    }
    VkImage swapchainImage = cachedImages[imageIndex];

    VkCommandBuffer cmd = b.presentCommandBuffers[b.presentCbIndex];
    VkCommandBufferBeginInfo beginInfo = {};
    beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    vkResetCommandBuffer(cmd, 0);
    if (vkBeginCommandBuffer(cmd, &beginInfo) != VK_SUCCESS) {
        return -1;
    }

    recordImageBarrier(cmd, swapchainImage, VK_IMAGE_ASPECT_COLOR_BIT,
                       VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                       VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT, VK_ACCESS_2_NONE,
                       VK_PIPELINE_STAGE_2_COPY_BIT, VK_ACCESS_2_TRANSFER_WRITE_BIT);

    recordImageBarrier(cmd, b.fgOutputs[slot], VK_IMAGE_ASPECT_COLOR_BIT,
                       VK_IMAGE_LAYOUT_GENERAL, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                       VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT, VK_ACCESS_2_MEMORY_WRITE_BIT,
                       VK_PIPELINE_STAGE_2_COPY_BIT, VK_ACCESS_2_TRANSFER_READ_BIT);

    VkImageBlit blit = {};
    blit.srcSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    blit.srcSubresource.layerCount = 1;
    blit.srcOffsets[0] = {0, 0, 0};
    blit.srcOffsets[1] = {static_cast<int32_t>(b.displayWidth), static_cast<int32_t>(b.displayHeight), 1};
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
                       VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT, VK_ACCESS_2_NONE);

    if (vkEndCommandBuffer(cmd) != VK_SUCCESS) {
        return -1;
    }

    VkCommandBufferSubmitInfo cmdInfo = {};
    cmdInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_SUBMIT_INFO;
    cmdInfo.commandBuffer = cmd;

    VkSemaphoreSubmitInfo waitInfo = {};
    waitInfo.sType = VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO;
    waitInfo.semaphore = b.acquireSemaphore;
    waitInfo.stageMask = VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT;

    VkSemaphoreSubmitInfo signalInfo = {};
    signalInfo.sType = VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO;
    signalInfo.semaphore = b.presentSemaphore;
    signalInfo.stageMask = VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT;

    VkSubmitInfo2 submitInfo = {};
    submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO_2;
    submitInfo.commandBufferInfoCount = 1;
    submitInfo.pCommandBufferInfos = &cmdInfo;
    submitInfo.waitSemaphoreInfoCount = 1;
    submitInfo.pWaitSemaphoreInfos = &waitInfo;
    submitInfo.signalSemaphoreInfoCount = 1;
    submitInfo.pSignalSemaphoreInfos = &signalInfo;
    if (vkQueueSubmit2(b.queue, 1, &submitInfo, VK_NULL_HANDLE) != VK_SUCCESS) {
        return -1;
    }

    VkPresentInfoKHR presentInfo = {};
    presentInfo.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
    presentInfo.waitSemaphoreCount = 1;
    presentInfo.pWaitSemaphores = &b.presentSemaphore;
    presentInfo.swapchainCount = 1;
    presentInfo.pSwapchains = &swapchain;
    presentInfo.pImageIndices = &imageIndex;
    result = vkQueuePresentKHR(b.queue, &presentInfo);
    if (result != VK_SUCCESS && result != VK_SUBOPTIMAL_KHR) {
        return -1;
    }

    b.presentCbIndex = (b.presentCbIndex + 1) % BridgeState::kCbRing;
    ffxfg_note_frame_time(b.statLastGenTime, b.statGenFps);
    perfNote(&b.perfPresent, perfMsSince(presentStart));
    return static_cast<int>(imageIndex);
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
