#!/usr/bin/env bash
# Angel-Aura-Amethyst: generate the SPIR-V permutation blobs for the FSR3
# (Upscaler + Frame Interpolation) Vulkan backend on a macOS/Linux host.
#
# Usage:
#   ./ios/generate_vk_shaders.sh
#
# Requirements:
#   - FidelityFX_SC built for this host:
#       cmake -S sdk/tools/ffx_shader_compiler -B .build-sc && \
#       cmake --build .build-sc
#   - glslangValidator on PATH or $GLSLANG_EXE (e.g. brew install glslang)
#
# The generated headers land in generated/shaders/vk/ and are committed with
# the fork so downstream (iOS) builds do not need ffx_sc or glslang at all.

set -euo pipefail

FFX_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SC="${FFX_ROOT}/sdk/tools/ffx_shader_compiler/bin/FidelityFX_SC"
GLSLANG="${GLSLANG_EXE:-/usr/local/bin/glslangValidator}"
GPU_PATH="${FFX_ROOT}/sdk/include/FidelityFX/gpu"
SRC_PATH="${FFX_ROOT}/sdk/src/backends/vk/shaders"
OUT_DIR="${FFX_ROOT}/generated/shaders/vk"

if [[ ! -x "${SC}" ]]; then
    echo "FidelityFX_SC not found at ${SC}" >&2
    echo "Build it first: cmake -S ${FFX_ROOT}/sdk/tools/ffx_shader_compiler -B ${FFX_ROOT}/.build-sc && cmake --build ${FFX_ROOT}/.build-sc" >&2
    exit 1
fi

mkdir -p "${OUT_DIR}"

# compile_pass <feature-dir> <pass-name> <base+permutation args...>
compile_pass() {
    local feature_dir="$1"
    local pass="$2"
    shift 2

    local shader="${SRC_PATH}/${feature_dir}/${pass}.glsl"

    # Wave32 (FFX_HALF=0)
    "${SC}" \
        -glslangexe="${GLSLANG}" \
        -e CS --target-env vulkan1.2 -S comp -Os -DFFX_GLSL=1 \
        -reflection -deps=gcc -DFFX_GPU=1 \
        "$@" \
        -I"${GPU_PATH}" \
        -I"${GPU_PATH}/${feature_dir}" \
        -output="${OUT_DIR}" \
        -name="${pass}" -DFFX_HALF=0 \
        "${shader}"

    # Wave64 (no WaveSize semantics in GLSL; blobs dedupe by hash upstream)
    "${SC}" \
        -glslangexe="${GLSLANG}" \
        -e CS --target-env vulkan1.2 -S comp -Os -DFFX_GLSL=1 \
        -reflection -deps=gcc -DFFX_GPU=1 \
        "$@" \
        -I"${GPU_PATH}" \
        -I"${GPU_PATH}/${feature_dir}" \
        -output="${OUT_DIR}" \
        -name="${pass}_wave64" -DFFX_HALF=0 \
        "${shader}"

    # Wave32 16-bit (FFX_HALF=1)
    "${SC}" \
        -glslangexe="${GLSLANG}" \
        -e CS --target-env vulkan1.2 -S comp -Os -DFFX_GLSL=1 \
        -reflection -deps=gcc -DFFX_GPU=1 \
        "$@" \
        -I"${GPU_PATH}" \
        -I"${GPU_PATH}/${feature_dir}" \
        -output="${OUT_DIR}" \
        -name="${pass}_16bit" -DFFX_HALF=1 \
        "${shader}"

    # Wave64 16-bit
    "${SC}" \
        -glslangexe="${GLSLANG}" \
        -e CS --target-env vulkan1.2 -S comp -Os -DFFX_GLSL=1 \
        -reflection -deps=gcc -DFFX_GPU=1 \
        "$@" \
        -I"${GPU_PATH}" \
        -I"${GPU_PATH}/${feature_dir}" \
        -output="${OUT_DIR}" \
        -name="${pass}_wave64_16bit" -DFFX_HALF=1 \
        "${shader}"
}

echo "== FSR3 Upscaler =="
for pass in \
    ffx_fsr3upscaler_accumulate_pass \
    ffx_fsr3upscaler_autogen_reactive_pass \
    ffx_fsr3upscaler_debug_view_pass \
    ffx_fsr3upscaler_luma_instability_pass \
    ffx_fsr3upscaler_luma_pyramid_pass \
    ffx_fsr3upscaler_prepare_inputs_pass \
    ffx_fsr3upscaler_prepare_reactivity_pass \
    ffx_fsr3upscaler_rcas_pass \
    ffx_fsr3upscaler_shading_change_pass \
    ffx_fsr3upscaler_shading_change_pyramid_pass; do
    compile_pass fsr3upscaler "${pass}" \
        -DFFX_FSR3UPSCALER_OPTION_UPSAMPLE_SAMPLERS_USE_DATA_HALF=0 \
        -DFFX_FSR3UPSCALER_OPTION_ACCUMULATE_SAMPLERS_USE_DATA_HALF=0 \
        -DFFX_FSR3UPSCALER_OPTION_REPROJECT_SAMPLERS_USE_DATA_HALF=1 \
        -DFFX_FSR3UPSCALER_OPTION_POSTPROCESSLOCKSTATUS_SAMPLERS_USE_DATA_HALF=0 \
        -DFFX_FSR3UPSCALER_OPTION_UPSAMPLE_USE_LANCZOS_TYPE=2 \
        -DFFX_FSR3UPSCALER_OPTION_REPROJECT_USE_LANCZOS_TYPE='{0,1}' \
        -DFFX_FSR3UPSCALER_OPTION_HDR_COLOR_INPUT='{0,1}' \
        -DFFX_FSR3UPSCALER_OPTION_LOW_RESOLUTION_MOTION_VECTORS='{0,1}' \
        -DFFX_FSR3UPSCALER_OPTION_JITTERED_MOTION_VECTORS='{0,1}' \
        -DFFX_FSR3UPSCALER_OPTION_INVERTED_DEPTH='{0,1}' \
        -DFFX_FSR3UPSCALER_OPTION_APPLY_SHARPENING='{0,1}'
