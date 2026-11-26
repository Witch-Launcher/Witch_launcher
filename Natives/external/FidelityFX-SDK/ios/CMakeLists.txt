cmake_minimum_required(VERSION 3.17)

# FidelityFX SDK (v1.1.4) static library for iOS arm64 (Vulkan backend, MoltenVK).
#
# Consumed via add_subdirectory() from Natives/CMakeLists.txt. Expects:
#   - FFX_VULKAN_HEADERS_INCLUDE : dir containing vulkan/vulkan.h
# Produces target: ffx_fsr3_vk (STATIC)
#
# Only FrameInterpolation (FI), FSR3Upscaler and the FSR3 combined driver are
# compiled; blob accessors and SPIR-V permutation blobs are pre-generated under
# ../generated/shaders/vk (see ../ios/generate_vk_shaders.sh).

set(FFX_SDK_ROOT "${CMAKE_CURRENT_LIST_DIR}/..")

if(NOT FFX_VULKAN_HEADERS_INCLUDE)
  message(FATAL_ERROR "ffx: FFX_VULKAN_HEADERS_INCLUDE not set (need vulkan/vulkan.h)")
endif()

set(FFX_COMPONENTS "${FFX_SDK_ROOT}/sdk/src/components")
set(FFX_SHARED_SRC "${FFX_SDK_ROOT}/sdk/src/shared")
set(FFX_BACKEND_VK "${FFX_SDK_ROOT}/sdk/src/backends/vk")
set(FFX_BACKEND_SHARED "${FFX_SDK_ROOT}/sdk/src/backends/shared")

set(FFX_FSR3_VK_SOURCES
  # host components
  "${FFX_COMPONENTS}/frameinterpolation/ffx_frameinterpolation.cpp"
  "${FFX_COMPONENTS}/fsr3upscaler/ffx_fsr3upscaler.cpp"
  "${FFX_COMPONENTS}/opticalflow/ffx_opticalflow.cpp"
  "${FFX_COMPONENTS}/fsr3/ffx_fsr3.cpp"
  "${FFX_COMPONENTS}/fsr2/ffx_fsr2.cpp"
  "${FFX_COMPONENTS}/fsr1/ffx_fsr1.cpp"
  # shared host helpers
  "${FFX_SHARED_SRC}/ffx_assert.cpp"
  "${FFX_SHARED_SRC}/ffx_message.cpp"
  "${FFX_SHARED_SRC}/ffx_object_management.cpp"
  "${FFX_SHARED_SRC}/ffx_breadcrumbs_list.cpp"
  # vulkan backend
  "${FFX_BACKEND_VK}/ffx_vk.cpp"
  # blob plumbing (consumes generated/shaders/vk permutation headers)
  "${FFX_BACKEND_SHARED}/ffx_shader_blobs.cpp"
  "${FFX_BACKEND_SHARED}/blob_accessors/ffx_frameinterpolation_shaderblobs.cpp"
  "${FFX_BACKEND_SHARED}/blob_accessors/ffx_fsr3upscaler_shaderblobs.cpp"
  "${FFX_BACKEND_SHARED}/blob_accessors/ffx_opticalflow_shaderblobs.cpp"
  "${FFX_BACKEND_SHARED}/blob_accessors/ffx_fsr2_shaderblobs.cpp"
  "${FFX_BACKEND_SHARED}/blob_accessors/ffx_fsr1_shaderblobs.cpp"
)

add_library(ffx_fsr3_vk STATIC ${FFX_FSR3_VK_SOURCES})

target_include_directories(ffx_fsr3_vk PUBLIC
  "${FFX_SDK_ROOT}/sdk/include"
  "${FFX_SDK_ROOT}/generated/shaders/vk"
)
target_include_directories(ffx_fsr3_vk PRIVATE
  "${FFX_SDK_ROOT}/sdk/include/FidelityFX/host"
  "${FFX_COMPONENTS}"
  "${FFX_SHARED_SRC}"
  "${FFX_BACKEND_SHARED}"
  "${FFX_BACKEND_VK}"
  "${FFX_VULKAN_HEADERS_INCLUDE}"
)

target_compile_definitions(ffx_fsr3_vk PRIVATE
  FFX_FI
  FFX_FSR3UPSCALER
  FFX_OF
  FFX_FSR2
  FFX_FSR1
  NOMINMAX
)

set_target_properties(ffx_fsr3_vk PROPERTIES
  CXX_STANDARD 17
  CXX_STANDARD_REQUIRED ON
  POSITION_INDEPENDENT_CODE ON
)

# Silence upstream's deprecated-codecvt fallback used on non-Windows builds.
target_compile_options(ffx_fsr3_vk PRIVATE
  -Wno-deprecated-declarations
  -Wno-unknown-pragmas
)
