#include "ffx_fsr2_depth_clip_pass_4a3648de5a194484ca0447030f7c888f.h"
#include "ffx_fsr2_depth_clip_pass_bdcb126878b21151967c32e830c5a445.h"
#include "ffx_fsr2_depth_clip_pass_cc8894d8b27871f1813e4349640fa06a.h"
#include "ffx_fsr2_depth_clip_pass_4c40abecb6b52f9acb2dad74885daf4a.h"
#include "ffx_fsr2_depth_clip_pass_26ee0576651daf896849fee8c44d0750.h"
#include "ffx_fsr2_depth_clip_pass_b0c6fdc42350259eccb06fa3c18ec1f2.h"
#include "ffx_fsr2_depth_clip_pass_320713d86b371e2186a4d9738252127c.h"
#include "ffx_fsr2_depth_clip_pass_9776a11e2bc03efce6ee822cc47a7cf0.h"

typedef union ffx_fsr2_depth_clip_pass_PermutationKey {
    struct {
        uint32_t FFX_FSR2_OPTION_LOW_RESOLUTION_MOTION_VECTORS : 1;
        uint32_t FFX_FSR2_OPTION_JITTERED_MOTION_VECTORS : 1;
        uint32_t FFX_FSR2_OPTION_INVERTED_DEPTH : 1;
        uint32_t FFX_FSR2_OPTION_REPROJECT_USE_LANCZOS_TYPE : 1;
        uint32_t FFX_FSR2_OPTION_HDR_COLOR_INPUT : 1;
        uint32_t FFX_FSR2_OPTION_APPLY_SHARPENING : 1;
    };
    uint32_t index;
} ffx_fsr2_depth_clip_pass_PermutationKey;

typedef struct ffx_fsr2_depth_clip_pass_PermutationInfo {
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
} ffx_fsr2_depth_clip_pass_PermutationInfo;

static const uint32_t g_ffx_fsr2_depth_clip_pass_IndirectionTable[] = {
    7,
    4,
    6,
    1,
    5,
    3,
    2,
    0,
    7,
    4,
    6,
    1,
    5,
    3,
    2,
    0,
    7,
    4,
    6,
    1,
    5,
    3,
    2,
    0,
    7,
    4,
    6,
    1,
    5,
    3,
    2,
    0,
    7,
    4,
    6,
    1,
    5,
    3,
    2,
    0,
    7,
    4,
    6,
    1,
    5,
    3,
    2,
    0,
    7,
    4,
    6,
    1,
    5,
    3,
    2,
    0,
    7,
    4,
    6,
    1,
    5,
    3,
    2,
    0,
};