done

echo "== Frame Interpolation =="
for pass in \
    ffx_frameinterpolation_compute_game_vector_field_inpainting_pyramid_pass \
    ffx_frameinterpolation_compute_inpainting_pyramid_pass \
    ffx_frameinterpolation_debug_view_pass \
    ffx_frameinterpolation_disocclusion_mask_pass \
    ffx_frameinterpolation_game_motion_vector_field_pass \
    ffx_frameinterpolation_inpainting_pass \
    ffx_frameinterpolation_optical_flow_vector_field_pass \
    ffx_frameinterpolation_pass \
    ffx_frameinterpolation_reconstruct_and_dilate_pass \
    ffx_frameinterpolation_reconstruct_previous_depth_pass \
    ffx_frameinterpolation_setup_pass; do
    compile_pass frameinterpolation "${pass}" \
        -DFFX_FRAMEINTERPOLATION_OPTION_UPSAMPLE_SAMPLERS_USE_DATA_HALF=0 \
        -DFFX_FRAMEINTERPOLATION_OPTION_ACCUMULATE_SAMPLERS_USE_DATA_HALF=0 \
        -DFFX_FRAMEINTERPOLATION_OPTION_REPROJECT_SAMPLERS_USE_DATA_HALF=1 \
        -DFFX_FRAMEINTERPOLATION_OPTION_POSTPROCESSLOCKSTATUS_SAMPLERS_USE_DATA_HALF=0 \
        -DFFX_FRAMEINTERPOLATION_OPTION_UPSAMPLE_USE_LANCZOS_TYPE=2 \
        -DFFX_FRAMEINTERPOLATION_OPTION_LOW_RES_MOTION_VECTORS='{0,1}' \
        -DFFX_FRAMEINTERPOLATION_OPTION_JITTER_MOTION_VECTORS='{0,1}' \
        -DFFX_FRAMEINTERPOLATION_OPTION_INVERTED_DEPTH='{0,1}'
done

echo "== FSR1 =="
for pass in \
    ffx_fsr1_easu_pass \
    ffx_fsr1_rcas_pass; do
    compile_pass fsr1 "${pass}" \
        -DFFX_FSR1_OPTION_APPLY_RCAS='{0,1}' \
        -DFFX_FSR1_OPTION_RCAS_PASSTHROUGH_ALPHA='{0,1}' \
        -DFFX_FSR1_OPTION_SRGB_CONVERSIONS='{0,1}'
done

echo "== FSR2 =="
for pass in \
    ffx_fsr2_accumulate_pass \
    ffx_fsr2_autogen_reactive_pass \
    ffx_fsr2_compute_luminance_pyramid_pass \
    ffx_fsr2_depth_clip_pass \
    ffx_fsr2_lock_pass \
    ffx_fsr2_rcas_pass \
    ffx_fsr2_reconstruct_previous_depth_pass \
    ffx_fsr2_tcr_autogen_pass; do
    compile_pass fsr2 "${pass}" \
        -DFFX_FSR2_OPTION_UPSAMPLE_SAMPLERS_USE_DATA_HALF=0 \
        -DFFX_FSR2_OPTION_ACCUMULATE_SAMPLERS_USE_DATA_HALF=0 \
        -DFFX_FSR2_OPTION_REPROJECT_SAMPLERS_USE_DATA_HALF=1 \
        -DFFX_FSR2_OPTION_POSTPROCESSLOCKSTATUS_SAMPLERS_USE_DATA_HALF=0 \
        -DFFX_FSR2_OPTION_UPSAMPLE_USE_LANCZOS_TYPE=2 \
        -DFFX_FSR2_OPTION_REPROJECT_USE_LANCZOS_TYPE='{0,1}' \
        -DFFX_FSR2_OPTION_HDR_COLOR_INPUT='{0,1}' \
        -DFFX_FSR2_OPTION_LOW_RESOLUTION_MOTION_VECTORS='{0,1}' \
        -DFFX_FSR2_OPTION_JITTERED_MOTION_VECTORS='{0,1}' \
        -DFFX_FSR2_OPTION_INVERTED_DEPTH='{0,1}' \
        -DFFX_FSR2_OPTION_APPLY_SHARPENING='{0,1}'
done

echo "== Optical Flow =="
for pass in \
    ffx_opticalflow_prepare_luma_pass \
    ffx_opticalflow_compute_luminance_pyramid_pass \
    ffx_opticalflow_generate_scd_histogram_pass \
    ffx_opticalflow_compute_scd_divergence_pass \
    ffx_opticalflow_compute_optical_flow_advanced_pass_v5 \
    ffx_opticalflow_filter_optical_flow_pass_v5 \
    ffx_opticalflow_scale_optical_flow_advanced_pass_v5; do
    compile_pass opticalflow "${pass}" \
        -DFFX_OPTICALFLOW_OPTION_HDR_COLOR_INPUT='{0,1}'
done

echo "Done. Generated headers in ${OUT_DIR}"
