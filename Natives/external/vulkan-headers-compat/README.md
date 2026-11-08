# Vulkan headers compat (vendored, minimal)

`glsl_optimizer` (LTW tinywrapper) needs `vulkan/vulkan_core.h`
(+ `vk_platform.h`) for `nir_print.c` / `nir_vulkan.h`; the FidelityFX
Vulkan backend (`ffx_fsr3_vk`) and `upscaler/ffx_bridge.cpp` include
`vulkan/vulkan.h` (plus the iOS/macOS/Metal platform headers it guards).

These headers (`vulkan/` + `vk_video/`, pulled in by `vulkan_core.h`)
are vendored here so the iOS build does **not**
depend on the `Natives/external/MoltenVK` submodule being checked out
(CI only inits the GL4ES deps; full MoltenVK is huge).

- Source: `Natives/external/MoltenVK/External/Vulkan-Headers`
  (KhronosGroup/Vulkan-Headers, Apache-2.0)
- `Natives/CMakeLists.txt` prefers the MoltenVK copy when present and
  falls back to this directory otherwise.

Do not add more headers here unless a new `vulkan/*` include appears
in `glsl_optimizer`, the FidelityFX SDK sources or `upscaler/`.
