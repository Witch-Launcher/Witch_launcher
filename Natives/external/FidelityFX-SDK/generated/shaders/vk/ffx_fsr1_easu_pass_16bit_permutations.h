#include "ffx_fsr1_easu_pass_16bit_6edf5b5d359d8dd9b960a5b795e1153d.h"
#include "ffx_fsr1_easu_pass_16bit_f21981357d797e51192993d41cc9bef2.h"
#include "ffx_fsr1_easu_pass_16bit_f8dc0656f6dae1a3a40ce814ae4130a7.h"
#include "ffx_fsr1_easu_pass_16bit_92dceed1f5831580c5367367264732eb.h"

typedef union ffx_fsr1_easu_pass_16bit_PermutationKey {
    struct {
        uint32_t FFX_FSR1_OPTION_APPLY_RCAS : 1;
        uint32_t FFX_FSR1_OPTION_RCAS_PASSTHROUGH_ALPHA : 1;
        uint32_t FFX_FSR1_OPTION_SRGB_CONVERSIONS : 1;
    };
    uint32_t index;
} ffx_fsr1_easu_pass_16bit_PermutationKey;

typedef struct ffx_fsr1_easu_pass_16bit_PermutationInfo {
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
} ffx_fsr1_easu_pass_16bit_PermutationInfo;

static const uint32_t g_ffx_fsr1_easu_pass_16bit_IndirectionTable[] = {
    2,
    3,
    2,
    3,
    0,
    1,
    0,
    1,
};

