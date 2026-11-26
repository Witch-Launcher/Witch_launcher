#include "ffx_fsr1_rcas_pass_16bit_f57de1a2ab00a6c9a8005869b27a27f1.h"
#include "ffx_fsr1_rcas_pass_16bit_ed1bc572e1b1d8413b32ca2ab11da765.h"

typedef union ffx_fsr1_rcas_pass_16bit_PermutationKey {
    struct {
        uint32_t FFX_FSR1_OPTION_APPLY_RCAS : 1;
        uint32_t FFX_FSR1_OPTION_RCAS_PASSTHROUGH_ALPHA : 1;
        uint32_t FFX_FSR1_OPTION_SRGB_CONVERSIONS : 1;
    };
    uint32_t index;
} ffx_fsr1_rcas_pass_16bit_PermutationKey;

typedef struct ffx_fsr1_rcas_pass_16bit_PermutationInfo {
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
} ffx_fsr1_rcas_pass_16bit_PermutationInfo;

static const uint32_t g_ffx_fsr1_rcas_pass_16bit_IndirectionTable[] = {
    0,
    0,
    1,
    1,
    0,
    0,
    1,
    1,
};

static const ffx_fsr1_rcas_pass_16bit_PermutationInfo g_ffx_fsr1_rcas_pass_16bit_PermutationInfo[] = {
    { g_ffx_fsr1_rcas_pass_16bit_f57de1a2ab00a6c9a8005869b27a27f1_size, g_ffx_fsr1_rcas_pass_16bit_f57de1a2ab00a6c9a8005869b27a27f1_data, 1, g_ffx_fsr1_rcas_pass_16bit_f57de1a2ab00a6c9a8005869b27a27f1_CBVResourceNames, g_ffx_fsr1_rcas_pass_16bit_f57de1a2ab00a6c9a8005869b27a27f1_CBVResourceBindings, g_ffx_fsr1_rcas_pass_16bit_f57de1a2ab00a6c9a8005869b27a27f1_CBVResourceCounts, g_ffx_fsr1_rcas_pass_16bit_f57de1a2ab00a6c9a8005869b27a27f1_CBVResourceSets, 1, g_ffx_fsr1_rcas_pass_16bit_f57de1a2ab00a6c9a8005869b27a27f1_TextureSRVResourceNames, g_ffx_fsr1_rcas_pass_16bit_f57de1a2ab00a6c9a8005869b27a27f1_TextureSRVResourceBindings, g_ffx_fsr1_rcas_pass_16bit_f57de1a2ab00a6c9a8005869b27a27f1_TextureSRVResourceCounts, g_ffx_fsr1_rcas_pass_16bit_f57de1a2ab00a6c9a8005869b27a27f1_TextureSRVResourceSets, 1, g_ffx_fsr1_rcas_pass_16bit_f57de1a2ab00a6c9a8005869b27a27f1_TextureUAVResourceNames, g_ffx_fsr1_rcas_pass_16bit_f57de1a2ab00a6c9a8005869b27a27f1_TextureUAVResourceBindings, g_ffx_fsr1_rcas_pass_16bit_f57de1a2ab00a6c9a8005869b27a27f1_TextureUAVResourceCounts, g_ffx_fsr1_rcas_pass_16bit_f57de1a2ab00a6c9a8005869b27a27f1_TextureUAVResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, },
    { g_ffx_fsr1_rcas_pass_16bit_ed1bc572e1b1d8413b32ca2ab11da765_size, g_ffx_fsr1_rcas_pass_16bit_ed1bc572e1b1d8413b32ca2ab11da765_data, 1, g_ffx_fsr1_rcas_pass_16bit_ed1bc572e1b1d8413b32ca2ab11da765_CBVResourceNames, g_ffx_fsr1_rcas_pass_16bit_ed1bc572e1b1d8413b32ca2ab11da765_CBVResourceBindings, g_ffx_fsr1_rcas_pass_16bit_ed1bc572e1b1d8413b32ca2ab11da765_CBVResourceCounts, g_ffx_fsr1_rcas_pass_16bit_ed1bc572e1b1d8413b32ca2ab11da765_CBVResourceSets, 1, g_ffx_fsr1_rcas_pass_16bit_ed1bc572e1b1d8413b32ca2ab11da765_TextureSRVResourceNames, g_ffx_fsr1_rcas_pass_16bit_ed1bc572e1b1d8413b32ca2ab11da765_TextureSRVResourceBindings, g_ffx_fsr1_rcas_pass_16bit_ed1bc572e1b1d8413b32ca2ab11da765_TextureSRVResourceCounts, g_ffx_fsr1_rcas_pass_16bit_ed1bc572e1b1d8413b32ca2ab11da765_TextureSRVResourceSets, 1, g_ffx_fsr1_rcas_pass_16bit_ed1bc572e1b1d8413b32ca2ab11da765_TextureUAVResourceNames, g_ffx_fsr1_rcas_pass_16bit_ed1bc572e1b1d8413b32ca2ab11da765_TextureUAVResourceBindings, g_ffx_fsr1_rcas_pass_16bit_ed1bc572e1b1d8413b32ca2ab11da765_TextureUAVResourceCounts, g_ffx_fsr1_rcas_pass_16bit_ed1bc572e1b1d8413b32ca2ab11da765_TextureUAVResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, },
};

