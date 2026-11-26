#include "ffx_fsr1_easu_pass_285351ec09f615903d78237e3fe90a12.h"
#include "ffx_fsr1_easu_pass_9c6822795dc3af2373428d42578f0dbd.h"
#include "ffx_fsr1_easu_pass_b3bc64cb7d2203303067d8086bf2499f.h"
#include "ffx_fsr1_easu_pass_22c070c3a735cd2bfcb61c215ba4f4c0.h"

typedef union ffx_fsr1_easu_pass_PermutationKey {
    struct {
        uint32_t FFX_FSR1_OPTION_APPLY_RCAS : 1;
        uint32_t FFX_FSR1_OPTION_RCAS_PASSTHROUGH_ALPHA : 1;
        uint32_t FFX_FSR1_OPTION_SRGB_CONVERSIONS : 1;
    };
    uint32_t index;
} ffx_fsr1_easu_pass_PermutationKey;

typedef struct ffx_fsr1_easu_pass_PermutationInfo {
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
} ffx_fsr1_easu_pass_PermutationInfo;

static const uint32_t g_ffx_fsr1_easu_pass_IndirectionTable[] = {
    3,
    0,
    3,
    0,
    1,
    2,
    1,
    2,
};

static const ffx_fsr1_easu_pass_PermutationInfo g_ffx_fsr1_easu_pass_PermutationInfo[] = {
    { g_ffx_fsr1_easu_pass_285351ec09f615903d78237e3fe90a12_size, g_ffx_fsr1_easu_pass_285351ec09f615903d78237e3fe90a12_data, 1, g_ffx_fsr1_easu_pass_285351ec09f615903d78237e3fe90a12_CBVResourceNames, g_ffx_fsr1_easu_pass_285351ec09f615903d78237e3fe90a12_CBVResourceBindings, g_ffx_fsr1_easu_pass_285351ec09f615903d78237e3fe90a12_CBVResourceCounts, g_ffx_fsr1_easu_pass_285351ec09f615903d78237e3fe90a12_CBVResourceSets, 1, g_ffx_fsr1_easu_pass_285351ec09f615903d78237e3fe90a12_TextureSRVResourceNames, g_ffx_fsr1_easu_pass_285351ec09f615903d78237e3fe90a12_TextureSRVResourceBindings, g_ffx_fsr1_easu_pass_285351ec09f615903d78237e3fe90a12_TextureSRVResourceCounts, g_ffx_fsr1_easu_pass_285351ec09f615903d78237e3fe90a12_TextureSRVResourceSets, 1, g_ffx_fsr1_easu_pass_285351ec09f615903d78237e3fe90a12_TextureUAVResourceNames, g_ffx_fsr1_easu_pass_285351ec09f615903d78237e3fe90a12_TextureUAVResourceBindings, g_ffx_fsr1_easu_pass_285351ec09f615903d78237e3fe90a12_TextureUAVResourceCounts, g_ffx_fsr1_easu_pass_285351ec09f615903d78237e3fe90a12_TextureUAVResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, g_ffx_fsr1_easu_pass_285351ec09f615903d78237e3fe90a12_SamplerResourceNames, g_ffx_fsr1_easu_pass_285351ec09f615903d78237e3fe90a12_SamplerResourceBindings, g_ffx_fsr1_easu_pass_285351ec09f615903d78237e3fe90a12_SamplerResourceCounts, g_ffx_fsr1_easu_pass_285351ec09f615903d78237e3fe90a12_SamplerResourceSets, 0, 0, 0, 0, 0, },
    { g_ffx_fsr1_easu_pass_9c6822795dc3af2373428d42578f0dbd_size, g_ffx_fsr1_easu_pass_9c6822795dc3af2373428d42578f0dbd_data, 1, g_ffx_fsr1_easu_pass_9c6822795dc3af2373428d42578f0dbd_CBVResourceNames, g_ffx_fsr1_easu_pass_9c6822795dc3af2373428d42578f0dbd_CBVResourceBindings, g_ffx_fsr1_easu_pass_9c6822795dc3af2373428d42578f0dbd_CBVResourceCounts, g_ffx_fsr1_easu_pass_9c6822795dc3af2373428d42578f0dbd_CBVResourceSets, 1, g_ffx_fsr1_easu_pass_9c6822795dc3af2373428d42578f0dbd_TextureSRVResourceNames, g_ffx_fsr1_easu_pass_9c6822795dc3af2373428d42578f0dbd_TextureSRVResourceBindings, g_ffx_fsr1_easu_pass_9c6822795dc3af2373428d42578f0dbd_TextureSRVResourceCounts, g_ffx_fsr1_easu_pass_9c6822795dc3af2373428d42578f0dbd_TextureSRVResourceSets, 1, g_ffx_fsr1_easu_pass_9c6822795dc3af2373428d42578f0dbd_TextureUAVResourceNames, g_ffx_fsr1_easu_pass_9c6822795dc3af2373428d42578f0dbd_TextureUAVResourceBindings, g_ffx_fsr1_easu_pass_9c6822795dc3af2373428d42578f0dbd_TextureUAVResourceCounts, g_ffx_fsr1_easu_pass_9c6822795dc3af2373428d42578f0dbd_TextureUAVResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, g_ffx_fsr1_easu_pass_9c6822795dc3af2373428d42578f0dbd_SamplerResourceNames, g_ffx_fsr1_easu_pass_9c6822795dc3af2373428d42578f0dbd_SamplerResourceBindings, g_ffx_fsr1_easu_pass_9c6822795dc3af2373428d42578f0dbd_SamplerResourceCounts, g_ffx_fsr1_easu_pass_9c6822795dc3af2373428d42578f0dbd_SamplerResourceSets, 0, 0, 0, 0, 0, },
    { g_ffx_fsr1_easu_pass_b3bc64cb7d2203303067d8086bf2499f_size, g_ffx_fsr1_easu_pass_b3bc64cb7d2203303067d8086bf2499f_data, 1, g_ffx_fsr1_easu_pass_b3bc64cb7d2203303067d8086bf2499f_CBVResourceNames, g_ffx_fsr1_easu_pass_b3bc64cb7d2203303067d8086bf2499f_CBVResourceBindings, g_ffx_fsr1_easu_pass_b3bc64cb7d2203303067d8086bf2499f_CBVResourceCounts, g_ffx_fsr1_easu_pass_b3bc64cb7d2203303067d8086bf2499f_CBVResourceSets, 1, g_ffx_fsr1_easu_pass_b3bc64cb7d2203303067d8086bf2499f_TextureSRVResourceNames, g_ffx_fsr1_easu_pass_b3bc64cb7d2203303067d8086bf2499f_TextureSRVResourceBindings, g_ffx_fsr1_easu_pass_b3bc64cb7d2203303067d8086bf2499f_TextureSRVResourceCounts, g_ffx_fsr1_easu_pass_b3bc64cb7d2203303067d8086bf2499f_TextureSRVResourceSets, 1, g_ffx_fsr1_easu_pass_b3bc64cb7d2203303067d8086bf2499f_TextureUAVResourceNames, g_ffx_fsr1_easu_pass_b3bc64cb7d2203303067d8086bf2499f_TextureUAVResourceBindings, g_ffx_fsr1_easu_pass_b3bc64cb7d2203303067d8086bf2499f_TextureUAVResourceCounts, g_ffx_fsr1_easu_pass_b3bc64cb7d2203303067d8086bf2499f_TextureUAVResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, g_ffx_fsr1_easu_pass_b3bc64cb7d2203303067d8086bf2499f_SamplerResourceNames, g_ffx_fsr1_easu_pass_b3bc64cb7d2203303067d8086bf2499f_SamplerResourceBindings, g_ffx_fsr1_easu_pass_b3bc64cb7d2203303067d8086bf2499f_SamplerResourceCounts, g_ffx_fsr1_easu_pass_b3bc64cb7d2203303067d8086bf2499f_SamplerResourceSets, 0, 0, 0, 0, 0, },
    { g_ffx_fsr1_easu_pass_22c070c3a735cd2bfcb61c215ba4f4c0_size, g_ffx_fsr1_easu_pass_22c070c3a735cd2bfcb61c215ba4f4c0_data, 1, g_ffx_fsr1_easu_pass_22c070c3a735cd2bfcb61c215ba4f4c0_CBVResourceNames, g_ffx_fsr1_easu_pass_22c070c3a735cd2bfcb61c215ba4f4c0_CBVResourceBindings, g_ffx_fsr1_easu_pass_22c070c3a735cd2bfcb61c215ba4f4c0_CBVResourceCounts, g_ffx_fsr1_easu_pass_22c070c3a735cd2bfcb61c215ba4f4c0_CBVResourceSets, 1, g_ffx_fsr1_easu_pass_22c070c3a735cd2bfcb61c215ba4f4c0_TextureSRVResourceNames, g_ffx_fsr1_easu_pass_22c070c3a735cd2bfcb61c215ba4f4c0_TextureSRVResourceBindings, g_ffx_fsr1_easu_pass_22c070c3a735cd2bfcb61c215ba4f4c0_TextureSRVResourceCounts, g_ffx_fsr1_easu_pass_22c070c3a735cd2bfcb61c215ba4f4c0_TextureSRVResourceSets, 1, g_ffx_fsr1_easu_pass_22c070c3a735cd2bfcb61c215ba4f4c0_TextureUAVResourceNames, g_ffx_fsr1_easu_pass_22c070c3a735cd2bfcb61c215ba4f4c0_TextureUAVResourceBindings, g_ffx_fsr1_easu_pass_22c070c3a735cd2bfcb61c215ba4f4c0_TextureUAVResourceCounts, g_ffx_fsr1_easu_pass_22c070c3a735cd2bfcb61c215ba4f4c0_TextureUAVResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, g_ffx_fsr1_easu_pass_22c070c3a735cd2bfcb61c215ba4f4c0_SamplerResourceNames, g_ffx_fsr1_easu_pass_22c070c3a735cd2bfcb61c215ba4f4c0_SamplerResourceBindings, g_ffx_fsr1_easu_pass_22c070c3a735cd2bfcb61c215ba4f4c0_SamplerResourceCounts, g_ffx_fsr1_easu_pass_22c070c3a735cd2bfcb61c215ba4f4c0_SamplerResourceSets, 0, 0, 0, 0, 0, },
};

