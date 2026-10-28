#include "ffx_fsr2_lock_pass_wave64_c9f8592d828c3eae80043c91ad280bc6.h"
#include "ffx_fsr2_lock_pass_wave64_6666a1531de51c98a5c1c8f3a03e97fd.h"

typedef union ffx_fsr2_lock_pass_wave64_PermutationKey {
    struct {
        uint32_t FFX_FSR2_OPTION_JITTERED_MOTION_VECTORS : 1;
        uint32_t FFX_FSR2_OPTION_INVERTED_DEPTH : 1;
        uint32_t FFX_FSR2_OPTION_REPROJECT_USE_LANCZOS_TYPE : 1;
        uint32_t FFX_FSR2_OPTION_HDR_COLOR_INPUT : 1;
        uint32_t FFX_FSR2_OPTION_LOW_RESOLUTION_MOTION_VECTORS : 1;
        uint32_t FFX_FSR2_OPTION_APPLY_SHARPENING : 1;
    };
    uint32_t index;
} ffx_fsr2_lock_pass_wave64_PermutationKey;

typedef struct ffx_fsr2_lock_pass_wave64_PermutationInfo {
    const uint32_t       blobSize;
    const unsigned char* blobData;


    const uint32_t  numConstantBuffers;
    const char**    constantBufferNames;
    const uint32_t* constantBufferBindings;
    const uint32_t* constantBufferCounts;
    const uint32_t* constantBufferSpaces;

    const uint32_t  numSRVTextures;
    const char**    srvTextureNames;
    const uint32_t* srvTextureBindings;
    const uint32_t* srvTextureCounts;
    const uint32_t* srvTextureSpaces;

    const uint32_t  numUAVTextures;
    const char**    uavTextureNames;
    const uint32_t* uavTextureBindings;
    const uint32_t* uavTextureCounts;
    const uint32_t* uavTextureSpaces;

    const uint32_t  numSRVBuffers;
    const char**    srvBufferNames;
    const uint32_t* srvBufferBindings;
    const uint32_t* srvBufferCounts;
    const uint32_t* srvBufferSpaces;

    const uint32_t  numUAVBuffers;
    const char**    uavBufferNames;
    const uint32_t* uavBufferBindings;
    const uint32_t* uavBufferCounts;
    const uint32_t* uavBufferSpaces;

    const uint32_t  numSamplers;
    const char**    samplerNames;
    const uint32_t* samplerBindings;
    const uint32_t* samplerCounts;
    const uint32_t* samplerSpaces;

    const uint32_t  numRTAccelerationStructures;
    const char**    rtAccelerationStructureNames;
    const uint32_t* rtAccelerationStructureBindings;
    const uint32_t* rtAccelerationStructureCounts;
    const uint32_t* rtAccelerationStructureSpaces;
} ffx_fsr2_lock_pass_wave64_PermutationInfo;

static const uint32_t g_ffx_fsr2_lock_pass_wave64_IndirectionTable[] = {
    0,
    0,
    1,
    1,
    0,
    0,
    1,
    1,
    0,
    0,
    1,
    1,
    0,
    0,
    1,
    1,
    0,
    0,
    1,
    1,
    0,
    0,
    1,
    1,
    0,
    0,
    1,
    1,
    0,
    0,
    1,
    1,
    0,
    0,
    1,
    1,
    0,
    0,
    1,
    1,
    0,
    0,
    1,
    1,
    0,
    0,
    1,
    1,
    0,
    0,
    1,
    1,
    0,
    0,
    1,
    1,
    0,
    0,
    1,
    1,
    0,
    0,
    1,
    1,
};

static const ffx_fsr2_lock_pass_wave64_PermutationInfo g_ffx_fsr2_lock_pass_wave64_PermutationInfo[] = {
    { g_ffx_fsr2_lock_pass_wave64_c9f8592d828c3eae80043c91ad280bc6_size, g_ffx_fsr2_lock_pass_wave64_c9f8592d828c3eae80043c91ad280bc6_data, 1, g_ffx_fsr2_lock_pass_wave64_c9f8592d828c3eae80043c91ad280bc6_CBVResourceNames, g_ffx_fsr2_lock_pass_wave64_c9f8592d828c3eae80043c91ad280bc6_CBVResourceBindings, g_ffx_fsr2_lock_pass_wave64_c9f8592d828c3eae80043c91ad280bc6_CBVResourceCounts, g_ffx_fsr2_lock_pass_wave64_c9f8592d828c3eae80043c91ad280bc6_CBVResourceSets, 1, g_ffx_fsr2_lock_pass_wave64_c9f8592d828c3eae80043c91ad280bc6_TextureSRVResourceNames, g_ffx_fsr2_lock_pass_wave64_c9f8592d828c3eae80043c91ad280bc6_TextureSRVResourceBindings, g_ffx_fsr2_lock_pass_wave64_c9f8592d828c3eae80043c91ad280bc6_TextureSRVResourceCounts, g_ffx_fsr2_lock_pass_wave64_c9f8592d828c3eae80043c91ad280bc6_TextureSRVResourceSets, 2, g_ffx_fsr2_lock_pass_wave64_c9f8592d828c3eae80043c91ad280bc6_TextureUAVResourceNames, g_ffx_fsr2_lock_pass_wave64_c9f8592d828c3eae80043c91ad280bc6_TextureUAVResourceBindings, g_ffx_fsr2_lock_pass_wave64_c9f8592d828c3eae80043c91ad280bc6_TextureUAVResourceCounts, g_ffx_fsr2_lock_pass_wave64_c9f8592d828c3eae80043c91ad280bc6_TextureUAVResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, },
    { g_ffx_fsr2_lock_pass_wave64_6666a1531de51c98a5c1c8f3a03e97fd_size, g_ffx_fsr2_lock_pass_wave64_6666a1531de51c98a5c1c8f3a03e97fd_data, 1, g_ffx_fsr2_lock_pass_wave64_6666a1531de51c98a5c1c8f3a03e97fd_CBVResourceNames, g_ffx_fsr2_lock_pass_wave64_6666a1531de51c98a5c1c8f3a03e97fd_CBVResourceBindings, g_ffx_fsr2_lock_pass_wave64_6666a1531de51c98a5c1c8f3a03e97fd_CBVResourceCounts, g_ffx_fsr2_lock_pass_wave64_6666a1531de51c98a5c1c8f3a03e97fd_CBVResourceSets, 1, g_ffx_fsr2_lock_pass_wave64_6666a1531de51c98a5c1c8f3a03e97fd_TextureSRVResourceNames, g_ffx_fsr2_lock_pass_wave64_6666a1531de51c98a5c1c8f3a03e97fd_TextureSRVResourceBindings, g_ffx_fsr2_lock_pass_wave64_6666a1531de51c98a5c1c8f3a03e97fd_TextureSRVResourceCounts, g_ffx_fsr2_lock_pass_wave64_6666a1531de51c98a5c1c8f3a03e97fd_TextureSRVResourceSets, 2, g_ffx_fsr2_lock_pass_wave64_6666a1531de51c98a5c1c8f3a03e97fd_TextureUAVResourceNames, g_ffx_fsr2_lock_pass_wave64_6666a1531de51c98a5c1c8f3a03e97fd_TextureUAVResourceBindings, g_ffx_fsr2_lock_pass_wave64_6666a1531de51c98a5c1c8f3a03e97fd_TextureUAVResourceCounts, g_ffx_fsr2_lock_pass_wave64_6666a1531de51c98a5c1c8f3a03e97fd_TextureUAVResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, },
};

