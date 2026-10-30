#include "ffx_frameinterpolation_disocclusion_mask_pass_16bit_8f2bc0ce1199a98bafe1d47e7cf98baf.h"
#include "ffx_frameinterpolation_disocclusion_mask_pass_16bit_356c93a2465c30f45ed760f0b71bcf1f.h"

typedef union ffx_frameinterpolation_disocclusion_mask_pass_16bit_PermutationKey {
    struct {
        uint32_t FFX_FRAMEINTERPOLATION_OPTION_INVERTED_DEPTH : 1;
        uint32_t FFX_FRAMEINTERPOLATION_OPTION_LOW_RES_MOTION_VECTORS : 1;
        uint32_t FFX_FRAMEINTERPOLATION_OPTION_JITTER_MOTION_VECTORS : 1;
    };
    uint32_t index;
} ffx_frameinterpolation_disocclusion_mask_pass_16bit_PermutationKey;

typedef struct ffx_frameinterpolation_disocclusion_mask_pass_16bit_PermutationInfo {
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
} ffx_frameinterpolation_disocclusion_mask_pass_16bit_PermutationInfo;

static const uint32_t g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_IndirectionTable[] = {
    1,
    0,
    1,
    0,
    1,
    0,
    1,
    0,
};

static const ffx_frameinterpolation_disocclusion_mask_pass_16bit_PermutationInfo g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_PermutationInfo[] = {
    { g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_8f2bc0ce1199a98bafe1d47e7cf98baf_size, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_8f2bc0ce1199a98bafe1d47e7cf98baf_data, 1, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_8f2bc0ce1199a98bafe1d47e7cf98baf_CBVResourceNames, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_8f2bc0ce1199a98bafe1d47e7cf98baf_CBVResourceBindings, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_8f2bc0ce1199a98bafe1d47e7cf98baf_CBVResourceCounts, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_8f2bc0ce1199a98bafe1d47e7cf98baf_CBVResourceSets, 7, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_8f2bc0ce1199a98bafe1d47e7cf98baf_TextureSRVResourceNames, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_8f2bc0ce1199a98bafe1d47e7cf98baf_TextureSRVResourceBindings, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_8f2bc0ce1199a98bafe1d47e7cf98baf_TextureSRVResourceCounts, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_8f2bc0ce1199a98bafe1d47e7cf98baf_TextureSRVResourceSets, 1, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_8f2bc0ce1199a98bafe1d47e7cf98baf_TextureUAVResourceNames, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_8f2bc0ce1199a98bafe1d47e7cf98baf_TextureUAVResourceBindings, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_8f2bc0ce1199a98bafe1d47e7cf98baf_TextureUAVResourceCounts, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_8f2bc0ce1199a98bafe1d47e7cf98baf_TextureUAVResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_8f2bc0ce1199a98bafe1d47e7cf98baf_SamplerResourceNames, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_8f2bc0ce1199a98bafe1d47e7cf98baf_SamplerResourceBindings, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_8f2bc0ce1199a98bafe1d47e7cf98baf_SamplerResourceCounts, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_8f2bc0ce1199a98bafe1d47e7cf98baf_SamplerResourceSets, 0, 0, 0, 0, 0, },
    { g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_356c93a2465c30f45ed760f0b71bcf1f_size, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_356c93a2465c30f45ed760f0b71bcf1f_data, 1, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_356c93a2465c30f45ed760f0b71bcf1f_CBVResourceNames, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_356c93a2465c30f45ed760f0b71bcf1f_CBVResourceBindings, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_356c93a2465c30f45ed760f0b71bcf1f_CBVResourceCounts, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_356c93a2465c30f45ed760f0b71bcf1f_CBVResourceSets, 7, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_356c93a2465c30f45ed760f0b71bcf1f_TextureSRVResourceNames, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_356c93a2465c30f45ed760f0b71bcf1f_TextureSRVResourceBindings, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_356c93a2465c30f45ed760f0b71bcf1f_TextureSRVResourceCounts, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_356c93a2465c30f45ed760f0b71bcf1f_TextureSRVResourceSets, 1, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_356c93a2465c30f45ed760f0b71bcf1f_TextureUAVResourceNames, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_356c93a2465c30f45ed760f0b71bcf1f_TextureUAVResourceBindings, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_356c93a2465c30f45ed760f0b71bcf1f_TextureUAVResourceCounts, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_356c93a2465c30f45ed760f0b71bcf1f_TextureUAVResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_356c93a2465c30f45ed760f0b71bcf1f_SamplerResourceNames, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_356c93a2465c30f45ed760f0b71bcf1f_SamplerResourceBindings, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_356c93a2465c30f45ed760f0b71bcf1f_SamplerResourceCounts, g_ffx_frameinterpolation_disocclusion_mask_pass_16bit_356c93a2465c30f45ed760f0b71bcf1f_SamplerResourceSets, 0, 0, 0, 0, 0, },
};

