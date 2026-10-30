#include "ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_411e951b10b3b430cbaa338721b6c807.h"
#include "ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_7ef50f5389c34704caafbb3fa3be2a66.h"

typedef union ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_PermutationKey {
    struct {
        uint32_t FFX_FRAMEINTERPOLATION_OPTION_INVERTED_DEPTH : 1;
        uint32_t FFX_FRAMEINTERPOLATION_OPTION_LOW_RES_MOTION_VECTORS : 1;
        uint32_t FFX_FRAMEINTERPOLATION_OPTION_JITTER_MOTION_VECTORS : 1;
    };
    uint32_t index;
} ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_PermutationKey;

typedef struct ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_PermutationInfo {
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
} ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_PermutationInfo;

static const uint32_t g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_IndirectionTable[] = {
    1,
    0,
    1,
    0,
    1,
    0,
    1,
    0,
};

static const ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_PermutationInfo g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_PermutationInfo[] = {
    { g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_411e951b10b3b430cbaa338721b6c807_size, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_411e951b10b3b430cbaa338721b6c807_data, 1, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_411e951b10b3b430cbaa338721b6c807_CBVResourceNames, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_411e951b10b3b430cbaa338721b6c807_CBVResourceBindings, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_411e951b10b3b430cbaa338721b6c807_CBVResourceCounts, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_411e951b10b3b430cbaa338721b6c807_CBVResourceSets, 3, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_411e951b10b3b430cbaa338721b6c807_TextureSRVResourceNames, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_411e951b10b3b430cbaa338721b6c807_TextureSRVResourceBindings, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_411e951b10b3b430cbaa338721b6c807_TextureSRVResourceCounts, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_411e951b10b3b430cbaa338721b6c807_TextureSRVResourceSets, 1, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_411e951b10b3b430cbaa338721b6c807_TextureUAVResourceNames, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_411e951b10b3b430cbaa338721b6c807_TextureUAVResourceBindings, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_411e951b10b3b430cbaa338721b6c807_TextureUAVResourceCounts, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_411e951b10b3b430cbaa338721b6c807_TextureUAVResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_411e951b10b3b430cbaa338721b6c807_SamplerResourceNames, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_411e951b10b3b430cbaa338721b6c807_SamplerResourceBindings, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_411e951b10b3b430cbaa338721b6c807_SamplerResourceCounts, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_411e951b10b3b430cbaa338721b6c807_SamplerResourceSets, 0, 0, 0, 0, 0, },
    { g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_7ef50f5389c34704caafbb3fa3be2a66_size, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_7ef50f5389c34704caafbb3fa3be2a66_data, 1, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_7ef50f5389c34704caafbb3fa3be2a66_CBVResourceNames, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_7ef50f5389c34704caafbb3fa3be2a66_CBVResourceBindings, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_7ef50f5389c34704caafbb3fa3be2a66_CBVResourceCounts, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_7ef50f5389c34704caafbb3fa3be2a66_CBVResourceSets, 3, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_7ef50f5389c34704caafbb3fa3be2a66_TextureSRVResourceNames, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_7ef50f5389c34704caafbb3fa3be2a66_TextureSRVResourceBindings, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_7ef50f5389c34704caafbb3fa3be2a66_TextureSRVResourceCounts, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_7ef50f5389c34704caafbb3fa3be2a66_TextureSRVResourceSets, 1, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_7ef50f5389c34704caafbb3fa3be2a66_TextureUAVResourceNames, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_7ef50f5389c34704caafbb3fa3be2a66_TextureUAVResourceBindings, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_7ef50f5389c34704caafbb3fa3be2a66_TextureUAVResourceCounts, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_7ef50f5389c34704caafbb3fa3be2a66_TextureUAVResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_7ef50f5389c34704caafbb3fa3be2a66_SamplerResourceNames, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_7ef50f5389c34704caafbb3fa3be2a66_SamplerResourceBindings, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_7ef50f5389c34704caafbb3fa3be2a66_SamplerResourceCounts, g_ffx_frameinterpolation_reconstruct_previous_depth_pass_wave64_7ef50f5389c34704caafbb3fa3be2a66_SamplerResourceSets, 0, 0, 0, 0, 0, },
};