static const ffx_fsr1_easu_pass_16bit_PermutationInfo g_ffx_fsr1_easu_pass_16bit_PermutationInfo[] = {
    { g_ffx_fsr1_easu_pass_16bit_6edf5b5d359d8dd9b960a5b795e1153d_size, g_ffx_fsr1_easu_pass_16bit_6edf5b5d359d8dd9b960a5b795e1153d_data, 1, g_ffx_fsr1_easu_pass_16bit_6edf5b5d359d8dd9b960a5b795e1153d_CBVResourceNames, g_ffx_fsr1_easu_pass_16bit_6edf5b5d359d8dd9b960a5b795e1153d_CBVResourceBindings, g_ffx_fsr1_easu_pass_16bit_6edf5b5d359d8dd9b960a5b795e1153d_CBVResourceCounts, g_ffx_fsr1_easu_pass_16bit_6edf5b5d359d8dd9b960a5b795e1153d_CBVResourceSets, 1, g_ffx_fsr1_easu_pass_16bit_6edf5b5d359d8dd9b960a5b795e1153d_TextureSRVResourceNames, g_ffx_fsr1_easu_pass_16bit_6edf5b5d359d8dd9b960a5b795e1153d_TextureSRVResourceBindings, g_ffx_fsr1_easu_pass_16bit_6edf5b5d359d8dd9b960a5b795e1153d_TextureSRVResourceCounts, g_ffx_fsr1_easu_pass_16bit_6edf5b5d359d8dd9b960a5b795e1153d_TextureSRVResourceSets, 1, g_ffx_fsr1_easu_pass_16bit_6edf5b5d359d8dd9b960a5b795e1153d_TextureUAVResourceNames, g_ffx_fsr1_easu_pass_16bit_6edf5b5d359d8dd9b960a5b795e1153d_TextureUAVResourceBindings, g_ffx_fsr1_easu_pass_16bit_6edf5b5d359d8dd9b960a5b795e1153d_TextureUAVResourceCounts, g_ffx_fsr1_easu_pass_16bit_6edf5b5d359d8dd9b960a5b795e1153d_TextureUAVResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, g_ffx_fsr1_easu_pass_16bit_6edf5b5d359d8dd9b960a5b795e1153d_SamplerResourceNames, g_ffx_fsr1_easu_pass_16bit_6edf5b5d359d8dd9b960a5b795e1153d_SamplerResourceBindings, g_ffx_fsr1_easu_pass_16bit_6edf5b5d359d8dd9b960a5b795e1153d_SamplerResourceCounts, g_ffx_fsr1_easu_pass_16bit_6edf5b5d359d8dd9b960a5b795e1153d_SamplerResourceSets, 0, 0, 0, 0, 0, },
    { g_ffx_fsr1_easu_pass_16bit_f21981357d797e51192993d41cc9bef2_size, g_ffx_fsr1_easu_pass_16bit_f21981357d797e51192993d41cc9bef2_data, 1, g_ffx_fsr1_easu_pass_16bit_f21981357d797e51192993d41cc9bef2_CBVResourceNames, g_ffx_fsr1_easu_pass_16bit_f21981357d797e51192993d41cc9bef2_CBVResourceBindings, g_ffx_fsr1_easu_pass_16bit_f21981357d797e51192993d41cc9bef2_CBVResourceCounts, g_ffx_fsr1_easu_pass_16bit_f21981357d797e51192993d41cc9bef2_CBVResourceSets, 1, g_ffx_fsr1_easu_pass_16bit_f21981357d797e51192993d41cc9bef2_TextureSRVResourceNames, g_ffx_fsr1_easu_pass_16bit_f21981357d797e51192993d41cc9bef2_TextureSRVResourceBindings, g_ffx_fsr1_easu_pass_16bit_f21981357d797e51192993d41cc9bef2_TextureSRVResourceCounts, g_ffx_fsr1_easu_pass_16bit_f21981357d797e51192993d41cc9bef2_TextureSRVResourceSets, 1, g_ffx_fsr1_easu_pass_16bit_f21981357d797e51192993d41cc9bef2_TextureUAVResourceNames, g_ffx_fsr1_easu_pass_16bit_f21981357d797e51192993d41cc9bef2_TextureUAVResourceBindings, g_ffx_fsr1_easu_pass_16bit_f21981357d797e51192993d41cc9bef2_TextureUAVResourceCounts, g_ffx_fsr1_easu_pass_16bit_f21981357d797e51192993d41cc9bef2_TextureUAVResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, g_ffx_fsr1_easu_pass_16bit_f21981357d797e51192993d41cc9bef2_SamplerResourceNames, g_ffx_fsr1_easu_pass_16bit_f21981357d797e51192993d41cc9bef2_SamplerResourceBindings, g_ffx_fsr1_easu_pass_16bit_f21981357d797e51192993d41cc9bef2_SamplerResourceCounts, g_ffx_fsr1_easu_pass_16bit_f21981357d797e51192993d41cc9bef2_SamplerResourceSets, 0, 0, 0, 0, 0, },
    { g_ffx_fsr1_easu_pass_16bit_f8dc0656f6dae1a3a40ce814ae4130a7_size, g_ffx_fsr1_easu_pass_16bit_f8dc0656f6dae1a3a40ce814ae4130a7_data, 1, g_ffx_fsr1_easu_pass_16bit_f8dc0656f6dae1a3a40ce814ae4130a7_CBVResourceNames, g_ffx_fsr1_easu_pass_16bit_f8dc0656f6dae1a3a40ce814ae4130a7_CBVResourceBindings, g_ffx_fsr1_easu_pass_16bit_f8dc0656f6dae1a3a40ce814ae4130a7_CBVResourceCounts, g_ffx_fsr1_easu_pass_16bit_f8dc0656f6dae1a3a40ce814ae4130a7_CBVResourceSets, 1, g_ffx_fsr1_easu_pass_16bit_f8dc0656f6dae1a3a40ce814ae4130a7_TextureSRVResourceNames, g_ffx_fsr1_easu_pass_16bit_f8dc0656f6dae1a3a40ce814ae4130a7_TextureSRVResourceBindings, g_ffx_fsr1_easu_pass_16bit_f8dc0656f6dae1a3a40ce814ae4130a7_TextureSRVResourceCounts, g_ffx_fsr1_easu_pass_16bit_f8dc0656f6dae1a3a40ce814ae4130a7_TextureSRVResourceSets, 1, g_ffx_fsr1_easu_pass_16bit_f8dc0656f6dae1a3a40ce814ae4130a7_TextureUAVResourceNames, g_ffx_fsr1_easu_pass_16bit_f8dc0656f6dae1a3a40ce814ae4130a7_TextureUAVResourceBindings, g_ffx_fsr1_easu_pass_16bit_f8dc0656f6dae1a3a40ce814ae4130a7_TextureUAVResourceCounts, g_ffx_fsr1_easu_pass_16bit_f8dc0656f6dae1a3a40ce814ae4130a7_TextureUAVResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, g_ffx_fsr1_easu_pass_16bit_f8dc0656f6dae1a3a40ce814ae4130a7_SamplerResourceNames, g_ffx_fsr1_easu_pass_16bit_f8dc0656f6dae1a3a40ce814ae4130a7_SamplerResourceBindings, g_ffx_fsr1_easu_pass_16bit_f8dc0656f6dae1a3a40ce814ae4130a7_SamplerResourceCounts, g_ffx_fsr1_easu_pass_16bit_f8dc0656f6dae1a3a40ce814ae4130a7_SamplerResourceSets, 0, 0, 0, 0, 0, },
    { g_ffx_fsr1_easu_pass_16bit_92dceed1f5831580c5367367264732eb_size, g_ffx_fsr1_easu_pass_16bit_92dceed1f5831580c5367367264732eb_data, 1, g_ffx_fsr1_easu_pass_16bit_92dceed1f5831580c5367367264732eb_CBVResourceNames, g_ffx_fsr1_easu_pass_16bit_92dceed1f5831580c5367367264732eb_CBVResourceBindings, g_ffx_fsr1_easu_pass_16bit_92dceed1f5831580c5367367264732eb_CBVResourceCounts, g_ffx_fsr1_easu_pass_16bit_92dceed1f5831580c5367367264732eb_CBVResourceSets, 1, g_ffx_fsr1_easu_pass_16bit_92dceed1f5831580c5367367264732eb_TextureSRVResourceNames, g_ffx_fsr1_easu_pass_16bit_92dceed1f5831580c5367367264732eb_TextureSRVResourceBindings, g_ffx_fsr1_easu_pass_16bit_92dceed1f5831580c5367367264732eb_TextureSRVResourceCounts, g_ffx_fsr1_easu_pass_16bit_92dceed1f5831580c5367367264732eb_TextureSRVResourceSets, 1, g_ffx_fsr1_easu_pass_16bit_92dceed1f5831580c5367367264732eb_TextureUAVResourceNames, g_ffx_fsr1_easu_pass_16bit_92dceed1f5831580c5367367264732eb_TextureUAVResourceBindings, g_ffx_fsr1_easu_pass_16bit_92dceed1f5831580c5367367264732eb_TextureUAVResourceCounts, g_ffx_fsr1_easu_pass_16bit_92dceed1f5831580c5367367264732eb_TextureUAVResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, g_ffx_fsr1_easu_pass_16bit_92dceed1f5831580c5367367264732eb_SamplerResourceNames, g_ffx_fsr1_easu_pass_16bit_92dceed1f5831580c5367367264732eb_SamplerResourceBindings, g_ffx_fsr1_easu_pass_16bit_92dceed1f5831580c5367367264732eb_SamplerResourceCounts, g_ffx_fsr1_easu_pass_16bit_92dceed1f5831580c5367367264732eb_SamplerResourceSets, 0, 0, 0, 0, 0, },
};

