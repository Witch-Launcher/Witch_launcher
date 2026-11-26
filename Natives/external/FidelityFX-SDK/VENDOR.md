# Vendored: AMD FidelityFX SDK

- **Upstream:** https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK
- **Version:** tag `v1.1.4` (MIT license, see `LICENSE.txt`)
- **Purpose:** FSR3 Frame Generation (FrameInterpolation + OpticalFlow) and
  FSR3 Upscaler host components with the Vulkan backend, used by the iOS
  launcher (MoltenVK). See `plan/FG.md` for the launcher-side integration.

## Why a vendored fork

Upstream ships precompiled shader blobs only as Windows binaries
(`sdk/tools/binary_store`, MSVC `.exe/.dll/.lib`) and its shader compiler
(`ffx_sc`) only builds on Windows. Everything here is recompiled from source
for macOS/iOS so the SPIR-V permutation blobs can be regenerated and the
host core can be built for `arm64-apple-ios`.

## What is vendored

Only the subset needed for FSR3 (upscaler + frame interpolation + optical
flow) on the Vulkan backend:

| Path | Contents |
| --- | --- |
| `sdk/include/` | Host API headers (`FidelityFX/host/*`) and GPU headers (`FidelityFX/gpu/*`, incl. the `CMakeCompile*.txt` permutation definitions) |
| `sdk/src/components/` | `frameinterpolation`, `fsr3upscaler`, `opticalflow`, `fsr3`, `fsr2`, `fsr1` |
| `sdk/src/shared/` | Host helpers: assert, message, object management, breadcrumbs |
| `sdk/src/backends/vk/` | `ffx_vk.cpp` + GLSL sources for the VK backend (incl. `FrameInterpolationSwapchain/`, unused on iOS) |
| `sdk/src/backends/shared/` | Blob plumbing: `ffx_shader_blobs.cpp` + `blob_accessors/{frameinterpolation,fsr3upscaler,opticalflow}` |
| `sdk/tools/ffx_shader_compiler/` | `ffx_sc`, ported to build on POSIX |
| `ios/` | This launcher's build + codegen glue (see below) |
| `generated/shaders/vk/` | Precompiled SPIR-V permutation headers (committed; consumers never need ffx_sc/glslang) |

NOT vendored (upstream-only, deleted): all other effects (fsr1/fsr2/cacao/…
host components stay because their `blob_accessors`/GPU headers are included
by shared plumbing — the IOss ones we compile are gated by defines),
`sdk/src/backends/dx12`, `sdk/tools/binary_store`, `agilitysdk`, `dxc`,
bundled `glslangValidator/bin`, `media_delivery` binaries.

## iOS glue (`ios/`)

- `ios/CMakeLists.txt` — builds static lib `ffx_fsr3_vk` (arm64-apple-ios)
  from the components above with `FFX_FI FFX_FSR3UPSCALER FFX_OF FFX_FSR2
  FFX_FSR1`; consumes Vulkan headers from the MoltenVK submodule. Included
  from `Natives/CMakeLists.txt`.
- `ios/generate_vk_shaders.sh` — regenerates `generated/shaders/vk/`:
  `FidelityFX_SC` (from `.build-sc`) shells to `glslangValidator`, compiling
  every GLSL pass of FSR3Upscaler (64 permutations), FrameInterpolation (8
  permutations), OpticalFlow (2 permutations), FSR2 (64 permutations) and
  FSR1 (8 permutations), each as 4 header variants (wave32/wave64 x FFX_HALF
  0/1). Requires `glslangValidator` on the host.
- `.build-sc/` — build dir for `FidelityFX_SC` (host tool, not shipped).

## Local patches (keep when re-syncing upstream)

All are `#ifdef _WIN32`-guarded; the Windows paths are untouched.

1. `sdk/tools/ffx_shader_compiler/src/`
   - `pch.hpp`: guard Windows headers, add `<cwchar>`.
   - `utils.cpp`: portable UTF-8 <-> wide conversion (UTF-32 on POSIX).
   - `ffx_sc.cpp`: portable path normalization/canonicalization, portable
     file-open helper (replaces `_wfopen_s`), dxc/fxc/GDK branches throw on
     POSIX, dual `main`/`wmain` entry.
   - `DXBCChecksum.h`: portable `BOOL/BYTE/DWORD` typedefs.
   - `CMakeLists.txt`: guard MSVC-only options, exclude
     `hlsl_compiler.cpp`/`DXBCChecksum.cpp` on POSIX, WIN32-only
     `add_subdirectory` for agilitysdk/dxc/glslangValidator.
   - `libs/tiny-process-library/CMakeLists.txt`: bump
     `cmake_minimum_required` to 3.17 (CMake 4.x policy).
2. `sdk/src/shared/ffx_portable_crt.h` (new): POSIX `_countof`, `wcscpy_s`.
3. `sdk/src/shared/ffx_breadcrumbs_list.h`: portable `sprintf_s`.
4. `sdk/src/shared/ffx_message.cpp`: POSIX messages go to stderr/callback
   instead of being discarded.
5. `sdk/include/FidelityFX/host/ffx_types.h`: `FFX_SDK_DEFAULT_CONTEXT_SIZE`
   grows on POSIX (1024*224 vs 1024*128) because POSIX `wchar_t` is 32-bit
   and the resource-name arrays double, overflowing the MSVC-tuned opaque
   context storage (private contexts would exceed the public buffer).
6. `sdk/src/backends/vk/ffx_vk.cpp`: portable UTF-8 <-> wide name conversion
   (libc++ dropped `std::wstring_convert`); explicit converters replace the
   `codecvt` fallback. Components include `ffx_portable_crt.h` guarded.