static const ffx_fsr2_depth_clip_pass_PermutationInfo g_ffx_fsr2_depth_clip_pass_PermutationInfo[] = {
    { g_ffx_fsr2_depth_clip_pass_4a3648de5a194484ca0447030f7c888f_size, g_ffx_fsr2_depth_clip_pass_4a3648de5a194484ca0447030f7c888f_data, 1, g_ffx_fsr2_depth_clip_pass_4a3648de5a194484ca0447030f7c888f_CBVResourceNames, g_ffx_fsr2_depth_clip_pass_4a3648de5a194484ca0447030f7c888f_CBVResourceBindings, g_ffx_fsr2_depth_clip_pass_4a3648de5a194484ca0447030f7c888f_CBVResourceCounts, g_ffx_fsr2_depth_clip_pass_4a3648de5a194484ca0447030f7c888f_CBVResourceSets, 9, g_ffx_fsr2_depth_clip_pass_4a3648de5a194484ca0447030f7c888f_TextureSRVResourceNames, g_ffx_fsr2_depth_clip_pass_4a3648de5a194484ca0447030f7c888f_TextureSRVResourceBindings, g_ffx_fsr2_depth_clip_pass_4a3648de5a194484ca0447030f7c888f_TextureSRVResourceCounts, g_ffx_fsr2_depth_clip_pass_4a3648de5a194484ca0447030f7c888f_TextureSRVResourceSets, 2, g_ffx_fsr2_depth_clip_pass_4a3648de5a194484ca0447030f7c888f_TextureUAVResourceNames, g_ffx_fsr2_depth_clip_pass_4a3648de5a194484ca0447030f7c888f_TextureUAVResourceBindings, g_ffx_fsr2_depth_clip_pass_4a3648de5a194484ca0447030f7c888f_TextureUAVResourceCounts, g_ffx_fsr2_depth_clip_pass_4a3648de5a194484ca0447030f7c888f_TextureUAVResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, g_ffx_fsr2_depth_clip_pass_4a3648de5a194484ca0447030f7c888f_SamplerResourceNames, g_ffx_fsr2_depth_clip_pass_4a3648de5a194484ca0447030f7c888f_SamplerResourceBindings, g_ffx_fsr2_depth_clip_pass_4a3648de5a194484ca0447030f7c888f_SamplerResourceCounts, g_ffx_fsr2_depth_clip_pass_4a3648de5a194484ca0447030f7c888f_SamplerResourceSets, 0, 0, 0, 0, 0, },
    { g_ffx_fsr2_depth_clip_pass_bdcb126878b21151967c32e830c5a445_size, g_ffx_fsr2_depth_clip_pass_bdcb126878b21151967c32e830c5a445_data, 1, g_ffx_fsr2_depth_clip_pass_bdcb126878b21151967c32e830c5a445_CBVResourceNames, g_ffx_fsr2_depth_clip_pass_bdcb126878b21151967c32e830c5a445_CBVResourceBindings, g_ffx_fsr2_depth_clip_pass_bdcb126878b21151967c32e830c5a445_CBVResourceCounts, g_ffx_fsr2_depth_clip_pass_bdcb126878b21151967c32e830c5a445_CBVResourceSets, 9, g_ffx_fsr2_depth_clip_pass_bdcb126878b21151967c32e830c5a445_TextureSRVResourceNames, g_ffx_fsr2_depth_clip_pass_bdcb126878b21151967c32e830c5a445_TextureSRVResourceBindings, g_ffx_fsr2_depth_clip_pass_bdcb126878b21151967c32e830c5a445_TextureSRVResourceCounts, g_ffx_fsr2_depth_clip_pass_bdcb126878b21151967c32e830c5a445_TextureSRVResourceSets, 2, g_ffx_fsr2_depth_clip_pass_bdcb126878b21151967c32e830c5a445_TextureUAVResourceNames, g_ffx_fsr2_depth_clip_pass_bdcb126878b21151967c32e830c5a445_TextureUAVResourceBindings, g_ffx_fsr2_depth_clip_pass_bdcb126878b21151967c32e830c5a445_TextureUAVResourceCounts, g_ffx_fsr2_depth_clip_pass_bdcb126878b21151967c32e830c5a445_TextureUAVResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, g_ffx_fsr2_depth_clip_pass_bdcb126878b21151967c32e830c5a445_SamplerResourceNames, g_ffx_fsr2_depth_clip_pass_bdcb126878b21151967c32e830c5a445_SamplerResourceBindings, g_ffx_fsr2_depth_clip_pass_bdcb126878b21151967c32e830c5a445_SamplerResourceCounts, g_ffx_fsr2_depth_clip_pass_bdcb126878b21151967c32e830c5a445_SamplerResourceSets, 0, 0, 0, 0, 0, },
    { g_ffx_fsr2_depth_clip_pass_cc8894d8b27871f1813e4349640fa06a_size, g_ffx_fsr2_depth_clip_pass_cc8894d8b27871f1813e4349640fa06a_data, 1, g_ffx_fsr2_depth_clip_pass_cc8894d8b27871f1813e4349640fa06a_CBVResourceNames, g_ffx_fsr2_depth_clip_pass_cc8894d8b27871f1813e4349640fa06a_CBVResourceBindings, g_ffx_fsr2_depth_clip_pass_cc8894d8b27871f1813e4349640fa06a_CBVResourceCounts, g_ffx_fsr2_depth_clip_pass_cc8894d8b27871f1813e4349640fa06a_CBVResourceSets, 9, g_ffx_fsr2_depth_clip_pass_cc8894d8b27871f1813e4349640fa06a_TextureSRVResourceNames, g_ffx_fsr2_depth_clip_pass_cc8894d8b27871f1813e4349640fa06a_TextureSRVResourceBindings, g_ffx_fsr2_depth_clip_pass_cc8894d8b27871f1813e4349640fa06a_TextureSRVResourceCounts, g_ffx_fsr2_depth_clip_pass_cc8894d8b27871f1813e4349640fa06a_TextureSRVResourceSets, 2, g_ffx_fsr2_depth_clip_pass_cc8894d8b27871f1813e4349640fa06a_TextureUAVResourceNames, g_ffx_fsr2_depth_clip_pass_cc8894d8b27871f1813e4349640fa06a_TextureUAVResourceBindings, g_ffx_fsr2_depth_clip_pass_cc8894d8b27871f1813e4349640fa06a_TextureUAVResourceCounts, g_ffx_fsr2_depth_clip_pass_cc8894d8b27871f1813e4349640fa06a_TextureUAVResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, g_ffx_fsr2_depth_clip_pass_cc8894d8b27871f1813e4349640fa06a_SamplerResourceNames, g_ffx_fsr2_depth_clip_pass_cc8894d8b27871f1813e4349640fa06a_SamplerResourceBindings, g_ffx_fsr2_depth_clip_pass_cc8894d8b27871f1813e4349640fa06a_SamplerResourceCounts, g_ffx_fsr2_depth_clip_pass_cc8894d8b27871f1813e4349640fa06a_SamplerResourceSets, 0, 0, 0, 0, 0, },
    { g_ffx_fsr2_depth_clip_pass_4c40abecb6b52f9acb2dad74885daf4a_size, g_ffx_fsr2_depth_clip_pass_4c40abecb6b52f9acb2dad74885daf4a_data, 1, g_ffx_fsr2_depth_clip_pass_4c40abecb6b52f9acb2dad74885daf4a_CBVResourceNames, g_ffx_fsr2_depth_clip_pass_4c40abecb6b52f9acb2dad74885daf4a_CBVResourceBindings, g_ffx_fsr2_depth_clip_pass_4c40abecb6b52f9acb2dad74885daf4a_CBVResourceCounts, g_ffx_fsr2_depth_clip_pass_4c40abecb6b52f9acb2dad74885daf4a_CBVResourceSets, 9, g_ffx_fsr2_depth_clip_pass_4c40abecb6b52f9acb2dad74885daf4a_TextureSRVResourceNames, g_ffx_fsr2_depth_clip_pass_4c40abecb6b52f9acb2dad74885daf4a_TextureSRVResourceBindings, g_ffx_fsr2_depth_clip_pass_4c40abecb6b52f9acb2dad74885daf4a_TextureSRVResourceCounts, g_ffx_fsr2_depth_clip_pass_4c40abecb6b52f9acb2dad74885daf4a_TextureSRVResourceSets, 2, g_ffx_fsr2_depth_clip_pass_4c40abecb6b52f9acb2dad74885daf4a_TextureUAVResourceNames, g_ffx_fsr2_depth_clip_pass_4c40abecb6b52f9acb2dad74885daf4a_TextureUAVResourceBindings, g_ffx_fsr2_depth_clip_pass_4c40abecb6b52f9acb2dad74885daf4a_TextureUAVResourceCounts, g_ffx_fsr2_depth_clip_pass_4c40abecb6b52f9acb2dad74885daf4a_TextureUAVResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, g_ffx_fsr2_depth_clip_pass_4c40abecb6b52f9acb2dad74885daf4a_SamplerResourceNames, g_ffx_fsr2_depth_clip_pass_4c40abecb6b52f9acb2dad74885daf4a_SamplerResourceBindings, g_ffx_fsr2_depth_clip_pass_4c40abecb6b52f9acb2dad74885daf4a_SamplerResourceCounts, g_ffx_fsr2_depth_clip_pass_4c40abecb6b52f9acb2dad74885daf4a_SamplerResourceSets, 0, 0, 0, 0, 0, },
    { g_ffx_fsr2_depth_clip_pass_26ee0576651daf896849fee8c44d0750_size, g_ffx_fsr2_depth_clip_pass_26ee0576651daf896849fee8c44d0750_data, 1, g_ffx_fsr2_depth_clip_pass_26ee0576651daf896849fee8c44d0750_CBVResourceNames, g_ffx_fsr2_depth_clip_pass_26ee0576651daf896849fee8c44d0750_CBVResourceBindings, g_ffx_fsr2_depth_clip_pass_26ee0576651daf896849fee8c44d0750_CBVResourceCounts, g_ffx_fsr2_depth_clip_pass_26ee0576651daf896849fee8c44d0750_CBVResourceSets, 9, g_ffx_fsr2_depth_clip_pass_26ee0576651daf896849fee8c44d0750_TextureSRVResourceNames, g_ffx_fsr2_depth_clip_pass_26ee0576651daf896849fee8c44d0750_TextureSRVResourceBindings, g_ffx_fsr2_depth_clip_pass_26ee0576651daf896849fee8c44d0750_TextureSRVResourceCounts, g_ffx_fsr2_depth_clip_pass_26ee0576651daf896849fee8c44d0750_TextureSRVResourceSets, 2, g_ffx_fsr2_depth_clip_pass_26ee0576651daf896849fee8c44d0750_TextureUAVResourceNames, g_ffx_fsr2_depth_clip_pass_26ee0576651daf896849fee8c44d0750_TextureUAVResourceBindings, g_ffx_fsr2_depth_clip_pass_26ee0576651daf896849fee8c44d0750_TextureUAVResourceCounts, g_ffx_fsr2_depth_clip_pass_26ee0576651daf896849fee8c44d0750_TextureUAVResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, g_ffx_fsr2_depth_clip_pass_26ee0576651daf896849fee8c44d0750_SamplerResourceNames, g_ffx_fsr2_depth_clip_pass_26ee0576651daf896849fee8c44d0750_SamplerResourceBindings, g_ffx_fsr2_depth_clip_pass_26ee0576651daf896849fee8c44d0750_SamplerResourceCounts, g_ffx_fsr2_depth_clip_pass_26ee0576651daf896849fee8c44d0750_SamplerResourceSets, 0, 0, 0, 0, 0, },
    { g_ffx_fsr2_depth_clip_pass_b0c6fdc42350259eccb06fa3c18ec1f2_size, g_ffx_fsr2_depth_clip_pass_b0c6fdc42350259eccb06fa3c18ec1f2_data, 1, g_ffx_fsr2_depth_clip_pass_b0c6fdc42350259eccb06fa3c18ec1f2_CBVResourceNames, g_ffx_fsr2_depth_clip_pass_b0c6fdc42350259eccb06fa3c18ec1f2_CBVResourceBindings, g_ffx_fsr2_depth_clip_pass_b0c6fdc42350259eccb06fa3c18ec1f2_CBVResourceCounts, g_ffx_fsr2_depth_clip_pass_b0c6fdc42350259eccb06fa3c18ec1f2_CBVResourceSets, 9, g_ffx_fsr2_depth_clip_pass_b0c6fdc42350259eccb06fa3c18ec1f2_TextureSRVResourceNames, g_ffx_fsr2_depth_clip_pass_b0c6fdc42350259eccb06fa3c18ec1f2_TextureSRVResourceBindings, g_ffx_fsr2_depth_clip_pass_b0c6fdc42350259eccb06fa3c18ec1f2_TextureSRVResourceCounts, g_ffx_fsr2_depth_clip_pass_b0c6fdc42350259eccb06fa3c18ec1f2_TextureSRVResourceSets, 2, g_ffx_fsr2_depth_clip_pass_b0c6fdc42350259eccb06fa3c18ec1f2_TextureUAVResourceNames, g_ffx_fsr2_depth_clip_pass_b0c6fdc42350259eccb06fa3c18ec1f2_TextureUAVResourceBindings, g_ffx_fsr2_depth_clip_pass_b0c6fdc42350259eccb06fa3c18ec1f2_TextureUAVResourceCounts, g_ffx_fsr2_depth_clip_pass_b0c6fdc42350259eccb06fa3c18ec1f2_TextureUAVResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, g_ffx_fsr2_depth_clip_pass_b0c6fdc42350259eccb06fa3c18ec1f2_SamplerResourceNames, g_ffx_fsr2_depth_clip_pass_b0c6fdc42350259eccb06fa3c18ec1f2_SamplerResourceBindings, g_ffx_fsr2_depth_clip_pass_b0c6fdc42350259eccb06fa3c18ec1f2_SamplerResourceCounts, g_ffx_fsr2_depth_clip_pass_b0c6fdc42350259eccb06fa3c18ec1f2_SamplerResourceSets, 0, 0, 0, 0, 0, },
    { g_ffx_fsr2_depth_clip_pass_320713d86b371e2186a4d9738252127c_size, g_ffx_fsr2_depth_clip_pass_320713d86b371e2186a4d9738252127c_data, 1, g_ffx_fsr2_depth_clip_pass_320713d86b371e2186a4d9738252127c_CBVResourceNames, g_ffx_fsr2_depth_clip_pass_320713d86b371e2186a4d9738252127c_CBVResourceBindings, g_ffx_fsr2_depth_clip_pass_320713d86b371e2186a4d9738252127c_CBVResourceCounts, g_ffx_fsr2_depth_clip_pass_320713d86b371e2186a4d9738252127c_CBVResourceSets, 9, g_ffx_fsr2_depth_clip_pass_320713d86b371e2186a4d9738252127c_TextureSRVResourceNames, g_ffx_fsr2_depth_clip_pass_320713d86b371e2186a4d9738252127c_TextureSRVResourceBindings, g_ffx_fsr2_depth_clip_pass_320713d86b371e2186a4d9738252127c_TextureSRVResourceCounts, g_ffx_fsr2_depth_clip_pass_320713d86b371e2186a4d9738252127c_TextureSRVResourceSets, 2, g_ffx_fsr2_depth_clip_pass_320713d86b371e2186a4d9738252127c_TextureUAVResourceNames, g_ffx_fsr2_depth_clip_pass_320713d86b371e2186a4d9738252127c_TextureUAVResourceBindings, g_ffx_fsr2_depth_clip_pass_320713d86b371e2186a4d9738252127c_TextureUAVResourceCounts, g_ffx_fsr2_depth_clip_pass_320713d86b371e2186a4d9738252127c_TextureUAVResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, g_ffx_fsr2_depth_clip_pass_320713d86b371e2186a4d9738252127c_SamplerResourceNames, g_ffx_fsr2_depth_clip_pass_320713d86b371e2186a4d9738252127c_SamplerResourceBindings, g_ffx_fsr2_depth_clip_pass_320713d86b371e2186a4d9738252127c_SamplerResourceCounts, g_ffx_fsr2_depth_clip_pass_320713d86b371e2186a4d9738252127c_SamplerResourceSets, 0, 0, 0, 0, 0, },
    { g_ffx_fsr2_depth_clip_pass_9776a11e2bc03efce6ee822cc47a7cf0_size, g_ffx_fsr2_depth_clip_pass_9776a11e2bc03efce6ee822cc47a7cf0_data, 1, g_ffx_fsr2_depth_clip_pass_9776a11e2bc03efce6ee822cc47a7cf0_CBVResourceNames, g_ffx_fsr2_depth_clip_pass_9776a11e2bc03efce6ee822cc47a7cf0_CBVResourceBindings, g_ffx_fsr2_depth_clip_pass_9776a11e2bc03efce6ee822cc47a7cf0_CBVResourceCounts, g_ffx_fsr2_depth_clip_pass_9776a11e2bc03efce6ee822cc47a7cf0_CBVResourceSets, 9, g_ffx_fsr2_depth_clip_pass_9776a11e2bc03efce6ee822cc47a7cf0_TextureSRVResourceNames, g_ffx_fsr2_depth_clip_pass_9776a11e2bc03efce6ee822cc47a7cf0_TextureSRVResourceBindings, g_ffx_fsr2_depth_clip_pass_9776a11e2bc03efce6ee822cc47a7cf0_TextureSRVResourceCounts, g_ffx_fsr2_depth_clip_pass_9776a11e2bc03efce6ee822cc47a7cf0_TextureSRVResourceSets, 2, g_ffx_fsr2_depth_clip_pass_9776a11e2bc03efce6ee822cc47a7cf0_TextureUAVResourceNames, g_ffx_fsr2_depth_clip_pass_9776a11e2bc03efce6ee822cc47a7cf0_TextureUAVResourceBindings, g_ffx_fsr2_depth_clip_pass_9776a11e2bc03efce6ee822cc47a7cf0_TextureUAVResourceCounts, g_ffx_fsr2_depth_clip_pass_9776a11e2bc03efce6ee822cc47a7cf0_TextureUAVResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, g_ffx_fsr2_depth_clip_pass_9776a11e2bc03efce6ee822cc47a7cf0_SamplerResourceNames, g_ffx_fsr2_depth_clip_pass_9776a11e2bc03efce6ee822cc47a7cf0_SamplerResourceBindings, g_ffx_fsr2_depth_clip_pass_9776a11e2bc03efce6ee822cc47a7cf0_SamplerResourceCounts, g_ffx_fsr2_depth_clip_pass_9776a11e2bc03efce6ee822cc47a7cf0_SamplerResourceSets, 0, 0, 0, 0, 0, },
};

