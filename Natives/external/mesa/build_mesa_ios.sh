#!/bin/bash
# Cross-compile Mesa for iOS arm64
# Requires: Meson, Ninja, iOS SDK (Xcode), Python 3
#
# Usage:
#   cd Natives/external/mesa
#   chmod +x build_mesa_ios.sh
#   ./build_mesa_ios.sh [version]
#
#   version: "25.0.7" (OSMesa) or "26.2.2" (EGL) - default: "26.2.2"
#
# The resulting dylibs will be placed in ../../resources/Frameworks/

set -euo pipefail

MESA_VERSION="${1:-26.2.2}"
MESA_TAG="mesa-${MESA_VERSION}"

if [ "${MESA_VERSION}" = "25.0.7" ]; then
    BUILD_VARIANT="osmesa"
else
    BUILD_VARIANT="egl"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MESA_SRC_DIR="${SCRIPT_DIR}/mesa-src-${MESA_VERSION}"
MESA_BUILD_DIR="${SCRIPT_DIR}/mesa-build-${MESA_VERSION}"
INSTALL_DIR="${SCRIPT_DIR}/mesa-install-${MESA_VERSION}"
FRAMEWORKS_DIR="${SCRIPT_DIR}/../../resources/Frameworks"

# Detect Xcode SDK
IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
IOS_MIN_VERSION="16.0"

echo "=== Mesa ${MESA_VERSION} (${BUILD_VARIANT}) iOS Cross-Compilation ==="
echo "iOS SDK: ${IOS_SDK}"
echo "Min version: ${IOS_MIN_VERSION}"

# Step 1: Clone Mesa if not already present
if [ ! -d "${MESA_SRC_DIR}" ]; then
    echo "=== Cloning Mesa ${MESA_TAG} ==="
    git clone --depth 1 --branch "${MESA_TAG}" \
        https://gitlab.freedesktop.org/mesa/mesa.git "${MESA_SRC_DIR}"
fi

cd "${MESA_SRC_DIR}"

# Step 2: Install Python dependencies
echo "=== Installing Python dependencies ==="
pip3 install meson ninja mako pyyaml setuptools 2>/dev/null || true

# Step 3: Create Meson cross-file for iOS
CROSS_FILE="${MESA_SRC_DIR}/cross-ios-arm64.txt"
cat > "${CROSS_FILE}" << EOF
[binaries]
c = 'xcrun --sdk iphoneos clang'
cpp = 'xcrun --sdk iphoneos clang++'
ar = 'xcrun --sdk iphoneos ar'
strip = 'xcrun --sdk iphoneos strip'
nm = 'xcrun --sdk iphoneos nm'
ranlib = 'xcrun --sdk iphoneos ranlib'
swift = 'xcrun --sdk iphoneos swiftc'
cmake = 'cmake'

[host_machine]
system = 'darwin'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'

[properties]
sys_root = '${IOS_SDK}'
needs_exe_wrapper = false

[built-in options]
c_args = ['-arch', 'arm64', '-isysroot', '${IOS_SDK}', '-miphoneos-version-min=${IOS_MIN_VERSION}', '-fembed-bitcode-marker', '-O2', '-fPIC']
cpp_args = ['-arch', 'arm64', '-isysroot', '${IOS_SDK}', '-miphoneos-version-min=${IOS_MIN_VERSION}', '-fembed-bitcode-marker', '-O2', '-fPIC', '-std=c++17']
c_link_args = ['-arch', 'arm64', '-isysroot', '${IOS_SDK}', '-miphoneos-version-min=${IOS_MIN_VERSION}', '-dynamiclib', '-Wl,-rpath,@loader_path']
cpp_link_args = ['-arch', 'arm64', '-isysroot', '${IOS_SDK}', '-miphoneos-version-min=${IOS_MIN_VERSION}', '-dynamiclib', '-Wl,-rpath,@loader_path']
default_library = 'shared'
strip = true
EOF

# Step 4: Configure with Meson
echo "=== Configuring Mesa ${MESA_VERSION} (${BUILD_VARIANT}) ==="
rm -rf "${MESA_BUILD_DIR}"

if [ "${BUILD_VARIANT}" = "osmesa" ]; then
    # Mesa 25.0.7 - OSMesa backend (Zink via OSMesa)
    meson setup "${MESA_BUILD_DIR}" "${MESA_SRC_DIR}" \
        --cross-file "${CROSS_FILE}" \
        --prefix="${INSTALL_DIR}" \
        -Dplatforms= \
        -Dosmesa=true \
        -Degl=false \
        -Dglx=disabled \
        -Dgallium-drivers=zink \
        -Dvulkan-drivers= \
        -Ddri-drivers= \
        -Dgallium-llvm=disabled \
        -Dshader-cache=false \
        -Dshader-cache-evicts-nop=false \
        -Dgallium-xlib=disabled \
        -Dglx-direct=false \
        -Dgbm=disabled \
        -Dvulkan-icd-dir="" \
        -Dprefix="${INSTALL_DIR}" \
        -Dlibdir=lib \
        -Dbindir=bin
else
    # Mesa 26.2.2 - EGL backend (Zink via EGL)
    meson setup "${MESA_BUILD_DIR}" "${MESA_SRC_DIR}" \
        --cross-file "${CROSS_FILE}" \
        --prefix="${INSTALL_DIR}" \
        -Dplatforms= \
        -Dosmesa=false \
        -Degl=true \
        -Dglx=disabled \
        -Dgallium-drivers=zink \
        -Dvulkan-drivers= \
        -Ddri-drivers= \
        -Dgallium-llvm=disabled \
        -Dshader-cache=false \
        -Dshader-cache-evicts-nop=false \
        -Dgallium-xlib=disabled \
        -Dglx-direct=false \
        -Dgbm=disabled \
        -Dvulkan-icd-dir="" \
        -Dprefix="${INSTALL_DIR}" \
        -Dlibdir=lib \
        -Dbindir=bin
fi

# Step 5: Build
echo "=== Building Mesa ${MESA_VERSION} ==="
ninja -C "${MESA_BUILD_DIR}" -j$(sysctl -n hw.ncpu)

# Step 6: Install
echo "=== Installing Mesa ${MESA_VERSION} ==="
ninja -C "${MESA_BUILD_DIR}" install

# Step 7: Copy dylibs to Frameworks
echo "=== Copying dylibs to Frameworks ==="
if [ "${BUILD_VARIANT}" = "osmesa" ]; then
    cp -v "${INSTALL_DIR}/lib/libOSMesa.8.dylib" "${FRAMEWORKS_DIR}/" 2>/dev/null || true
    cp -v "${INSTALL_DIR}/lib/libOSMesaCore.8.dylib" "${FRAMEWORKS_DIR}/" 2>/dev/null || true
else
    cp -v "${INSTALL_DIR}/lib/libEGL.1.dylib" "${FRAMEWORKS_DIR}/libEGL_26.dylib" 2>/dev/null || true
    cp -v "${INSTALL_DIR}/lib/libGLESv2.1.dylib" "${FRAMEWORKS_DIR}/libGLESv2_26.dylib" 2>/dev/null || true
fi

echo ""
echo "=== Mesa ${MESA_VERSION} (${BUILD_VARIANT}) build complete! ==="
echo "Dylibs installed to: ${FRAMEWORKS_DIR}"
