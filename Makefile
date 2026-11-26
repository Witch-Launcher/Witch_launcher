SHELL := /bin/bash
.SHELLFLAGS = -ec
# Use `make VERBOSE=1` to print commands.
$(VERBOSE).SILENT:

# Prerequisite variables
SOURCEDIR   := $(shell printf "%q\n" "$(shell pwd)")
OUTPUTDIR   := $(SOURCEDIR)/artifacts
WORKINGDIR  := $(SOURCEDIR)/Natives/build
DETECTPLAT  := $(shell uname -s)
DETECTARCH  := $(shell uname -m)
VERSION     := $(shell plutil -extract CFBundleShortVersionString raw -o - Natives/Info.plist 2>/dev/null || echo "1.0")
BRANCH      := $(shell git branch --show-current 2>/dev/null || echo "unknown")
COMMIT      := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
PLATFORM    ?= 2

# Release vs Debug
RELEASE ?= 0

# Check if running on github runner
RUNNER ?= 0

# Check if slimmed should be built
SLIMMED ?= 0

# Check if slimmed should be built, and additionally skip normal build
SLIMMED_ONLY ?= 0

# How JREs are obtained: build = compile OpenJDK from source (default),
# download = fetch the prebuilt iOS packages from angelauramc.dev.
# `make jre-download` forces download mode for that invocation.
JRE_BUILD_MODE ?= build
JRE_VERSIONS   ?= 8 17 21 25

# If not in a GitHub repository, default to these
# so that compiling doesn't fail
ifeq (,$(BRANCH))
BRANCH := unknown
endif
ifeq (,$(COMMIT))
BRANCH := unknown
endif


# Team IDs and provisioning profile for the codesign function
# Default to -1 for check
# Currently requires a paid Apple Developer account, will fix later
SIGNING_TEAMID ?= -1
TEAMID ?= -1
PROVISIONING ?= -1

ifeq (1,$(RELEASE))
CMAKE_BUILD_TYPE := Release
else
CMAKE_BUILD_TYPE := Debug
endif


# Distinguish iOS from macOS, and *OS from others
ifeq ($(DETECTPLAT),Darwin)
OSVER       := $(shell sw_vers -productVersion | cut -b 1-2)
ifeq ($(shell sw_vers -productName),macOS)
IOS         := 0
SDKPATH     ?= $(shell xcrun --sdk iphoneos --show-sdk-path)
BOOTJDK     ?= $(shell /usr/libexec/java_home -v 1.8)/bin
$(warning Building on macOS.)
else
IOS         := 1
SDKPATH     ?= /usr/share/SDKs/iPhoneOS.sdk
BOOTJDK     ?= /usr/lib/jvm/java-8-openjdk/bin
ifeq ($(shell test "$(OSVER)" -gt 14; echo $$?),0)
PREFIX      ?= /var/jb/
else
PREFIX      ?= /
endif
$(warning Building on iOS. Note that all targets may not compile or require external components.)
endif
else ifeq ($(DETECTPLAT),Linux)
IOS         := 0
# SDKPATH presence is checked later
BOOTJDK     ?= /usr/bin
$(warning Building on Linux. Note that all targets may not compile or require external components.)
else
$(error This platform is not currently supported for building Witch.)
endif

# Define PLATFORM_NAME from PLATFORM
ifeq ($(PLATFORM),2)
PLATFORM_NAME := ios
$(warning Set PLATFORM to 2, which is equal to iOS.)
else ifeq ($(PLATFORM),3)
PLATFORM_NAME := tvos
$(warning Set PLATFORM to 3, which is equal to tvOS.)
else ifeq ($(PLATFORM),6)
PLATFORM_NAME := maccatalyst
$(warning Set PLATFORM to 6, which is equal to Mac Catalyst.)
else ifeq ($(PLATFORM),7)
PLATFORM_NAME := iossimulator
$(warning Set PLATFORM to 7, which is equal to iOS Simulator.)
else ifeq ($(PLATFORM),8)
PLATFORM_NAME := tvossimulator
$(warning Set PLATFORM to 8, which is equal to tvOS Simulator.)
else ifeq ($(PLATFORM),11)
PLATFORM_NAME := xros
$(warning Set PLATFORM to 11, which is equal to visionOS.)
else ifeq ($(PLATFORM),12)
PLATFORM_NAME := xrsimulator
$(warning Set PLATFORM to 12, which is equal to visionOS Simulator.)
else
$(error PLATFORM is not valid.)
endif

POJAV_BUNDLE_DIR      ?= $(OUTPUTDIR)/Witch.app
POJAV_JRE8_DIR        ?= $(SOURCEDIR)/depends/java-8-openjdk
POJAV_JRE17_DIR       ?= $(SOURCEDIR)/depends/java-17-openjdk
POJAV_JRE21_DIR       ?= $(SOURCEDIR)/depends/java-21-openjdk
POJAV_JRE25_DIR       ?= $(SOURCEDIR)/depends/java-25-openjdk
STIKJIT_XCFRAMEWORK  := $(SOURCEDIR)/third_party/stikjit/StikJIT.xcframework
WITCH_JIT_HELPER_DIR := $(SOURCEDIR)/tools/WitchJITHelper
WITCH_JIT_HELPER_BUILD := $(WORKINGDIR)/jit-helper-build
# App icon set to use: AppIcon-Light (official) or AppIcon-Development (dev builds).
# Non-release builds carry the dev logo (local `make` + the GitHub beta
# workflow); only RELEASE=1 builds keep the official blue one.
ifeq (1,$(RELEASE))
APP_ICON              ?= AppIcon-Light
else
APP_ICON              ?= AppIcon-Development
endif

# Function to use later for checking dependencies
METHOD_DEPCHECK   = $(shell $(1) >/dev/null 2>&1 && echo 1)

# Function to modify Info.plist files
METHOD_INFOPLIST  =  \
	if [ '$(4)' = '0' ]; then \
		plutil -replace $(1) -string $(2) $(3); \
	else \
		plutil -value $(2) -key $(1) $(3); \
	fi

