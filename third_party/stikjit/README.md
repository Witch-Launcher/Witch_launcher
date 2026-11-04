# StikJIT

`StikJIT.xcframework` enables JIT for another process over the device's RSD
tunnel. Witch uses it only inside `WitchJITHelper.appex`; the launcher itself
never links or loads it.

- Upstream: https://github.com/StikDebug/StikJIT
- Version: **2.0.1**
- License: MPL-2.0 (`LICENSE` in this directory)
- Integration guide: https://github.com/StikDebug/StikJIT/blob/main/INTEGRATION.md

The checked-in `ios-arm64` slice was rebuilt from the 2.0.1 tag with the
toolchain used by this project so its `.swiftinterface` can be imported by
Xcode 26 / Swift 6.2. Upstream release binaries are built with a newer Swift
compiler and are not importable by older Xcode versions.

To rebuild the slice:

```sh
git clone --depth 1 --branch 2.0.1 https://github.com/StikDebug/StikJIT.git /tmp/StikJIT-src
cd /tmp/StikJIT-src
xcodegen generate
xcodebuild -project StikJIT.xcodeproj -target StikJIT -sdk iphoneos \
  -configuration Release SYMROOT=/tmp/StikJIT-sym OBJROOT=/tmp/StikJIT-obj \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  ONLY_ACTIVE_ARCH=NO ARCHS=arm64 build
cp -R /tmp/StikJIT-sym/Release-iphoneos/StikJIT.framework \
  third_party/stikjit/StikJIT.xcframework/ios-arm64/
```

StikJIT is based on StikDebug and bundles the idevice FFI and JIT scripts,
which retain their own upstream licenses.

The bundled `universal.js` and `legacy.js` files were removed from this copy
because Witch always supplies its own `UniversalJIT26.js` through
`StikJIT.Script.customBase64`. Those scripts come from StikDebug (AGPL-3.0)
and are not part of Witch's distribution. Do not use `.universal` or `.legacy`
with this copy.