# Function to check directories
METHOD_DIRCHECK   = \
	if [ ! -d '$(1)' ]; then \
		mkdir -p $(1); \
	else \
		rm -rf $(1)/*; \
	fi
	
# Function to change the platform on Mach-O files.
# iOS = 2, tvOS = 3, iOS Simulator = 7, tvOS Simulator = 8, visionOS = 11, visionOS Simulator = 12
# https://github.com/apple-oss-distributions/xnu/blob/main/EXTERNAL_HEADERS/mach-o/loader.h
# TODO: Change Info.plist for visionOS 1.0
METHOD_CHANGE_PLAT = \
	if [ '$(1)' != '11' ] && [ '$(1)' != '12' ]; then \
		vtool -arch arm64 -set-build-version $(1) 14.0 16.0 -replace -output $(2) $(2); \
		ldid -S -M $(2); \
	else \
		vtool -arch arm64 -set-build-version $(1) 1.0 1.0 -replace -output $(2) $(2); \
	fi \
	
# Function to package the application
METHOD_PACKAGE = \
	if [ '$(TROLLSTORE_JIT_ENT)' == '1' ]; then \
		IPA_SUFFIX="-trollstore.tipa"; \
	else \
		IPA_SUFFIX=".ipa"; \
	fi; \
	rm -f $(OUTPUTDIR)/Witch-$(VERSION)-$(PLATFORM_NAME)$$IPA_SUFFIX; \
	if [ '$(SLIMMED_ONLY)' = '0' ]; then \
		zip --symlinks -r $(OUTPUTDIR)/Witch-$(VERSION)-$(PLATFORM_NAME)$$IPA_SUFFIX Payload; \
	fi; \
	if [ '$(SLIMMED)' = '1' ] || [ '$(SLIMMED_ONLY)' = '1' ]; then \
		rm -f $(OUTPUTDIR)/Witch-slimmed-$(VERSION)-$(PLATFORM_NAME)$$IPA_SUFFIX; \
		zip --symlinks -r $(OUTPUTDIR)/Witch-slimmed-$(VERSION)-$(PLATFORM_NAME)$$IPA_SUFFIX Payload --exclude='Payload/Witch.app/java_runtimes/*'; \
	fi

# Function to codesign binaries.
METHOD_CODESIGN = \
	codesign --remove-signature $(2); \
	codesign -f -s $(1) --generate-entitlement-der --entitlements entitlements.codesign.xml $(2); \
	printf 'File: '; printf $(2); printf ', Codesigned with team: '; printf $(1); printf '\n'

# Function to run code when finding Mach-O files.
METHOD_MACHO = \
	for file in $$(find $(1)); do \
		if [[ "$$(file $$file)" == *"Mach-O"* ]]; then \
			$(2); \
		fi; \
	done

# Like METHOD_MACHO but skip libjvm.dylib — pre-built iOS JREs are already tagged;
# vtool/ldid on the ~100 MB JVM can corrupt dyld rebase metadata.
METHOD_MACHO_JRE = \
	for file in $$(find $(1)); do \
		if [[ "$$file" == *"/lib/server/libjvm.dylib" ]]; then \
			continue; \
		fi; \
		if [[ "$$file" == *"/PlugIns/"* || "$$file" == *"/Frameworks/StikJIT.framework/"* ]]; then \
			continue; \
		fi; \
		if [[ "$$(file $$file)" == *"Mach-O"* ]]; then \
			$(2); \
		fi; \
	done

# Make sure everything is already available for use. Error if they require something
ifneq ($(call METHOD_DEPCHECK,cmake --version),1)
$(error You need to install cmake)
endif

ifneq ($(call METHOD_DEPCHECK,$(BOOTJDK)/javac -version),1)
$(error You need to install JDK 8)
endif

ifeq ($(IOS),0)
ifeq ($(filter 1.8.0,$(shell $(BOOTJDK)/javac -version &> javaver.txt && cat javaver.txt | cut -b 7-11 && rm -rf javaver.txt)),)
$(error You need to install JDK 8)
endif
endif

ifneq ($(call METHOD_DEPCHECK,ldid),1)
$(error You need to install ldid)
endif

ifneq ($(call METHOD_DEPCHECK,wget --version),1)
$(error You need to install wget)
endif

ifeq ($(DETECTPLAT),Linux)
ifneq ($(call METHOD_DEPCHECK,lld),1)
$(error You need to install lld)
endif
endif

ifneq ($(filter sysctl,$(shell sysctl -n hw.logicalcpu)),)
ifneq ($(call METHOD_DEPCHECK,nproc --version),1)
ifneq ($(call METHOD_DEPCHECK,gnproc --version),1)
$(warning Unable to determine number of threads, defaulting to 2.)
JOBS   ?= 2
else
JOBS   ?= $(shell gnproc)
endif
else
JOBS   ?= $(shell nproc)
endif
else
JOBS   ?= $(shell sysctl -n hw.logicalcpu)
endif

ifndef SDKPATH
$(error You need to specify SDKPATH to the path of iPhoneOS.sdk. The SDK version should be 14.0 or newer.)
endif

all: clean lwgjl native dep_moltenvk dep_mesa_zink dep_angle java jre assets payload package dsym

help:
	echo 'Makefile to compile Witch'
	echo ''
	echo 'Usage:'
	echo '    make                                Makes everything under all'
	echo '    make help                           Displays this message'
	echo '    make all                            Builds the entire app'
	echo '    make native                         Builds the native app'
	echo '    make java                           Builds the Java app'
	echo '    make lwgjl                          Builds LWGJL 3.3.3 and 3.4.1 from source'
	echo '    make jre                            Downloads/unpacks the iOS JREs'
	echo '    make assets                         Compiles Assets.xcassets'
	echo '    make payload                        Makes Payload/Witch.app'
	echo '    make package                        Builds ipa of Witch'
	echo '    make deploy                         Copies files to local iDevice'
	echo '    make dsym                           Generate debug symbol files'
	echo '    make clean                          Cleans build directories'
	echo '    make check                          Dump all variables for checking'

check:
	$(foreach v, \
		$(shell echo "$(filter-out METHOD_% .% MAKEFILE_LIST MAKEFLAGS CURDIR,$(.VARIABLES))" | tr ' ' '\n' | sort), \
		$(if $(filter file,$(origin $(v))), \
		$(info $(shell printf "%-20s" "$(v)") = $(value $(v)))) \
	)

native: dep_mg
	echo '[Witch v$(VERSION)] native - start'
	mkdir -p $(WORKINGDIR)
	cd $(WORKINGDIR) && cmake \
		-DCMAKE_BUILD_TYPE=$(CMAKE_BUILD_TYPE) \
		-DCMAKE_CROSSCOMPILING=true \
		-DCMAKE_SYSTEM_NAME=Darwin \
		-DCMAKE_SYSTEM_PROCESSOR=aarch64 \
		-DCMAKE_OSX_SYSROOT="$(SDKPATH)" \
		-DCMAKE_OSX_ARCHITECTURES=arm64 \
		-DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
		-DCMAKE_C_FLAGS="-arch arm64" \
		-DCMAKE_MAKE_PROGRAM=/usr/bin/make \
		-DCONFIG_BRANCH="$(BRANCH)" \
		-DCONFIG_COMMIT="$(COMMIT)" \
		-DCONFIG_RELEASE=$(RELEASE) \
		..

	cmake --build $(WORKINGDIR) --config $(CMAKE_BUILD_TYPE) -j$(JOBS)
	python3 $(SOURCEDIR)/scripts/inject_oauth_schemes.py "$(WORKINGDIR)/Witch.app/Info.plist" "$(WITCH_GOOGLE_DRIVE_CLIENT_ID)" "$(WITCH_DROPBOX_APP_KEY)" || exit 1
	#	--target awt_headless awt_xawt libOSMesaOverride.dylib tinygl4angle Witch
	-rm -f $(WORKINGDIR)/libawt_headless.dylib
	echo '[Witch v$(VERSION)] native - end'

java: lwgjl
	echo '[Witch v$(VERSION)] java - start'
	# lwgjl must finish first: the java compile classpath includes
	# libs/lwjgl{,36,41}/lwjgl.jar, and the lwgjl target writes those jars.
	# Running java in parallel reads partially-written/empty zip files.
	# Each .java file compiles in its own javac VM (JavaApp Makefile), so keep
	# parallelism low: running 10+ javac VMs concurrently with the parallel
	# native/lwgjl/dep_mg jobs exhausts CI runner memory and crashes javac
	# (SIGABRT in _platform_memmove).
	$(MAKE) -C JavaApp -j2 BOOTJDK=$(BOOTJDK)
	echo '[Witch v$(VERSION)] java - end'

jre: native
	echo '[Witch v$(VERSION)] jre - start'
	mkdir -p $(SOURCEDIR)/depends
	@if [ '$(JRE_BUILD_MODE)' = 'download' ]; then \
		echo '[Witch] JRE_BUILD_MODE=download: fetching prebuilt packages'; \
	else \
		echo '[Witch] JRE_BUILD_MODE=build: building from source'; \
		for ver in $(JRE_VERSIONS); do \
			if [ ! -f "$(SOURCEDIR)/depends/java-$${ver}-openjdk/release" ]; then \
				bash $(SOURCEDIR)/scripts/jre-build/build.sh $$ver || exit 1; \
			else \
				echo "[Witch] java-$${ver}-openjdk already present, skipping build"; \
			fi; \
		done; \
	fi
	cd $(SOURCEDIR)/depends; \
	unpack_jre() { \
		ver="$$1"; url="$$2"; \
		if [ -f "java-$${ver}-openjdk/release" ]; then echo "[Witch] java-$${ver}-openjdk already unpacked, skip"; return 0; fi; \
		if ls jre$${ver}-*.tar.xz >/dev/null 2>&1; then \
			echo "[Witch] extracting jre$${ver}-*.tar.xz"; \
			mkdir -p "java-$${ver}-openjdk"; tar xf jre$${ver}-*.tar.xz -C "java-$${ver}-openjdk"; return 0; \
		fi; \
		if ! ls jre$${ver}-*.tar.xz >/dev/null 2>&1; then \
			echo "[Witch] downloading jre$${ver} ..."; \
			wget -q --tries=4 --waitretry=5 -O "jre$${ver}-ios-aarch64.tar.xz" "$$url"; \
		fi; \
		mkdir -p "java-$${ver}-openjdk"; \
		tar xf "jre$${ver}-ios-aarch64.tar.xz" -C "java-$${ver}-openjdk"; \
	}; \
	for ver in $(JRE_VERSIONS); do \
		unpack_jre "$$ver" "https://github.com/Witch-Launcher/JDK-Java_iOS/releases/download/jre-runtimes-20261108/jre$${ver}-ios-aarch64.tar.xz"; \
	done; \
	if ls jre*.tar.xz >/dev/null 2>&1; then rm -f jre*.tar.xz; fi; \
	rm -rf $(SOURCEDIR)/depends/java-{8,17,21,25}-openjdk/{ASSEMBLY_EXCEPTION,bin,include,jre,legal,LICENSE,man,THIRD_PARTY_README,lib/{ct.sym,jspawnhelper,libjsig.dylib,src.zip,tools.jar}}; \
	rm -f $(SOURCEDIR)/depends/java-{8,17,21,25}-openjdk/.amethyst-mirror-mapping; \
	rm -f $(SOURCEDIR)/depends/java-{8,17,21,25}-openjdk/.witch-mirror-mapping; \
	for ver in 17 21; do \
		jvm="$(SOURCEDIR)/depends/java-$$ver-openjdk/lib/server/libjvm.dylib"; \
		if [ -f "$$jvm" ]; then \
			python3 $(SOURCEDIR)/scripts/patch_jre_mirror_runtime.py $$ver "$$jvm" || true; \
		fi; \
	done; \
	jvm25="$(SOURCEDIR)/depends/java-25-openjdk/lib/server/libjvm.dylib"; \
	if [ -f "$$jvm25" ]; then \
		python3 $(SOURCEDIR)/scripts/patch_jre25_runtime.py "$$jvm25" || true; \
	fi; \
	for ver in $(JRE_VERSIONS); do \
		jvm="$(SOURCEDIR)/depends/java-$$ver-openjdk/lib/server/libjvm.dylib"; \
		marker="$(SOURCEDIR)/depends/java-$$ver-openjdk/.witch-mirror-mapping"; \
		if [ -f "$$jvm" ]; then \
			if python3 $(SOURCEDIR)/scripts/patch_libjvm_mirror_brk.py "$$jvm" && \
			   python3 $(SOURCEDIR)/scripts/patch_libjvm_jit_alloc.py "$$jvm" && \
			   python3 $(SOURCEDIR)/scripts/jre-build/check_libjvm_patch.py "$$jvm"; then \
				printf 'witch-mirror-mapping-v1\n' > "$$marker"; \
				echo "[jre] Java $$ver mirror brk patches OK (marker written)"; \
			else \
				rm -f "$$marker"; \
				echo "[jre] ERROR: Java $$ver libjvm is not mirror-patched (no brk #0x6a/#0xf00d hooks)"; \
				echo "[jre] ERROR: no marker written — the launcher will refuse this runtime on iOS 26+ instead of black-screening"; \
				echo "[jre] ERROR: the source build must include the JIT26 mirror patches (see scripts/jre-build/patches); the published assets are used with JRE_BUILD_MODE=download"; \
			fi; \
		fi; \
	done; \
	for ver in $(JRE_VERSIONS); do \
		jvm="$(SOURCEDIR)/depends/java-$$ver-openjdk/lib/server/libjvm.dylib"; \
		if [ -f "$$jvm" ]; then \
			if ! otool -l "$$jvm" >/dev/null 2>&1; then \
				echo "[jre] ERROR: libjvm.dylib for Java $$ver failed Mach-O validation (corrupt build/download?)"; \
				exit 1; \
			fi; \
		fi; \
	done; \
	$(MAKE) -C $(SOURCEDIR) verify-jres || { echo "[jre] ERROR: JRE verification failed" >&2; exit 1; }; \
	$(call METHOD_DIRCHECK,$(OUTPUTDIR)/java_runtimes); \
	cp -R $(POJAV_JRE8_DIR) $(OUTPUTDIR)/java_runtimes; \
	cp -R $(POJAV_JRE17_DIR) $(OUTPUTDIR)/java_runtimes; \
	cp -R $(POJAV_JRE21_DIR) $(OUTPUTDIR)/java_runtimes; \
	cp -R $(POJAV_JRE25_DIR) $(OUTPUTDIR)/java_runtimes; \
	cp $(WORKINGDIR)/libawt_xawt.dylib $(OUTPUTDIR)/java_runtimes/java-8-openjdk/lib; \
	cp $(WORKINGDIR)/libawt_xawt.dylib $(OUTPUTDIR)/java_runtimes/java-17-openjdk/lib;
	cp $(WORKINGDIR)/libawt_xawt.dylib $(OUTPUTDIR)/java_runtimes/java-21-openjdk/lib
	cp $(WORKINGDIR)/libawt_xawt.dylib $(OUTPUTDIR)/java_runtimes/java-25-openjdk/lib
	echo '[Witch v$(VERSION)] jre - end'

# Force the download based flow for this invocation.
jre-download:
	$(MAKE) jre JRE_BUILD_MODE=download

# Validate every bundled runtime before it is copied into the app.
verify-jres:
	echo '[Witch v$(VERSION)] verify-jres - start'
	for ver in $(JRE_VERSIONS); do \
		if [ -d "$(SOURCEDIR)/depends/java-$${ver}-openjdk" ]; then \
			bash $(SOURCEDIR)/scripts/jre-build/verify_jre.sh $$ver || exit 1; \
		fi; \
	done
	echo '[Witch v$(VERSION)] verify-jres - end'

 dep_mg:
	echo '[Witch v$(VERSION)] dep_mg - start'
	mkdir -p $(WORKINGDIR)/mobileglues
	cd $(WORKINGDIR)/mobileglues && cmake \
		-DCMAKE_CROSSCOMPILING=true \
		-DCMAKE_SYSTEM_NAME=Darwin \
		-DCMAKE_SYSTEM_PROCESSOR=aarch64 \
		-DCMAKE_OSX_SYSROOT="$(SDKPATH)" \
		-DCMAKE_OSX_ARCHITECTURES=arm64 \
		-DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
		-DCMAKE_C_FLAGS="-arch arm64" \
		-DCMAKE_MAKE_PROGRAM=/usr/bin/make \
		-DSPIRV_CROSS_SHARED="ON" \
		$(SOURCEDIR)/Natives/external/MobileGlues/src/main/cpp/

	cmake --build $(WORKINGDIR)/mobileglues --config RelWithDebInfo -j$(JOBS) --target mobileglues
	cp $(WORKINGDIR)/mobileglues/libmobileglues*.dylib $(WORKINGDIR)/
	cp $(WORKINGDIR)/mobileglues/libspirv-cross*.dylib $(WORKINGDIR)/ 2>/dev/null || true
	echo '[Witch v$(VERSION)] dep_mg - end'

# SPIRV-Cross C API shared library used by Minecraft's OpenGL backend
# (com.mojang.renderpearl -> org.lwjgl.util.spvc). The MobileGlues prebuilt
# copy is built for Apple Silicon macOS CPUs, so clang emits ARMv8.3 LDAPR*
# (RCpc) instructions in thread-safe static guards; A11/A10 (iPhone 8 and
# older) are ARMv8.2 and crash with SIGILL on the first spvc compile.
# Build it here for the real iOS target with a generic ARMv8.0 CPU instead of
# shipping the prebuilt.
spvc:
	echo '[Witch v$(VERSION)] spvc - start'
	mkdir -p $(WORKINGDIR)/spvc
	# Root-cause fix (2026-10-27, session 5): the slim build (MSL/HLSL/CPP/
	# REFLECT/UTIL OFF) shipped in 0.0.4 regressed frame rate on-device —
	# MC 26.3 RenderPearl parses/reflects SPIR-V through LWJGL spvc and the
	# missing backend pieces forced slower fallback paths on every new
	# pipeline. The verified-good device build (Witch-0.0.4-ios.ipa @2026-10-27)
	# keeps pin be71ee8 and turns ALL backends ON, still -mcpu=generic and
	# guarded below against ARMv8.3 atomics for A11/A10.
	cd $(WORKINGDIR)/spvc && cmake \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_SYSTEM_NAME=iOS \
		-DCMAKE_OSX_SYSROOT="$(SDKPATH)" \
		-DCMAKE_OSX_ARCHITECTURES=arm64 \
		-DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
		-DCMAKE_C_FLAGS="-mcpu=generic" \
		-DCMAKE_CXX_FLAGS="-mcpu=generic" \
		-DCMAKE_MAKE_PROGRAM=/usr/bin/make \
		-DSPIRV_CROSS_SHARED=ON \
		-DSPIRV_CROSS_STATIC=OFF \
		-DSPIRV_CROSS_CLI=OFF \
		-DSPIRV_CROSS_ENABLE_TESTS=OFF \
		-DSPIRV_CROSS_ENABLE_C_API=ON \
		-DSPIRV_CROSS_ENABLE_GLSL=ON \
		-DSPIRV_CROSS_ENABLE_HLSL=ON \
		-DSPIRV_CROSS_ENABLE_MSL=ON \
		-DSPIRV_CROSS_ENABLE_CPP=ON \
		-DSPIRV_CROSS_ENABLE_REFLECT=ON \
		-DSPIRV_CROSS_ENABLE_UTIL=ON \
		$(SOURCEDIR)/Natives/external/MobileGlues/src/main/cpp/3rdparty/SPIRV-Cross/
	cmake --build $(WORKINGDIR)/spvc --config Release -j$(JOBS) --target spirv-cross-c-shared
	cp $(WORKINGDIR)/spvc/libspirv-cross-c-shared.0.dylib $(WORKINGDIR)/libspirv-cross-c-shared.0.dylib
	cp $(WORKINGDIR)/spvc/libspirv-cross-c-shared.0.dylib $(SOURCEDIR)/Natives/resources/Frameworks/libspirv-cross-c-shared.0.dylib
	@if otool -tvV $(WORKINGDIR)/libspirv-cross-c-shared.0.dylib | grep -qE '\b(ldapr|stllr)'; then \
		echo 'ERROR: libspirv-cross still uses ARMv8.3 atomics (unsupported on A11/A10)'; exit 1; \
	fi
	echo '[Witch v$(VERSION)] spvc - end'

dep_mobilegl:
	echo '[Witch v$(VERSION)] dep_mobilegl - start'
	@if [ ! -f "$(SOURCEDIR)/Natives/external/MobileGL/CMakeLists.txt" ]; then \
		echo '[Witch] MobileGL source missing (submodule not checked out) - using vendored libMobileGL.dylib'; \
		test -f "$(SOURCEDIR)/Natives/resources/Frameworks/libMobileGL.dylib" || { echo 'ERROR: vendored libMobileGL.dylib missing too'; exit 1; }; \
		cp "$(SOURCEDIR)/Natives/resources/Frameworks/libMobileGL.dylib" "$(WORKINGDIR)/libMobileGL.dylib"; \
	else \
		echo '[Witch] Building MobileGL from source (two-level namespace, no flat_namespace)'; \
		mkdir -p $(WORKINGDIR)/mobilegl; \
		cd $(WORKINGDIR)/mobilegl && cmake \
			-DCMAKE_CROSSCOMPILING=true \
			-DCMAKE_BUILD_TYPE=Release \
			-DCMAKE_SYSTEM_NAME=iOS \
			-DCMAKE_OSX_SYSROOT="$(SDKPATH)" \
			-DCMAKE_OSX_ARCHITECTURES=arm64 \
			-DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
			-DCMAKE_C_FLAGS="-arch arm64" \
			-DCMAKE_MAKE_PROGRAM=/usr/bin/make \
			-DMOBILEGL_IOS=ON \
			-DMOBILEGL_BACKEND_TYPE=DirectVulkan \
			-DMOBILEGL_BUILD_TEST=OFF \
			-DMOBILEGL_BUILD_BENCHMARK=OFF \
			-DMOBILEGL_VULKAN_LIBRARY="$(SOURCEDIR)/Natives/resources/Frameworks/libMoltenVK.dylib" \
			-DSPIRV_CROSS_SHARED="ON" \
			-DCMAKE_SHARED_LINKER_FLAGS="-L$(SOURCEDIR)/Natives/resources/Frameworks -lc++_cxx23 -lc++abi_cxx23 -Wl,-undefined,error" \
			$(SOURCEDIR)/Natives/external/MobileGL/; \
		cmake --build $(WORKINGDIR)/mobilegl --config Release -j$(JOBS) --target MobileGL; \
		cp $(WORKINGDIR)/mobilegl/libMobileGL*.dylib $(WORKINGDIR)/ 2>/dev/null || true; \
		cp $(WORKINGDIR)/mobilegl/libMobileGL_s.a $(WORKINGDIR)/ 2>/dev/null || true; \
		cp $(WORKINGDIR)/libMobileGL.dylib $(SOURCEDIR)/Natives/resources/Frameworks/libMobileGL.dylib; \
		install_name_tool -change @rpath/libMoltenVK.1.dylib @rpath/libMoltenVK.dylib $(WORKINGDIR)/libMobileGL.dylib; \
		install_name_tool -change @rpath/libMoltenVK.1.dylib @rpath/libMoltenVK.dylib $(SOURCEDIR)/Natives/resources/Frameworks/libMobileGL.dylib; \
	fi
	echo '[Witch v$(VERSION)] dep_mobilegl - end'

TGLES_SRC ?= /Volumes/project/TGLES
TGLMT_SRC ?= /Volumes/project/TGLMT
dep_tglmt:
	echo '[Witch v$(VERSION)] dep_tglmt - start'
	mkdir -p "$(WORKINGDIR)"
	if [ -d "$(TGLMT_SRC)" ]; then \
		cmake --fresh -S "$(TGLMT_SRC)" -B "$(TGLMT_SRC)/build-ios-pkg" \
			-DCMAKE_SYSTEM_NAME=iOS \
			-DCMAKE_OSX_SYSROOT="$(SDKPATH)" \
			-DCMAKE_OSX_ARCHITECTURES=arm64 \
			-DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
			-DCMAKE_BUILD_TYPE=Release \
			-DTGLMT_APPLE_METAL=ON \
			-DTGLMT_BUILD_TESTS=OFF \
			-DTGLMT_BUILD_SHARED=ON && \
		cmake --build "$(TGLMT_SRC)/build-ios-pkg" --config Release && \
		cp "$(TGLMT_SRC)/build-ios-pkg/libtglmt.dylib" \
			"$(SOURCEDIR)/Natives/resources/Frameworks/libtglmt.dylib" && \
		cp "$(TGLMT_SRC)/build-ios-pkg/libtglmt.dylib" \
			"$(WORKINGDIR)/libtglmt.dylib"; \
	else \
		echo '[Witch] TGLMT_SRC not found at $(TGLMT_SRC), keeping vendored libtglmt.dylib'; \
		cp "$(SOURCEDIR)/Natives/resources/Frameworks/libtglmt.dylib" \
			"$(WORKINGDIR)/libtglmt.dylib"; \
	fi
	test -f "$(SOURCEDIR)/Natives/resources/Frameworks/libtglmt.dylib" || \
		{ echo 'ERROR: libtglmt.dylib missing (set TGLMT_SRC or vendor the dylib)'; exit 1; }
	echo '[Witch v$(VERSION)] dep_tglmt - end'

# MetalBridgeKit: macOS Metal API facade + A9 emulation services (BC decode,
# tessellation, fences, sparse, argument replay) for Metal mods ported from
# macOS. Renderer "metal_macos" dlopens the framework at launch (JavaLauncher).
# Vendored copy ships with the repo; METALBRIDGE_SRC rebuilds it fresh.
METALBRIDGE_SRC ?= /Volumes/project/MetalBridgeA9
dep_metalbridge:
	echo '[Witch v$(VERSION)] dep_metalbridge - start'
	if [ -d "$(METALBRIDGE_SRC)/MetalBridge.xcodeproj" ]; then \
		if ! command -v xcodebuild >/dev/null 2>&1; then \
			echo 'ERROR: xcodebuild not found. Install Xcode command line tools.'; exit 1; \
		fi; \
		echo '[Witch] Installing/updating Metal Toolchain...'; \
		xcodebuild -downloadComponent MetalToolchain || { echo 'ERROR: Failed to install Metal Toolchain (run: sudo xcodebuild -downloadComponent MetalToolchain)'; exit 1; }; \
		(cd "$(METALBRIDGE_SRC)" && xcodegen generate >/dev/null 2>&1 || true); \
		(cd "$(METALBRIDGE_SRC)" && xcodebuild -project MetalBridge.xcodeproj \
			-target MetalBridgeKit -configuration Release -sdk iphoneos \
			-arch arm64 CODE_SIGNING_ALLOWED=NO build) || { echo 'ERROR: MetalBridgeKit build failed'; exit 1; }; \
		rm -rf "$(SOURCEDIR)/Natives/resources/Frameworks/MetalBridgeKit.framework"; \
		cp -pR "$(METALBRIDGE_SRC)/build/Release-iphoneos/MetalBridgeKit.framework" \
			"$(SOURCEDIR)/Natives/resources/Frameworks/MetalBridgeKit.framework"; \
	else \
		echo '[Witch] METALBRIDGE_SRC not found at $(METALBRIDGE_SRC), keeping vendored MetalBridgeKit.framework'; \
	fi
	test -d "$(SOURCEDIR)/Natives/resources/Frameworks/MetalBridgeKit.framework" && \
		test -f "$(SOURCEDIR)/Natives/resources/Frameworks/MetalBridgeKit.framework/MetalBridgeKit" && \
		test -f "$(SOURCEDIR)/Natives/resources/Frameworks/MetalBridgeKit.framework/default.metallib" || \
		{ echo 'ERROR: MetalBridgeKit.framework missing or incomplete (set METALBRIDGE_SRC or vendor the framework)'; exit 1; }
	echo '[Witch v$(VERSION)] dep_metalbridge - end'

dep_tgles:
	echo '[Witch v$(VERSION)] dep_tgles - start'
	mkdir -p "$(WORKINGDIR)"
	if [ -d "$(TGLES_SRC)" ]; then \
		cmake --fresh -S "$(TGLES_SRC)" -B "$(TGLES_SRC)/build-ios-dev" \
			-DCMAKE_SYSTEM_NAME=iOS \
			-DCMAKE_OSX_SYSROOT="$(SDKPATH)" \
			-DCMAKE_OSX_ARCHITECTURES=arm64 \
			-DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
			-DCMAKE_BUILD_TYPE=Release && \
		cmake --build "$(TGLES_SRC)/build-ios-dev" --config Release && \
		cp "$(TGLES_SRC)/build-ios-dev/libtgles.dylib" \
			"$(SOURCEDIR)/Natives/resources/Frameworks/libtgles.dylib" && \
		cp "$(TGLES_SRC)/build-ios-dev/libtgles.dylib" \
			"$(WORKINGDIR)/libtgles.dylib"; \
	else \
		echo '[Witch] TGLES_SRC not found at $(TGLES_SRC), keeping vendored libtgles.dylib'; \
		cp "$(SOURCEDIR)/Natives/resources/Frameworks/libtgles.dylib" \
			"$(WORKINGDIR)/libtgles.dylib"; \
	fi
	test -f "$(SOURCEDIR)/Natives/resources/Frameworks/libtgles.dylib" || \
		{ echo 'ERROR: libtgles.dylib missing (set TGLES_SRC or vendor the dylib)'; exit 1; }
	echo '[Witch v$(VERSION)] dep_tgles - end'

dep_moltenvk12:
	echo '[Witch v$(VERSION)] dep_moltenvk12 - start'
	mkdir -p $(WORKINGDIR)/moltenvk12
	cd "$(SOURCEDIR)/Natives/external/MoltenVK" && \
		git stash 2>/dev/null || true && \
		git checkout v1.2.11 2>/dev/null || git checkout v1.2.10 2>/dev/null || true
	cd $(WORKINGDIR)/moltenvk12 && cmake \
		-DCMAKE_CROSSCOMPILING=true \
		-DCMAKE_SYSTEM_NAME=iOS \
		-DCMAKE_OSX_SYSROOT="$(SDKPATH)" \
		-DCMAKE_OSX_ARCHITECTURES=arm64 \
		-DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
		-DCMAKE_C_FLAGS="-arch arm64" \
		-DCMAKE_CXX_FLAGS="-arch arm64 -stdlib=libc++" \
		-DCMAKE_MAKE_PROGRAM=/usr/bin/make \
		-DMVK_STATIC_LIBRARY_ONLY=ON \
		$(SOURCEDIR)/Natives/external/MoltenVK/
	cmake --build $(WORKINGDIR)/moltenvk12 --config Release -j$(JOBS)
	cd "$(SOURCEDIR)/Natives/external/MoltenVK" && \
		git checkout - 2>/dev/null || true
	echo '[Witch v$(VERSION)] dep_moltenvk12 - end'

dep_moltenvk:
	echo '[Witch v$(VERSION)] dep_moltenvk - start'
	MOLTENVK_SRC="$(SOURCEDIR)/Natives/external/MoltenVK"; \
	MOLTENVK_BUILD="$(WORKINGDIR)/moltenvk14"; \
	mkdir -p "$$MOLTENVK_BUILD"; \
	cp -f "$(SOURCEDIR)/patches/MoltenVK-Common-CMakeLists.txt" "$$MOLTENVK_SRC/Common/CMakeLists.txt" 2>/dev/null || true; \
	cd "$$MOLTENVK_SRC" && cmake \
		-DCMAKE_CROSSCOMPILING=true \
		-DCMAKE_SYSTEM_NAME=iOS \
		-DCMAKE_OSX_SYSROOT="$(SDKPATH)" \
		-DCMAKE_OSX_ARCHITECTURES=arm64 \
		-DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
		-DCMAKE_C_FLAGS="-arch arm64" \
		-DCMAKE_CXX_FLAGS="-arch arm64 -stdlib=libc++" \
		-DCMAKE_BUILD_TYPE=Release \
		-DMVK_STATIC_LIBRARY_ONLY=OFF \
		-DMVK_EXCLUDE_SPIRV_TOOLS=ON \
		-DCPM_cereal_SOURCE="$$MOLTENVK_SRC/External/cereal" \
		-DCPM_SPIRV-Cross_SOURCE="$$MOLTENVK_SRC/External/SPIRV-Cross" \
		-DCPM_Vulkan-Headers_SOURCE="$$MOLTENVK_SRC/External/Vulkan-Headers" \
		-DCMAKE_INSTALL_PREFIX="$(SOURCEDIR)/Natives/resources/Frameworks" \
		-B "$$MOLTENVK_BUILD" \
		. && \
	cmake --build "$$MOLTENVK_BUILD" --config Release -j$(JOBS) && \
	cp -L "$$MOLTENVK_BUILD/MoltenVK/libMoltenVK.dylib" "$(SOURCEDIR)/Natives/resources/Frameworks/"
	echo '[Witch v$(VERSION)] dep_moltenvk - end'

dep_mesa_zink:
	echo '[Witch v$(VERSION)] dep_mesa_zink - start'
	# Build Mesa 25.0.7 (OSMesa+Zink)
	rm -rf "$(SOURCEDIR)/source/mesa-build-25.0.7"; mkdir -p "$(SOURCEDIR)/source/mesa-build-25.0.7"
	cd "$(SOURCEDIR)/source/mesa-25.0.7" && meson setup "$(SOURCEDIR)/source/mesa-build-25.0.7" . \
		--cross-file cross-ios-arm64.txt \
		-Dplatforms= \
		-Dosmesa=true \
		-Degl=disabled \
		-Dglx=disabled \
		-Dglx-direct=false \
		-Dgallium-drivers=zink,softpipe \
		-Dvulkan-drivers= \
		-Dgbm=disabled \
		-Dshader-cache=disabled \
		-Dmoltenvk-dir="$(SOURCEDIR)/Natives/external/MoltenVK/MoltenVK" \
		-Dprefix="$(SOURCEDIR)/Natives/resources/Frameworks" \
		-Dlibdir=lib \
		-Dbindir=bin
	ninja -C "$(SOURCEDIR)/source/mesa-build-25.0.7" -j$(JOBS)
	# Guard: refuse to ship an OSMesa built without zink. If driver_zink is
	# missing from the osmesa target deps, GALLIUM_DRIVER=zink gets a NULL
	# pipe_screen and st_api_create_context segfaults at launch.
	nm -a "$(SOURCEDIR)/source/mesa-build-25.0.7/src/gallium/targets/osmesa/libOSMesa.8.dylib" 2>/dev/null | grep -q '_zink_internal_create_screen' || \
		{ echo 'ERROR: libOSMesa.8.dylib built WITHOUT zink (driver_zink missing in osmesa meson.build)'; exit 1; }
	cp "$(SOURCEDIR)/source/mesa-build-25.0.7/src/gallium/targets/osmesa/libOSMesa.8.dylib" "$(SOURCEDIR)/Natives/resources/Frameworks/"
	# Build Mesa 26.2.2 (EGL)
	rm -rf "$(SOURCEDIR)/source/mesa26-build"; mkdir -p "$(SOURCEDIR)/source/mesa26-build"
	cd "$(SOURCEDIR)/source/mesa-26.2.2" && PATH="/usr/local/opt/bison/bin:$$PATH" meson setup "$(SOURCEDIR)/source/mesa26-build" . \
		--cross-file ../mesa-25.0.7/cross-ios-arm64.txt \
		-Dplatforms= \
		-Degl=enabled \
		-Dglx=disabled \
		-Dglx-direct=false \
		-Dgallium-drivers=zink,softpipe \
		-Dvulkan-drivers= \
		-Dgbm=disabled \
		-Ddisplay-info=disabled \
		-Dzstd=disabled \
		-Dshader-cache=disabled \
		-Dllvm=disabled \
		-Dvalgrind=disabled \
		-Dlibunwind=disabled \
		-Dexpat=disabled \
		-Dvideo-codecs=av1dec \
		-Dmoltenvk-dir="$(SOURCEDIR)/Natives/external/MoltenVK/MoltenVK" \
		-Dprefix="$(SOURCEDIR)/Natives/resources/Frameworks" \
		-Dlibdir=lib \
		-Dbindir=bin
	PATH="/usr/local/opt/bison/bin:$$PATH" ninja -C "$(SOURCEDIR)/source/mesa26-build" -j$(JOBS)
	cp "$(SOURCEDIR)/source/mesa26-build/src/egl/libEGL.1.dylib" "$(SOURCEDIR)/Natives/resources/Frameworks/libEGL_Mesa26.dylib"
	cp "$(SOURCEDIR)/source/mesa26-build/src/gallium/targets/dri/libgallium-26.2.2.dylib" "$(SOURCEDIR)/Natives/resources/Frameworks/"
	echo '[Witch v$(VERSION)] dep_mesa_zink - end'

dep_kkosmic:
	echo '[Witch v$(VERSION)] dep_kkosmic - start'
	# Build KosmicKrisp Vulkan driver for iOS (A13+)
	# Requires Mesa mainline source at source/mesa-kosmickrisp/
	KK_SRC="$(SOURCEDIR)/source/mesa-kosmickrisp"
	KK_BUILD="$(SOURCEDIR)/source/mesa-kk-build"
	KK_CROSS="$$KK_SRC/cross-ios-arm64-kkosmic.txt"
	PREFIX="$(SOURCEDIR)/Natives/resources/Frameworks"
	if [ ! -d "$$KK_SRC/src/kosmickrisp" ]; then \
		echo "ERROR: Mesa source not found. Run: git clone https://gitlab.freedesktop.org/mesa/mesa.git $$KK_SRC"; \
		exit 1; \
	fi
	rm -rf "$$KK_BUILD"; mkdir -p "$$KK_BUILD"
	cd "$$KK_SRC" && meson setup "$$KK_BUILD" . \
		--cross-file "$$KK_CROSS" \
		-Dplatforms= \
		-Dvulkan-drivers=kosmickrisp \
		-Dgallium-drivers= \
		-Dopengl=false \
		-Dgles1=disabled \
		-Dgles2=disabled \
		-Dglx=disabled \
		-Dglx-direct=false \
		-Dgbm=disabled \
		-Dllvm=disabled \
		-Dvalgrind=disabled \
		-Dlibunwind=disabled \
		-Dzstd=disabled \
		-Dshader-cache=disabled \
		-Dexpat=disabled \
		-Dbuildtype=release \
		-Dprefix="$$PREFIX" \
		-Dlibdir=lib \
		-Dbindir=bin
	ninja -C "$$KK_BUILD" -j$(JOBS)
	# Copy KosmicKrisp driver (try multiple possible output paths)
	cp "$$KK_BUILD/src/vulkan/libvulkan_kosmickrisp.dylib" "$$PREFIX/" 2>/dev/null || \
	cp "$$KK_BUILD/src/vulkan/libvulkan_kosmickrisp.so" "$$PREFIX/" 2>/dev/null || \
	echo "WARNING: KosmicKrisp driver not found in build output"
	echo '[Witch v$(VERSION)] dep_kkosmic - end'

dep_angle:
	echo '[Witch v$(VERSION)] dep_angle - start'
	ANGLE_SRC="$(SOURCEDIR)/source/angle-build/angle"; \
	cd "$$ANGLE_SRC" && \
	mkdir -p out/ios-vulkan-arm64 out/ios-metal-arm64 && \
	"$$(pwd)/buildtools/mac/gn" gen out/ios-vulkan-arm64 --args='target_os="ios" target_cpu="arm64" target_environment="device" ios_deployment_target="16.0" is_debug=false is_official_build=true chrome_pgo_phase=0 ios_enable_code_signing=false is_component_build=false symbol_level=0 angle_standalone=true angle_build_tests=false angle_enable_vulkan=true angle_shared_libvulkan=true angle_use_custom_libvulkan=true angle_enable_metal=false angle_enable_gl=false angle_enable_null=false angle_enable_wgpu=false angle_enable_swiftshader=false angle_enable_essl=false angle_enable_glsl=true angle_egl_dispatch_library="libGLESv2_angle_vulkan" treat_warnings_as_errors=false use_custom_libcxx=true clang_base_path="//third_party/llvm-build/Release+Asserts" enable_rust=false use_system_xcode=true enable_rust_cxx=false angle_enable_perfetto=false' && \
	"$$(pwd)/third_party/ninja/ninja" -C out/ios-vulkan-arm64 -j4 libEGL libGLESv2 && \
	"$$(pwd)/buildtools/mac/gn" gen out/ios-metal-arm64 --args='target_os="ios" target_cpu="arm64" target_environment="device" ios_deployment_target="16.0" is_debug=false is_official_build=true chrome_pgo_phase=0 ios_enable_code_signing=false is_component_build=false symbol_level=0 angle_standalone=true angle_build_tests=false angle_enable_vulkan=false angle_enable_metal=true angle_enable_gl=false angle_enable_null=false angle_enable_wgpu=false angle_enable_swiftshader=false angle_enable_essl=false angle_enable_glsl=true treat_warnings_as_errors=false use_custom_libcxx=true clang_base_path="//third_party/llvm-build/Release+Asserts" enable_rust=false use_system_xcode=true metal_preferred_client="native" angle_egl_dispatch_library="libGLESv2_angle_metal.dylib" enable_rust_cxx=false angle_enable_perfetto=false' && \
	"$$(pwd)/third_party/ninja/ninja" -C out/ios-metal-arm64 -j4 libEGL libGLESv2 && \
	cp out/ios-vulkan-arm64/libEGL.framework/libEGL "$(SOURCEDIR)/Natives/resources/Frameworks/libEGL_angle_vulkan" && \
	cp out/ios-vulkan-arm64/libGLESv2.framework/libGLESv2 "$(SOURCEDIR)/Natives/resources/Frameworks/libGLESv2_angle_vulkan" && \
	cp out/ios-vulkan-arm64/libvulkan.dylib "$(SOURCEDIR)/Natives/resources/Frameworks/" && \
	cp out/ios-metal-arm64/libEGL.framework/libEGL "$(SOURCEDIR)/Natives/resources/Frameworks/libEGL_angle_metal" && \
	cp out/ios-metal-arm64/libGLESv2.framework/libGLESv2 "$(SOURCEDIR)/Natives/resources/Frameworks/libGLESv2_angle_metal" && \
	cp out/ios-metal-arm64/libGLESv2.framework/libGLESv2 "$(SOURCEDIR)/Natives/resources/Frameworks/libGLESv2_angle_metal.dylib" && \
	install_name_tool -id @rpath/libEGL_angle_vulkan.dylib "$(SOURCEDIR)/Natives/resources/Frameworks/libEGL_angle_vulkan" && \
	install_name_tool -id @rpath/libGLESv2_angle_vulkan.dylib "$(SOURCEDIR)/Natives/resources/Frameworks/libGLESv2_angle_vulkan" && \
	install_name_tool -id @rpath/libEGL_angle_metal.dylib "$(SOURCEDIR)/Natives/resources/Frameworks/libEGL_angle_metal" && \
	install_name_tool -id @rpath/libGLESv2_angle_metal.dylib "$(SOURCEDIR)/Natives/resources/Frameworks/libGLESv2_angle_metal" && \
	install_name_tool -id @rpath/libGLESv2_angle_metal.dylib "$(SOURCEDIR)/Natives/resources/Frameworks/libGLESv2_angle_metal.dylib"
	echo '[Witch v$(VERSION)] dep_angle - end'

assets: logos
	echo '[Witch v$(VERSION)] assets - start'
	@XCODE_DEV=$(shell xcode-select -p 2>/dev/null); \
	if [ -n "$$XCODE_DEV" ] && [ -d "$$XCODE_DEV/Platforms/iPhoneOS.platform" ]; then \
		mkdir -p $(WORKINGDIR)/Witch.app/Base.lproj; \
		"$$XCODE_DEV/usr/bin/actool" $(SOURCEDIR)/Natives/Assets.xcassets \
			--compile $(SOURCEDIR)/Natives/resources \
			--platform iphoneos \
			--minimum-deployment-target 14.0 \
			--target-device iphone --target-device ipad \
			--output-partial-info-plist /dev/null || true; \
	else \
		echo 'Skipping actool - not available'; \
	fi
	echo '[Witch v$(VERSION)] assets - end'

# Generate the legacy CFBundleIconFiles PNGs (AppIcon-Witch60x60@2x.png, ...)
# from the master logos in Natives/logo/. The file names change when the
# artwork changes so SpringBoard drops its stale icon cache after updates
# (TrollStore installs reuse the same bundle id + icon paths otherwise).
# APP_ICON=AppIcon-Development is set for development builds (GitHub
# development workflow); it substitutes the dev logo in place of the official
# blue one so non-release builds carry the dev branding.
logos:
	echo '[Witch v$(VERSION)] logos - start'
	@if [ '$(APP_ICON)' = 'AppIcon-Development' ]; then \
		PRIMARY="$(SOURCEDIR)/Natives/logo/logo-dev.png"; \
	else \
		PRIMARY="$(SOURCEDIR)/Natives/logo/logo-main-light.png"; \
	fi; \
	sips -z 120 120 "$$PRIMARY" --out $(SOURCEDIR)/Natives/resources/AppIcon-Witch60x60@2x.png >/dev/null; \
	sips -z 152 152 "$$PRIMARY" --out $(SOURCEDIR)/Natives/resources/AppIcon-Witch76x76@2x~ipad.png >/dev/null; \
	echo "[Witch v$(VERSION)] logos - done (primary=$$PRIMARY)"
	echo '[Witch v$(VERSION)] logos - end'

lwgjl:
	echo '[Witch v$(VERSION)] lwgjl - start'
	@set -e; \
	LWJGL33_DIR="$(SOURCEDIR)/lwgjl/lwjgl3-wip-rebase_3.3.3"; \
	if [ ! -f "$$LWJGL33_DIR/bin/out/liblwjgl.dylib" ]; then \
		echo "Building LWGJL 3.3.3..."; \
		cd "$$LWJGL33_DIR" && export JAVA_HOME="$(JAVA_HOME)" && cd libffi && find build_iphoneos-arm64 -name Makefile -exec touch {} + && touch build_iphoneos-arm64/config.status && make -C build_iphoneos-arm64 && cd .. && mkdir -p bin/libs/native/macos/arm64/org/lwjgl bin/libs/native/macos/x64/org/lwjgl && cp libffi/build_iphoneos-arm64/.libs/libffi.a bin/libs/native/macos/arm64/org/lwjgl/libffi.a && cp bin/libs/native/macos/arm64/org/lwjgl/libffi.a bin/libs/native/macos/x64/org/lwjgl/libffi.a 2>/dev/null && ant -Dplatform.macos=true -Dbuild.arch=arm64 -Dbinding.assimp=false -Dbinding.bgfx=false -Dbinding.cuda=false -Dbinding.egl=false -Dbinding.fmod=false -Dbinding.harfbuzz=false -Dbinding.hwloc=false -Dbinding.jawt=false -Dbinding.jemalloc=false -Dbinding.ktx=false -Dbinding.libdivide=false -Dbinding.llvm=false -Dbinding.lmdb=false -Dbinding.lz4=false -Dbinding.meow=false -Dbinding.meshoptimizer=false -Dbinding.nfd=false -Dbinding.nuklear=false -Dbinding.odbc=false -Dbinding.opengles=false -Dbinding.opencl=false -Dbinding.openvr=false -Dbinding.openxr=false -Dbinding.opus=false -Dbinding.par=false -Dbinding.remotery=false -Dbinding.renderdoc=false -Dbinding.rpmalloc=false -Dbinding.vulkan=true -Dbinding.vma=true -Dbinding.spvc=true -Dbinding.shaderc=true -Dbinding.sse=false -Dbinding.spng=false -Dbinding.tinyexr=false -Dbinding.tinyfd=true -Dbinding.tootle=false -Dbinding.xxhash=false -Dbinding.yoga=false -Dbinding.zstd=false -Dbinding.sdl=false -Dbuild.type=release/3.3.3 -Djavadoc.skip=true -Dnashorn.args="--no-deprecation-warning" compile-templates compile compile-native release && mkdir -p bin/out && find bin/libs/native/macos/arm64/org/lwjgl -name '*.dylib' -exec cp {} bin/out/ \; || exit 1; \
	fi; \
	echo "Copying 3.3.3 JARs to libs/lwjgl..."; \
	find "$$LWJGL33_DIR/bin/RELEASE" -name '*.jar' ! -name '*-natives-*' ! -name '*-sources.jar' -exec cp {} "$(SOURCEDIR)/JavaApp/libs/lwjgl/" \; 2>/dev/null || true; \
	LWJGL36_DIR="$(SOURCEDIR)/lwgjl/lwjgl3-wip-rebase_3.3.6"; \
	mkdir -p "$(SOURCEDIR)/JavaApp/libs/lwjgl36"; \
	if [ ! -f "$$LWJGL36_DIR/bin/out/liblwjgl.dylib" ]; then \
		echo "Building LWGJL 3.3.6..."; \
		cd "$$LWJGL36_DIR" && export JAVA_HOME="$(JAVA_HOME)" && cd libffi && find build_iphoneos-arm64 -name Makefile -exec touch {} + && touch build_iphoneos-arm64/config.status && make -C build_iphoneos-arm64 && cd .. && mkdir -p bin/libs/native/macos/arm64/org/lwjgl bin/libs/native/macos/x64/org/lwjgl && cp libffi/build_iphoneos-arm64/.libs/libffi.a bin/libs/native/macos/arm64/org/lwjgl/libffi.a && cp bin/libs/native/macos/arm64/org/lwjgl/libffi.a bin/libs/native/macos/x64/org/lwjgl/libffi.a 2>/dev/null && ant -Dplatform.macos=true -Dbuild.arch=arm64 -Dbinding.assimp=false -Dbinding.bgfx=false -Dbinding.cuda=false -Dbinding.egl=false -Dbinding.fmod=false -Dbinding.harfbuzz=false -Dbinding.hwloc=false -Dbinding.jawt=false -Dbinding.jemalloc=false -Dbinding.ktx=false -Dbinding.libdivide=false -Dbinding.llvm=false -Dbinding.lmdb=false -Dbinding.lz4=false -Dbinding.meow=false -Dbinding.meshoptimizer=false -Dbinding.nfd=false -Dbinding.nuklear=false -Dbinding.odbc=false -Dbinding.opengles=false -Dbinding.opencl=false -Dbinding.openvr=false -Dbinding.openxr=false -Dbinding.opus=false -Dbinding.par=false -Dbinding.remotery=false -Dbinding.renderdoc=false -Dbinding.rpmalloc=false -Dbinding.vulkan=true -Dbinding.vma=true -Dbinding.spvc=true -Dbinding.shaderc=true -Dbinding.sse=false -Dbinding.spng=false -Dbinding.tinyexr=false -Dbinding.tinyfd=true -Dbinding.tootle=false -Dbinding.xxhash=false -Dbinding.yoga=false -Dbinding.zstd=false -Dbinding.sdl=false -Dbuild.type=release/3.3.6 -Djavadoc.skip=true -Dnashorn.args="--no-deprecation-warning" compile-templates compile compile-native release && mkdir -p bin/out && find bin/libs/native/macos/arm64/org/lwjgl -name '*.dylib' -exec cp {} bin/out/ \; || exit 1; \
	fi; \
	echo "Copying 3.3.6 JARs to libs/lwjgl36..."; \
	find "$$LWJGL36_DIR/bin/RELEASE" -name '*.jar' ! -name '*-natives-*' ! -name '*-sources.jar' -exec cp {} "$(SOURCEDIR)/JavaApp/libs/lwjgl36/" \; 2>/dev/null || true; \
	LWJGL41_DIR="$(SOURCEDIR)/lwgjl/lwjgl3-wip-rebase_3.4.1"; \
	: "LWJGL 3.4.1 Shaderc needs shaderc_compile_options_set_max_id_bound"; \
	if [ ! -f "$$LWJGL41_DIR/bin/out/liblwjgl.dylib" ] || \
	   ! nm -gU "$$LWJGL41_DIR/bin/out/libshaderc.dylib" 2>/dev/null | grep -q '_shaderc_compile_options_set_max_id_bound$$'; then \
		echo "Building LWGJL 3.4.1..."; \
		cd "$$LWJGL41_DIR" && export JAVA_HOME="$(JAVA_HOME)" && cd libffi && find build_iphoneos-arm64 -name Makefile -exec touch {} + && touch build_iphoneos-arm64/config.status && make -C build_iphoneos-arm64 && cd .. && mkdir -p bin/libs/native/macos/arm64/org/lwjgl bin/libs/native/macos/x64/org/lwjgl && cp libffi/build_iphoneos-arm64/.libs/libffi.a bin/libs/native/macos/arm64/org/lwjgl/libffi.a && cp bin/libs/native/macos/arm64/org/lwjgl/libffi.a bin/libs/native/macos/x64/org/lwjgl/libffi.a 2>/dev/null && ant -Dplatform.macos=true -Dbuild.arch=arm64 -Dbinding.assimp=false -Dbinding.bgfx=false -Dbinding.cuda=false -Dbinding.egl=false -Dbinding.fmod=false -Dbinding.harfbuzz=false -Dbinding.hwloc=false -Dbinding.jawt=false -Dbinding.jemalloc=false -Dbinding.ktx=false -Dbinding.libdivide=false -Dbinding.llvm=false -Dbinding.lmdb=false -Dbinding.lz4=false -Dbinding.meow=false -Dbinding.meshoptimizer=false -Dbinding.nfd=false -Dbinding.nuklear=false -Dbinding.odbc=false -Dbinding.opengles=false -Dbinding.opencl=false -Dbinding.openvr=false -Dbinding.openxr=false -Dbinding.opus=false -Dbinding.par=false -Dbinding.remotery=false -Dbinding.renderdoc=false -Dbinding.rpmalloc=false -Dbinding.vulkan=true -Dbinding.vma=true -Dbinding.spvc=true -Dbinding.shaderc=true -Dbinding.sse=false -Dbinding.spng=false -Dbinding.tinyexr=false -Dbinding.tinyfd=true -Dbinding.tootle=false -Dbinding.xxhash=false -Dbinding.yoga=false -Dbinding.zstd=false -Dbinding.sdl=false -Dbuild.type=release/3.4.1 -Djavadoc.skip=true -Dnashorn.args="--no-deprecation-warning" compile-templates compile compile-native release && mkdir -p bin/out && find bin/libs/native/macos/arm64/org/lwjgl -name '*.dylib' -exec cp {} bin/out/ \; && unzip -o libshaderc-ios.zip libshaderc_shared.dylib -d /tmp/shaderc-fix && cp /tmp/shaderc-fix/libshaderc_shared.dylib bin/out/libshaderc.dylib && rm -rf /tmp/shaderc-fix || exit 1; \
	fi; \
	if [ -f "$$LWJGL41_DIR/libshaderc-ios.zip" ] && \
	   ! nm -gU "$$LWJGL41_DIR/bin/out/libshaderc.dylib" 2>/dev/null | grep -q '_shaderc_compile_options_set_max_id_bound$$'; then \
		echo "Replacing broken shaderc with working one from libshaderc-ios.zip..."; \
		cd "$$LWJGL41_DIR" && unzip -o libshaderc-ios.zip libshaderc_shared.dylib -d /tmp/shaderc-fix && cp /tmp/shaderc-fix/libshaderc_shared.dylib bin/out/libshaderc.dylib && rm -rf /tmp/shaderc-fix; \
	fi; \
	echo "Copying 3.4.1 JARs to libs/lwjgl41..."; \
	find "$$LWJGL41_DIR/bin/RELEASE" -name '*.jar' ! -name '*-natives-*' ! -name '*-sources.jar' -exec cp {} "$(SOURCEDIR)/JavaApp/libs/lwjgl41/" \; 2>/dev/null || true; \
	echo '[Witch v$(VERSION)] lwgjl - end'

jit-helper: native
	echo '[Witch v$(VERSION)] jit-helper - start'
	@if [ '$(PLATFORM)' != '2' ]; then \
		echo 'Skipping Built-in StikJIT helper (iOS-only build)'; exit 0; \
	fi
	@if [ ! -d '$(STIKJIT_XCFRAMEWORK)/ios-arm64/StikJIT.framework' ]; then \
		echo 'ERROR: StikJIT.xcframework is missing. See third_party/stikjit/README.md'; exit 1; \
	fi
	@command -v xcodegen >/dev/null 2>&1 || { echo 'ERROR: xcodegen is required for the JIT helper (brew install xcodegen)'; exit 1; }
	cd $(WITCH_JIT_HELPER_DIR) && xcodegen generate --quiet
	cd $(WITCH_JIT_HELPER_DIR) && xcodebuild -project WitchJITHelper.xcodeproj -target WitchJITHelper \
		-sdk iphoneos -configuration Release \
		SYMROOT=$(WITCH_JIT_HELPER_BUILD)/sym OBJROOT=$(WITCH_JIT_HELPER_BUILD)/obj \
		CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
		ONLY_ACTIVE_ARCH=NO ARCHS=arm64 build
	mkdir -p $(WORKINGDIR)/Witch.app/PlugIns $(WORKINGDIR)/Witch.app/Frameworks
	rm -rf $(WORKINGDIR)/Witch.app/PlugIns/WitchJITHelper.appex
	cp -R $(WITCH_JIT_HELPER_BUILD)/sym/Release-iphoneos/WitchJITHelper.appex $(WORKINGDIR)/Witch.app/PlugIns/
	rm -rf $(WORKINGDIR)/Witch.app/Frameworks/StikJIT.framework
	cp -R $(STIKJIT_XCFRAMEWORK)/ios-arm64/StikJIT.framework $(WORKINGDIR)/Witch.app/Frameworks/
	echo '[Witch v$(VERSION)] jit-helper - end'

payload: native dep_mg spvc dep_mobilegl dep_tgles dep_tglmt dep_metalbridge lwgjl java jre assets jit-helper
	echo '[Witch v$(VERSION)] payload - start'
	rm -f $(WORKINGDIR)/Witch.app/*.png
	$(call METHOD_DIRCHECK,$(WORKINGDIR)/Witch.app/libs)
	$(call METHOD_DIRCHECK,$(WORKINGDIR)/Witch.app/libs_caciocavallo)
	$(call METHOD_DIRCHECK,$(WORKINGDIR)/Witch.app/libs_caciocavallo17)
	cp -R $(SOURCEDIR)/Natives/resources/en.lproj/LaunchScreen.storyboardc $(WORKINGDIR)/Witch.app/Base.lproj/ || exit 1
	cp -R $(SOURCEDIR)/Natives/resources/* $(WORKINGDIR)/Witch.app/ || exit 1
	if [ '$(PLATFORM)' = '2' ]; then \
		mkdir -p $(WORKINGDIR)/Witch.app/PlugIns $(WORKINGDIR)/Witch.app/Frameworks; \
		if [ ! -d '$(WORKINGDIR)/Witch.app/PlugIns/WitchJITHelper.appex' ]; then \
			echo 'ERROR: WitchJITHelper.appex was not staged'; exit 1; \
		fi; \
		if [ ! -d '$(WORKINGDIR)/Witch.app/Frameworks/StikJIT.framework' ]; then \
			echo 'ERROR: StikJIT.framework was not staged'; exit 1; \
		fi; \
	fi
	cp $(WORKINGDIR)/*.dylib $(WORKINGDIR)/Witch.app/Frameworks/ || exit 1
	cp -R $(SOURCEDIR)/JavaApp/libs/others/* $(WORKINGDIR)/Witch.app/libs/ || exit 1
	cp $(SOURCEDIR)/JavaApp/build/launcher.jar $(SOURCEDIR)/JavaApp/build/patchjna_agent.jar $(SOURCEDIR)/JavaApp/build/cacio-init-agent.jar $(SOURCEDIR)/JavaApp/build/f3agent.jar $(SOURCEDIR)/JavaApp/build/fsr3-agent.jar $(WORKINGDIR)/Witch.app/libs/ || exit 1
	mkdir -p $(WORKINGDIR)/Witch.app/libs/lwjgl33 $(WORKINGDIR)/Witch.app/libs/lwjgl36 $(WORKINGDIR)/Witch.app/libs/lwjgl41
	cp $(SOURCEDIR)/JavaApp/build/lwjgl-3.3.3.jar $(WORKINGDIR)/Witch.app/libs/lwjgl33/lwjgl.jar || exit 1
	cp $(SOURCEDIR)/JavaApp/build/lwjgl-3.3.6.jar $(WORKINGDIR)/Witch.app/libs/lwjgl36/lwjgl.jar || exit 1
	cp $(SOURCEDIR)/JavaApp/build/lwjgl-3.4.1.jar $(WORKINGDIR)/Witch.app/libs/lwjgl41/lwjgl.jar || exit 1
	mkdir -p $(WORKINGDIR)/Witch.app/libs/lwjgl33_natives $(WORKINGDIR)/Witch.app/libs/lwjgl36_natives $(WORKINGDIR)/Witch.app/libs/lwjgl41_natives
	cp $(SOURCEDIR)/lwgjl/lwjgl3-wip-rebase_3.3.3/bin/out/*.dylib $(WORKINGDIR)/Witch.app/libs/lwjgl33_natives/ || exit 1
	cp $(SOURCEDIR)/lwgjl/lwjgl3-wip-rebase_3.3.6/bin/out/*.dylib $(WORKINGDIR)/Witch.app/libs/lwjgl36_natives/ || exit 1
	cp $(SOURCEDIR)/lwgjl/lwjgl3-wip-rebase_3.4.1/bin/out/*.dylib $(WORKINGDIR)/Witch.app/libs/lwjgl41_natives/ || exit 1
	# LWJGL's own libspirv-cross.dylib was compiled with the macOS arm64
	# (Apple Silicon) CPU baseline, which emits ARMv8.3 RCpc atomics in
	# thread-safe static guards -> SIGILL on A11/A10. Replace it everywhere
	# with the ARMv8.0 iOS build produced by `make spvc` so no code path can
	# pick the incompatible copy.
	for dir in lwjgl33_natives lwjgl36_natives lwjgl41_natives; do \
		cp $(SOURCEDIR)/Natives/resources/Frameworks/libspirv-cross-c-shared.0.dylib \
			$(WORKINGDIR)/Witch.app/libs/$$dir/libspirv-cross.dylib; \
	done
	# The LWJGL macOS build emits a macOS-platform libMoltenVK.dylib (links
	# AppKit, platform macOS) that can never dlopen on iOS. If it stays in the
	# natives dirs, LWJGL resolves a bare "libMoltenVK.dylib" opengl.libname via
	# org.lwjgl.librarypath and dies with UnsatisfiedLinkError (error=null) in
	# GL.create() on MC 26.x. The signed iOS copy lives in Frameworks and is
	# referenced by absolute path (vulkan.libname) / dlopen redirect, so drop
	# the macOS copies here.
	rm -f $(WORKINGDIR)/Witch.app/libs/lwjgl33_natives/libMoltenVK*.dylib \
		$(WORKINGDIR)/Witch.app/libs/lwjgl36_natives/libMoltenVK*.dylib \
		$(WORKINGDIR)/Witch.app/libs/lwjgl41_natives/libMoltenVK*.dylib
	@nm -gU $(WORKINGDIR)/Witch.app/libs/lwjgl41_natives/libshaderc.dylib | \
		grep -q '_shaderc_compile_options_set_max_id_bound$$' || \
		{ echo 'ERROR: LWJGL 3.4.1 Shaderc is too old for VulkanMod'; exit 1; }
	# Keep the legacy iOS Shaderc binary for LWJGL 3.3.x. VulkanMod 0.6.8 uses
	# LWJGL 3.4.1 and requires shaderc_compile_options_set_max_id_bound, which
	# this legacy binary does not export. The 3.4.1 directory therefore retains
	# the matching Shaderc produced by the local LWJGL build above.
	cp $(SOURCEDIR)/Natives/resources/Frameworks/libshaderc.dylib \
	   $(WORKINGDIR)/Witch.app/libs/lwjgl33_natives/libshaderc.dylib || exit 1
	cp $(SOURCEDIR)/Natives/resources/Frameworks/libshaderc.dylib \
	   $(WORKINGDIR)/Witch.app/libs/lwjgl36_natives/libshaderc.dylib || exit 1
	# LWJGL's libopenal.dylib links ApplicationServices.framework (macOS-only).
	# Replace with iOS-compatible openal-soft build so LWJGL finds it at the
	# expected path but loads a dylib that works on iOS.
	cp $(SOURCEDIR)/Natives/resources/Frameworks/libopenal.dylib \
	   $(WORKINGDIR)/Witch.app/libs/lwjgl33_natives/libopenal.dylib
	cp $(SOURCEDIR)/Natives/resources/Frameworks/libopenal.dylib \
	   $(WORKINGDIR)/Witch.app/libs/lwjgl36_natives/libopenal.dylib
	cp $(SOURCEDIR)/Natives/resources/Frameworks/libopenal.dylib \
	   $(WORKINGDIR)/Witch.app/libs/lwjgl41_natives/libopenal.dylib
	# LWJGL's libfreetype.dylib links CoreGraphics.framework (macOS-only).
	# Replace with the JDK's freetype build which is statically compiled
	# against iOS and doesn't need macOS frameworks.
	cp $(SOURCEDIR)/depends/java-25-openjdk/lib/libfreetype.dylib \
	   $(WORKINGDIR)/Witch.app/libs/lwjgl33_natives/libfreetype.dylib
	cp $(SOURCEDIR)/depends/java-25-openjdk/lib/libfreetype.dylib \
	   $(WORKINGDIR)/Witch.app/libs/lwjgl36_natives/libfreetype.dylib
	cp $(SOURCEDIR)/depends/java-25-openjdk/lib/libfreetype.dylib \
	   $(WORKINGDIR)/Witch.app/libs/lwjgl41_natives/libfreetype.dylib
	# LWJGL 3.4.x SDL binding (org.lwjgl.sdl.SDL) loads "SDL3"; provide the
	# prebuilt iOS arm64 libSDL3 from amethyst-prebuilt-libraries in every
	# natives dir so the game's SDL bootstrap always finds it.
	cp -L $(SOURCEDIR)/amethyst-prebuilt-libraries/SDL/SDL3/build_ios/libSDL3.dylib \
	   $(WORKINGDIR)/Witch.app/libs/lwjgl33_natives/libSDL3.dylib
	cp $(SOURCEDIR)/amethyst-prebuilt-libraries/SDL/SDL3/build_ios/libSDL3.0.dylib \
	   $(WORKINGDIR)/Witch.app/libs/lwjgl33_natives/libSDL3.0.dylib
	cp -L $(SOURCEDIR)/amethyst-prebuilt-libraries/SDL/SDL3/build_ios/libSDL3.dylib \
	   $(WORKINGDIR)/Witch.app/libs/lwjgl36_natives/libSDL3.dylib
	cp $(SOURCEDIR)/amethyst-prebuilt-libraries/SDL/SDL3/build_ios/libSDL3.0.dylib \
	   $(WORKINGDIR)/Witch.app/libs/lwjgl36_natives/libSDL3.0.dylib
	cp -L $(SOURCEDIR)/amethyst-prebuilt-libraries/SDL/SDL3/build_ios/libSDL3.dylib \
	   $(WORKINGDIR)/Witch.app/libs/lwjgl41_natives/libSDL3.dylib
	cp $(SOURCEDIR)/amethyst-prebuilt-libraries/SDL/SDL3/build_ios/libSDL3.0.dylib \
	   $(WORKINGDIR)/Witch.app/libs/lwjgl41_natives/libSDL3.0.dylib
	cp -R $(SOURCEDIR)/JavaApp/libs/caciocavallo/* $(WORKINGDIR)/Witch.app/libs_caciocavallo || exit 1
	cp -R $(SOURCEDIR)/JavaApp/libs/caciocavallo17/* $(WORKINGDIR)/Witch.app/libs_caciocavallo17 || exit 1
	$(call METHOD_DIRCHECK,$(OUTPUTDIR)/Payload)
	cp -R $(WORKINGDIR)/Witch.app $(OUTPUTDIR)/Payload
	if [ '$(SLIMMED_ONLY)' != '1' ]; then \
		cp -R $(OUTPUTDIR)/java_runtimes $(OUTPUTDIR)/Payload/Witch.app; \
	fi
	python3 $(SOURCEDIR)/scripts/inject_oauth_schemes.py "$(OUTPUTDIR)/Payload/Witch.app/Info.plist" "$(WITCH_GOOGLE_DRIVE_CLIENT_ID)" "$(WITCH_DROPBOX_APP_KEY)" || exit 1
	# Always run the platform retag FIRST before signing so CodeResources hashes stay intact.
	$(call METHOD_MACHO_JRE,$(OUTPUTDIR)/Payload/Witch.app,$(call METHOD_CHANGE_PLAT,$(PLATFORM),$$file)); \
	$(call METHOD_MACHO_JRE,$(OUTPUTDIR)/java_runtimes,$(call METHOD_CHANGE_PLAT,$(PLATFORM),$$file));
	chmod -R 755 $(OUTPUTDIR)/Payload
	# Sideload (SideStore/AltStore/ESign/Feather): entitlements.sideload.xml is
	# intentionally MINIMAL (no com.apple.private.*, no disable-library-validation,
	# no background-gpu, no jb.pmap_cs.*). Private keys live only in
	# entitlements.trollstore.xml — adding them here breaks free-Apple-ID signing
	# with 0xe8008016. Use TROLLSTORE_JIT_ENT=1 only for TrollStore.
	# Optional override: SIDESTORE_ENT=/path/to/entitlements.xml
	# ORDER MATTERS: ad-hoc-sign the whole bundle FIRST, then overlay the
	# entitlements on the main binary. ldid -S <dir> (no plist) re-signs every
	# Mach-O inside ad-hoc with no entitlement blob, so running it last used to
	# silently WIPE the keys above — the installed app then reported
	# "memorystatus=0 increased-memory-limit=0" and died at the 2 GiB Jetsam cap.
	# Drop any bundle seal copied from the build tree or left by an
	# interrupted run: ldid -S recursively walks the bundle and fails while
	# re-signing when a stale _CodeSignature/CodeResources is present.
	rm -rf $(OUTPUTDIR)/Payload/Witch.app/_CodeSignature;
	# Nested code first: framework and app extension are iOS 17.4+ binaries and
	# must stay signed even though the app's 14.0 retag skipped them.
	if [ -d $(OUTPUTDIR)/Payload/Witch.app/Frameworks/StikJIT.framework ]; then \
		ldid -S $(OUTPUTDIR)/Payload/Witch.app/Frameworks/StikJIT.framework || exit 1; \
	fi
	if [ -d $(OUTPUTDIR)/Payload/Witch.app/PlugIns/WitchJITHelper.appex ]; then \
		ldid -S $(OUTPUTDIR)/Payload/Witch.app/PlugIns/WitchJITHelper.appex || exit 1; \
	fi
	ldid -S $(OUTPUTDIR)/Payload/Witch.app;
	if [ '$(TROLLSTORE_JIT_ENT)' == '1' ]; then \
		ldid -S$(SOURCEDIR)/entitlements.trollstore.xml $(OUTPUTDIR)/Payload/Witch.app/Witch; \
	elif [ '$(PLATFORM)' == '6' ]; then \
		ldid -S$(SOURCEDIR)/entitlements.codesign.xml $(OUTPUTDIR)/Payload/Witch.app/Witch; \
	elif [ -n '$(SIDESTORE_ENT)' ] && [ -f '$(SIDESTORE_ENT)' ]; then \
		ldid -S$(SIDESTORE_ENT) $(OUTPUTDIR)/Payload/Witch.app/Witch; \
	else \
		ldid -S$(SOURCEDIR)/entitlements.sideload.xml $(OUTPUTDIR)/Payload/Witch.app/Witch; \
	fi
	echo '[Witch v$(VERSION)] payload - end'

deploy:
	echo '[Witch v$(VERSION)] deploy - start'
	cd $(OUTPUTDIR); \
	if [ '$(IOS)' = '1' ]; then \
		ldid -S $(WORKINGDIR)/Witch.app || exit 1; \
		ldid -S$(SOURCEDIR)/entitlements.trollstore.xml $(WORKINGDIR)/Witch.app/Witch || exit 1; \
		sudo mv $(WORKINGDIR)/*.dylib $(PREFIX)Applications/Witch.app/Frameworks/ || exit 1; \
		if [ -d $(WORKINGDIR)/Witch.app/PlugIns/WitchJITHelper.appex ]; then \
			sudo mkdir -p $(PREFIX)Applications/Witch.app/PlugIns; \
			sudo rm -rf $(PREFIX)Applications/Witch.app/PlugIns/WitchJITHelper.appex; \
			sudo cp -R $(WORKINGDIR)/Witch.app/PlugIns/WitchJITHelper.appex $(PREFIX)Applications/Witch.app/PlugIns/ || exit 1; \
			sudo cp -R $(WORKINGDIR)/Witch.app/Frameworks/StikJIT.framework $(PREFIX)Applications/Witch.app/Frameworks/ || exit 1; \
		fi; \
		sudo mv $(WORKINGDIR)/Witch.app/Witch $(PREFIX)Applications/Witch.app/Witch || exit 1; \
		sudo mv $(SOURCEDIR)/JavaApp/build/*.jar $(PREFIX)Applications/Witch.app/libs/ || exit 1; \
		cd $(PREFIX)Applications/Witch.app/Frameworks || exit 1; \
		sudo chown -R 501:501 $(PREFIX)Applications/Witch.app/* || exit 1; \
	elif [ '$(IOS)' = '0' ] && [ '$(DETECTPLAT)' = 'Darwin' ]; then \
		if [ '$(PLATFORM)' != '2' ] || [ '$(TEAMID)' = '-1' ] || [ '$(SIGNING_TEAMID)' = '-1' ] || [ '$(PROVISIONING)' = '-1' ]; then \
			echo 'Configuration not supported for deploy recipe.'; \
		else \
			$(call METHOD_PACKAGE); \
			if [ '$(SLIMMED_ONLY)' = '0' ]; then \
				open $(OUTPUTDIR)/net.kdt.pojavlauncher-$(VERSION)-$(PLATFORM_NAME).ipa; \
			else \
				open $(OUTPUTDIR)/net.kdt.pojavlauncher.slimmed-$(VERSION)-$(PLATFORM_NAME).ipa; \
			fi; \
		fi; \
	else \
		echo 'Device not supported for deploy recipe.'; \
	fi
	echo '[Witch v$(VERSION)] deploy - end'

package: payload
	echo '[Witch v$(VERSION)] package - start'
	if [ '$(TEAMID)' != '-1' ] && [ '$(SIGNING_TEAMID)' != '-1' ] && [ -f '$(PROVISIONING)' ] && [ '$(DETECTPLAT)' = 'Darwin' ]; then \
		printf '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">\n<dict>\n	<key>application-identifier</key>\n	<string>$(TEAMID).org.angelauramc.amethyst</string>\n	<key>com.apple.developer.team-identifier</key>\n	<string>$(TEAMID)</string>\n	<key>get-task-allow</key>\n	<true/>\n	<key>keychain-access-groups</key>\n	<array>\n	<string>$(TEAMID).*</string>\n	<string>com.apple.token</string>\n	</array>\n</dict>\n</plist>' > entitlements.codesign.xml; \
		$(MAKE) codesign; \
		rm -rf entitlements.codesign.xml; \
	else \
		echo 'Skipped codesigning. If not intentional, check your variables.'; \
	fi
	cd $(OUTPUTDIR); \
	$(call METHOD_PACKAGE); \
	zip --symlinks -r $(OUTPUTDIR)/java_runtimes.zip java_runtimes; \
	echo '[Witch v$(VERSION)] package - end'
	
dsym: payload
	echo '[Witch v$(VERSION)] dsym - start'
	dsymutil --arch arm64 $(OUTPUTDIR)/Payload/Witch.app/Witch; \
	rm -rf $(OUTPUTDIR)/Witch.dSYM; \
	mv $(OUTPUTDIR)/Payload/Witch.app/Witch.dSYM $(OUTPUTDIR)/Witch.dSYM
	echo '[Witch v$(VERSION)] dsym - end'
	
codesign:
	echo '[Witch v$(VERSION)] codesign - start'
	cp '$(PROVISIONING)' $(OUTPUTDIR)/Payload/Witch.app/embedded.mobileprovision
	# Helper and framework are separate code. Sign them with the same identity
	# before the main binary; METHOD_MACHO_JRE deliberately skips them.
	if [ -d $(OUTPUTDIR)/Payload/Witch.app/Frameworks/StikJIT.framework ]; then \
		codesign --remove-signature $(OUTPUTDIR)/Payload/Witch.app/Frameworks/StikJIT.framework || true; \
		codesign -f -s $(SIGNING_TEAMID) --generate-entitlement-der $(OUTPUTDIR)/Payload/Witch.app/Frameworks/StikJIT.framework || exit 1; \
	fi
	if [ -d $(OUTPUTDIR)/Payload/Witch.app/PlugIns/WitchJITHelper.appex ]; then \
		cp '$(PROVISIONING)' $(OUTPUTDIR)/Payload/Witch.app/PlugIns/WitchJITHelper.appex/embedded.mobileprovision || true; \
		codesign --remove-signature $(OUTPUTDIR)/Payload/Witch.app/PlugIns/WitchJITHelper.appex || true; \
		codesign -f -s $(SIGNING_TEAMID) --generate-entitlement-der $(OUTPUTDIR)/Payload/Witch.app/PlugIns/WitchJITHelper.appex || exit 1; \
	fi
	$(call METHOD_MACHO_JRE,$(OUTPUTDIR)/Payload/Witch.app,$(call METHOD_CODESIGN,$(SIGNING_TEAMID),$$file))
	$(call METHOD_MACHO_JRE,$(OUTPUTDIR)/java_runtimes,$(call METHOD_CODESIGN,$(SIGNING_TEAMID),$$file))
	echo '[Witch v$(VERSION)] codesign - end'

clean:
	echo '[Witch v$(VERSION)] clean - start'
	-xattr -rc $(WORKINGDIR) 2>/dev/null; rm -rf $(WORKINGDIR)
	-xattr -rc JavaApp/build 2>/dev/null; rm -rf JavaApp/build
	-xattr -rc $(OUTPUTDIR) 2>/dev/null; rm -rf $(OUTPUTDIR)
	echo '[Witch v$(VERSION)] clean - end'

		

.PHONY: all clean check native java jre lwgjl dep_mg dep_mobilegl dep_tgles dep_tglmt dep_metalbridge dep_moltenvk dep_moltenvk12 dep_mesa_zink dep_kkosmic dep_angle assets payload package dsym deploy help codesign
