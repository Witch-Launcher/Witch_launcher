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
$(error This platform is not currently supported for building Angel Aura Amethyst.)
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

POJAV_BUNDLE_DIR      ?= $(OUTPUTDIR)/AngelAuraAmethyst.app
POJAV_JRE8_DIR        ?= $(SOURCEDIR)/depends/java-8-openjdk
POJAV_JRE17_DIR       ?= $(SOURCEDIR)/depends/java-17-openjdk
POJAV_JRE21_DIR       ?= $(SOURCEDIR)/depends/java-21-openjdk
POJAV_JRE25_DIR       ?= $(SOURCEDIR)/depends/java-25-openjdk

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
	if [ '$(SLIMMED_ONLY)' = '0' ]; then \
		zip --symlinks -r $(OUTPUTDIR)/org.angelauramc.amethyst-$(VERSION)-$(PLATFORM_NAME)$$IPA_SUFFIX Payload; \
	fi; \
	if [ '$(SLIMMED)' = '1' ] || [ '$(SLIMMED_ONLY)' = '1' ]; then \
		zip --symlinks -r $(OUTPUTDIR)/org.angelauramc.amethyst.slimmed-$(VERSION)-$(PLATFORM_NAME)$$IPA_SUFFIX Payload --exclude='Payload/AngelAuraAmethyst.app/java_runtimes/*'; \
	fi

# Function to download and unpack Java runtimes.
METHOD_JAVA_UNPACK = \
	cd $(SOURCEDIR)/depends; \
	if [ ! -f "java-$(1)-openjdk/release" ] && [ ! -f "$(ls jre$(1)-*.tar.xz)" ]; then \
		if [ "$(RUNNER)" != "1" ]; then \
			wget '$(2)' -q --show-progress; \
			unzip jre*-ios-aarch64.zip && rm jre*-ios-aarch64.zip; \
		fi; \
		mkdir -p java-$(1)-openjdk; \
		tar xvf jre$(1)-*.tar.xz -C java-$(1)-openjdk; \
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

all: clean lwgjl native java jre assets payload package dsym

help:
	echo 'Makefile to compile Angel Aura Amethyst'
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
	echo '    make payload                        Makes Payload/AngelAuraAmethyst.app'
	echo '    make package                        Builds ipa of Angel Aura Amethyst'
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
	echo '[Amethyst v$(VERSION)] native - start'
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
	#	--target awt_headless awt_xawt libOSMesaOverride.dylib tinygl4angle AngelAuraAmethyst
	-rm -f $(WORKINGDIR)/libawt_headless.dylib
	echo '[Amethyst v$(VERSION)] native - end'

java: lwgjl
	echo '[Amethyst v$(VERSION)] java - start'
	# lwgjl must finish first: the java compile classpath includes
	# libs/lwjgl{,36,41}/lwjgl.jar, and the lwgjl target writes those jars.
	# Running java in parallel reads partially-written/empty zip files.
	# Each .java file compiles in its own javac VM (JavaApp Makefile), so keep
	# parallelism low: running 10+ javac VMs concurrently with the parallel
	# native/lwgjl/dep_mg jobs exhausts CI runner memory and crashes javac
	# (SIGABRT in _platform_memmove).
	$(MAKE) -C JavaApp -j2 BOOTJDK=$(BOOTJDK)
	echo '[Amethyst v$(VERSION)] java - end'

jre: native
	echo '[Amethyst v$(VERSION)] jre - start'
	mkdir -p $(SOURCEDIR)/depends
	cd $(SOURCEDIR)/depends; \
	$(call METHOD_JAVA_UNPACK,8,'https://assets.angelauramc.dev/openjdk/ios-arm64/jre8-ios-aarch64.zip'); \
	$(call METHOD_JAVA_UNPACK,17,'https://assets.angelauramc.dev/openjdk/ios-arm64/jre17-ios-aarch64.zip'); \
	$(call METHOD_JAVA_UNPACK,21,'https://assets.angelauramc.dev/openjdk/ios-arm64/jre21-ios-aarch64.zip'); \
	$(call METHOD_JAVA_UNPACK,25,'https://assets.angelauramc.dev/openjdk/ios-arm64/jre25-ios-aarch64.zip'); \
	if [ -f "$(ls jre*.tar.xz)" ]; then rm $(SOURCEDIR)/depends/jre*.tar.xz; fi; \
	rm -rf $(SOURCEDIR)/depends/java-{8,17,21,25}-openjdk/{ASSEMBLY_EXCEPTION,bin,include,jre,legal,LICENSE,man,THIRD_PARTY_README,lib/{ct.sym,jspawnhelper,libjsig.dylib,src.zip,tools.jar}}; \
	printf 'amethyst-mirror-mapping-v1\n' > $(SOURCEDIR)/depends/java-17-openjdk/.amethyst-mirror-mapping; \
	printf 'amethyst-mirror-mapping-v1\n' > $(SOURCEDIR)/depends/java-21-openjdk/.amethyst-mirror-mapping; \
	printf 'amethyst-mirror-mapping-v1\n' > $(SOURCEDIR)/depends/java-25-openjdk/.amethyst-mirror-mapping; \
	$(call METHOD_DIRCHECK,$(OUTPUTDIR)/java_runtimes); \
	cp -R $(POJAV_JRE8_DIR) $(OUTPUTDIR)/java_runtimes; \
	cp -R $(POJAV_JRE17_DIR) $(OUTPUTDIR)/java_runtimes; \
	cp -R $(POJAV_JRE21_DIR) $(OUTPUTDIR)/java_runtimes; \
	cp -R $(POJAV_JRE25_DIR) $(OUTPUTDIR)/java_runtimes; \
	cp $(WORKINGDIR)/libawt_xawt.dylib $(OUTPUTDIR)/java_runtimes/java-8-openjdk/lib; \
	cp $(WORKINGDIR)/libawt_xawt.dylib $(OUTPUTDIR)/java_runtimes/java-17-openjdk/lib;
	cp $(WORKINGDIR)/libawt_xawt.dylib $(OUTPUTDIR)/java_runtimes/java-21-openjdk/lib
	cp $(WORKINGDIR)/libawt_xawt.dylib $(OUTPUTDIR)/java_runtimes/java-25-openjdk/lib
	echo '[Amethyst v$(VERSION)] jre - end'

 dep_mg:
	echo '[Amethyst v$(VERSION)] dep_mg - start'
	mkdir -p $(WORKINGDIR)/mobileglues
	cd $(WORKINGDIR)/mobileglues && cmake \
		-DMACOS="1" \
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
	echo '[Amethyst v$(VERSION)] dep_mg - end'

assets:
	echo '[Amethyst v$(VERSION)] assets - start'
	if [ -d /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform ]; then \
		mkdir -p $(WORKINGDIR)/AngelAuraAmethyst.app/Base.lproj; \
		xcrun actool $(SOURCEDIR)/Natives/Assets.xcassets \
			--compile $(SOURCEDIR)/Natives/resources \
			--platform iphoneos \
			--minimum-deployment-target 14.0 \
			--app-icon AppIcon-Light \
			--output-partial-info-plist /dev/null || true; \
	else \
		echo 'Skipping actool - not available'; \
	fi
	echo '[Amethyst v$(VERSION)] assets - end'

lwgjl:
	echo '[Amethyst v$(VERSION)] lwgjl - start'
	@set -e; \
	LWJGL33_DIR="$(SOURCEDIR)/lwgjl/lwjgl3-wip-rebase_3.3.3"; \
	if [ ! -f "$$LWJGL33_DIR/bin/out/liblwjgl.dylib" ]; then \
		echo "Building LWGJL 3.3.3..."; \
		cd "$$LWJGL33_DIR" && export JAVA_HOME="$(JAVA_HOME)" && cd libffi && find build_iphoneos-arm64 -name Makefile -exec touch {} + && touch build_iphoneos-arm64/config.status && make -C build_iphoneos-arm64 && cd .. && mkdir -p bin/libs/native/macos/arm64/org/lwjgl bin/libs/native/macos/x64/org/lwjgl && cp libffi/build_iphoneos-arm64/.libs/libffi.a bin/libs/native/macos/arm64/org/lwjgl/libffi.a && cp bin/libs/native/macos/arm64/org/lwjgl/libffi.a bin/libs/native/macos/x64/org/lwjgl/libffi.a 2>/dev/null && ant -Dplatform.macos=true -Dbinding.assimp=false -Dbinding.bgfx=false -Dbinding.cuda=false -Dbinding.egl=false -Dbinding.fmod=false -Dbinding.harfbuzz=false -Dbinding.hwloc=false -Dbinding.jawt=false -Dbinding.jemalloc=false -Dbinding.ktx=false -Dbinding.libdivide=false -Dbinding.llvm=false -Dbinding.lmdb=false -Dbinding.lz4=false -Dbinding.meow=false -Dbinding.meshoptimizer=false -Dbinding.nfd=false -Dbinding.nuklear=false -Dbinding.odbc=false -Dbinding.opengles=false -Dbinding.opencl=false -Dbinding.openvr=false -Dbinding.openxr=false -Dbinding.opus=false -Dbinding.par=false -Dbinding.remotery=false -Dbinding.renderdoc=false -Dbinding.rpmalloc=false -Dbinding.vulkan=true -Dbinding.vma=true -Dbinding.spvc=true -Dbinding.shaderc=true -Dbinding.sse=false -Dbinding.spng=false -Dbinding.tinyexr=false -Dbinding.tinyfd=true -Dbinding.tootle=false -Dbinding.xxhash=false -Dbinding.yoga=false -Dbinding.zstd=false -Dbinding.sdl=false -Dbuild.type=release/3.3.3 -Djavadoc.skip=true -Dnashorn.args="--no-deprecation-warning" compile-templates compile compile-native release && mkdir -p bin/out && find bin/libs/native/macos/arm64/org/lwjgl -name '*.dylib' -exec cp {} bin/out/ \; || exit 1; \
	fi; \
	echo "Copying 3.3.3 JARs to libs/lwjgl..."; \
	find "$$LWJGL33_DIR/bin/RELEASE" -name '*.jar' ! -name '*-natives-*' ! -name '*-sources.jar' -exec cp {} "$(SOURCEDIR)/JavaApp/libs/lwjgl/" \; ; \
	LWJGL36_DIR="$(SOURCEDIR)/lwgjl/lwjgl3-wip-rebase_3.3.6"; \
	mkdir -p "$(SOURCEDIR)/JavaApp/libs/lwjgl36"; \
	if [ ! -f "$$LWJGL36_DIR/bin/out/liblwjgl.dylib" ]; then \
		echo "Building LWGJL 3.3.6..."; \
		cd "$$LWJGL36_DIR" && export JAVA_HOME="$(JAVA_HOME)" && cd libffi && find build_iphoneos-arm64 -name Makefile -exec touch {} + && touch build_iphoneos-arm64/config.status && make -C build_iphoneos-arm64 && cd .. && mkdir -p bin/libs/native/macos/arm64/org/lwjgl bin/libs/native/macos/x64/org/lwjgl && cp libffi/build_iphoneos-arm64/.libs/libffi.a bin/libs/native/macos/arm64/org/lwjgl/libffi.a && cp bin/libs/native/macos/arm64/org/lwjgl/libffi.a bin/libs/native/macos/x64/org/lwjgl/libffi.a 2>/dev/null && ant -Dplatform.macos=true -Dbinding.assimp=false -Dbinding.bgfx=false -Dbinding.cuda=false -Dbinding.egl=false -Dbinding.fmod=false -Dbinding.harfbuzz=false -Dbinding.hwloc=false -Dbinding.jawt=false -Dbinding.jemalloc=false -Dbinding.ktx=false -Dbinding.libdivide=false -Dbinding.llvm=false -Dbinding.lmdb=false -Dbinding.lz4=false -Dbinding.meow=false -Dbinding.meshoptimizer=false -Dbinding.nfd=false -Dbinding.nuklear=false -Dbinding.odbc=false -Dbinding.opengles=false -Dbinding.opencl=false -Dbinding.openvr=false -Dbinding.openxr=false -Dbinding.opus=false -Dbinding.par=false -Dbinding.remotery=false -Dbinding.renderdoc=false -Dbinding.rpmalloc=false -Dbinding.vulkan=true -Dbinding.vma=true -Dbinding.spvc=true -Dbinding.shaderc=true -Dbinding.sse=false -Dbinding.spng=false -Dbinding.tinyexr=false -Dbinding.tinyfd=true -Dbinding.tootle=false -Dbinding.xxhash=false -Dbinding.yoga=false -Dbinding.zstd=false -Dbinding.sdl=false -Dbuild.type=release/3.3.6 -Djavadoc.skip=true -Dnashorn.args="--no-deprecation-warning" compile-templates compile compile-native release && mkdir -p bin/out && find bin/libs/native/macos/arm64/org/lwjgl -name '*.dylib' -exec cp {} bin/out/ \; || exit 1; \
	fi; \
	echo "Copying 3.3.6 JARs to libs/lwjgl36..."; \
	find "$$LWJGL36_DIR/bin/RELEASE" -name '*.jar' ! -name '*-natives-*' ! -name '*-sources.jar' -exec cp {} "$(SOURCEDIR)/JavaApp/libs/lwjgl36/" \; ; \
	LWJGL41_DIR="$(SOURCEDIR)/lwgjl/lwjgl3-wip-rebase_3.4.1"; \
	if [ ! -f "$$LWJGL41_DIR/bin/out/liblwjgl.dylib" ]; then \
		echo "Building LWGJL 3.4.1..."; \
		cd "$$LWJGL41_DIR" && export JAVA_HOME="$(JAVA_HOME)" && cd libffi && find build_iphoneos-arm64 -name Makefile -exec touch {} + && touch build_iphoneos-arm64/config.status && make -C build_iphoneos-arm64 && cd .. && mkdir -p bin/libs/native/macos/arm64/org/lwjgl bin/libs/native/macos/x64/org/lwjgl && cp libffi/build_iphoneos-arm64/.libs/libffi.a bin/libs/native/macos/arm64/org/lwjgl/libffi.a && cp bin/libs/native/macos/arm64/org/lwjgl/libffi.a bin/libs/native/macos/x64/org/lwjgl/libffi.a 2>/dev/null && ant -Dplatform.macos=true -Dbinding.assimp=false -Dbinding.bgfx=false -Dbinding.cuda=false -Dbinding.egl=false -Dbinding.fmod=false -Dbinding.harfbuzz=false -Dbinding.hwloc=false -Dbinding.jawt=false -Dbinding.jemalloc=false -Dbinding.ktx=false -Dbinding.libdivide=false -Dbinding.llvm=false -Dbinding.lmdb=false -Dbinding.lz4=false -Dbinding.meow=false -Dbinding.meshoptimizer=false -Dbinding.nfd=false -Dbinding.nuklear=false -Dbinding.odbc=false -Dbinding.opengles=false -Dbinding.opencl=false -Dbinding.openvr=false -Dbinding.openxr=false -Dbinding.opus=false -Dbinding.par=false -Dbinding.remotery=false -Dbinding.renderdoc=false -Dbinding.rpmalloc=false -Dbinding.vulkan=true -Dbinding.vma=true -Dbinding.spvc=true -Dbinding.shaderc=true -Dbinding.sse=false -Dbinding.spng=false -Dbinding.tinyexr=false -Dbinding.tinyfd=true -Dbinding.tootle=false -Dbinding.xxhash=false -Dbinding.yoga=false -Dbinding.zstd=false -Dbinding.sdl=false -Dbuild.type=release/3.4.1 -Djavadoc.skip=true -Dnashorn.args="--no-deprecation-warning" compile-templates compile compile-native release && mkdir -p bin/out && find bin/libs/native/macos/arm64/org/lwjgl -name '*.dylib' -exec cp {} bin/out/ \; || exit 1; \
	fi; \
	echo "Copying 3.4.1 JARs to libs/lwjgl41..."; \
	find "$$LWJGL41_DIR/bin/RELEASE" -name '*.jar' ! -name '*-natives-*' ! -name '*-sources.jar' -exec cp {} "$(SOURCEDIR)/JavaApp/libs/lwjgl41/" \; ; \
	echo '[Amethyst v$(VERSION)] lwgjl - end'

payload: native dep_mg lwgjl java jre assets
	echo '[Amethyst v$(VERSION)] payload - start'
	$(call METHOD_DIRCHECK,$(WORKINGDIR)/AngelAuraAmethyst.app/libs)
	$(call METHOD_DIRCHECK,$(WORKINGDIR)/AngelAuraAmethyst.app/libs_caciocavallo)
	$(call METHOD_DIRCHECK,$(WORKINGDIR)/AngelAuraAmethyst.app/libs_caciocavallo17)
	cp -R $(SOURCEDIR)/Natives/resources/en.lproj/LaunchScreen.storyboardc $(WORKINGDIR)/AngelAuraAmethyst.app/Base.lproj/ || exit 1
	cp -R $(SOURCEDIR)/Natives/resources/* $(WORKINGDIR)/AngelAuraAmethyst.app/ || exit 1
	cp $(WORKINGDIR)/*.dylib $(WORKINGDIR)/AngelAuraAmethyst.app/Frameworks/ || exit 1
	cp -R $(SOURCEDIR)/JavaApp/libs/others/* $(WORKINGDIR)/AngelAuraAmethyst.app/libs/ || exit 1
	cp $(SOURCEDIR)/JavaApp/build/launcher.jar $(SOURCEDIR)/JavaApp/build/patchjna_agent.jar $(SOURCEDIR)/JavaApp/build/cacio-init-agent.jar $(WORKINGDIR)/AngelAuraAmethyst.app/libs/ || exit 1
	mkdir -p $(WORKINGDIR)/AngelAuraAmethyst.app/libs/lwjgl33 $(WORKINGDIR)/AngelAuraAmethyst.app/libs/lwjgl36 $(WORKINGDIR)/AngelAuraAmethyst.app/libs/lwjgl41
	cp $(SOURCEDIR)/JavaApp/build/lwjgl-3.3.3.jar $(WORKINGDIR)/AngelAuraAmethyst.app/libs/lwjgl33/lwjgl.jar || exit 1
	cp $(SOURCEDIR)/JavaApp/build/lwjgl-3.3.6.jar $(WORKINGDIR)/AngelAuraAmethyst.app/libs/lwjgl36/lwjgl.jar || exit 1
	cp $(SOURCEDIR)/JavaApp/build/lwjgl-3.4.1.jar $(WORKINGDIR)/AngelAuraAmethyst.app/libs/lwjgl41/lwjgl.jar || exit 1
	mkdir -p $(WORKINGDIR)/AngelAuraAmethyst.app/libs/lwjgl33_natives $(WORKINGDIR)/AngelAuraAmethyst.app/libs/lwjgl36_natives $(WORKINGDIR)/AngelAuraAmethyst.app/libs/lwjgl41_natives
	cp $(SOURCEDIR)/lwgjl/lwjgl3-wip-rebase_3.3.3/bin/out/*.dylib $(WORKINGDIR)/AngelAuraAmethyst.app/libs/lwjgl33_natives/ || exit 1
	cp $(SOURCEDIR)/lwgjl/lwjgl3-wip-rebase_3.3.6/bin/out/*.dylib $(WORKINGDIR)/AngelAuraAmethyst.app/libs/lwjgl36_natives/ || exit 1
	cp $(SOURCEDIR)/lwgjl/lwjgl3-wip-rebase_3.4.1/bin/out/*.dylib $(WORKINGDIR)/AngelAuraAmethyst.app/libs/lwjgl41_natives/ || exit 1
	# LWJGL's libopenal.dylib links ApplicationServices.framework (macOS-only).
	# Replace with iOS-compatible openal-soft build so LWJGL finds it at the
	# expected path but loads a dylib that works on iOS.
	cp $(SOURCEDIR)/Natives/resources/Frameworks/libopenal.dylib \
	   $(WORKINGDIR)/AngelAuraAmethyst.app/libs/lwjgl33_natives/libopenal.dylib
	cp $(SOURCEDIR)/Natives/resources/Frameworks/libopenal.dylib \
	   $(WORKINGDIR)/AngelAuraAmethyst.app/libs/lwjgl36_natives/libopenal.dylib
	cp $(SOURCEDIR)/Natives/resources/Frameworks/libopenal.dylib \
	   $(WORKINGDIR)/AngelAuraAmethyst.app/libs/lwjgl41_natives/libopenal.dylib
	# LWJGL's libfreetype.dylib links CoreGraphics.framework (macOS-only).
	# Replace with the JDK's freetype build which is statically compiled
	# against iOS and doesn't need macOS frameworks.
	cp $(SOURCEDIR)/depends/java-25-openjdk/lib/libfreetype.dylib \
	   $(WORKINGDIR)/AngelAuraAmethyst.app/libs/lwjgl33_natives/libfreetype.dylib
	cp $(SOURCEDIR)/depends/java-25-openjdk/lib/libfreetype.dylib \
	   $(WORKINGDIR)/AngelAuraAmethyst.app/libs/lwjgl36_natives/libfreetype.dylib
	cp $(SOURCEDIR)/depends/java-25-openjdk/lib/libfreetype.dylib \
	   $(WORKINGDIR)/AngelAuraAmethyst.app/libs/lwjgl41_natives/libfreetype.dylib
	# LWJGL 3.4.x SDL binding (org.lwjgl.sdl.SDL) loads "SDL3"; provide the
	# prebuilt iOS arm64 libSDL3 from amethyst-prebuilt-libraries in every
	# natives dir so the game's SDL bootstrap always finds it.
	cp -L $(SOURCEDIR)/amethyst-prebuilt-libraries/SDL/SDL3/build_ios/libSDL3.dylib \
	   $(WORKINGDIR)/AngelAuraAmethyst.app/libs/lwjgl33_natives/libSDL3.dylib
	cp $(SOURCEDIR)/amethyst-prebuilt-libraries/SDL/SDL3/build_ios/libSDL3.0.dylib \
	   $(WORKINGDIR)/AngelAuraAmethyst.app/libs/lwjgl33_natives/libSDL3.0.dylib
	cp -L $(SOURCEDIR)/amethyst-prebuilt-libraries/SDL/SDL3/build_ios/libSDL3.dylib \
	   $(WORKINGDIR)/AngelAuraAmethyst.app/libs/lwjgl36_natives/libSDL3.dylib
	cp $(SOURCEDIR)/amethyst-prebuilt-libraries/SDL/SDL3/build_ios/libSDL3.0.dylib \
	   $(WORKINGDIR)/AngelAuraAmethyst.app/libs/lwjgl36_natives/libSDL3.0.dylib
	cp -L $(SOURCEDIR)/amethyst-prebuilt-libraries/SDL/SDL3/build_ios/libSDL3.dylib \
	   $(WORKINGDIR)/AngelAuraAmethyst.app/libs/lwjgl41_natives/libSDL3.dylib
	cp $(SOURCEDIR)/amethyst-prebuilt-libraries/SDL/SDL3/build_ios/libSDL3.0.dylib \
	   $(WORKINGDIR)/AngelAuraAmethyst.app/libs/lwjgl41_natives/libSDL3.0.dylib
	cp -R $(SOURCEDIR)/JavaApp/libs/caciocavallo/* $(WORKINGDIR)/AngelAuraAmethyst.app/libs_caciocavallo || exit 1
	cp -R $(SOURCEDIR)/JavaApp/libs/caciocavallo17/* $(WORKINGDIR)/AngelAuraAmethyst.app/libs_caciocavallo17 || exit 1
	$(call METHOD_DIRCHECK,$(OUTPUTDIR)/Payload)
	cp -R $(WORKINGDIR)/AngelAuraAmethyst.app $(OUTPUTDIR)/Payload
	if [ '$(SLIMMED_ONLY)' != '1' ]; then \
		cp -R $(OUTPUTDIR)/java_runtimes $(OUTPUTDIR)/Payload/AngelAuraAmethyst.app; \
	fi
	ldid -S $(OUTPUTDIR)/Payload/AngelAuraAmethyst.app; \
	if [ '$(TROLLSTORE_JIT_ENT)' == '1' ]; then \
		ldid -S$(SOURCEDIR)/entitlements.trollstore.xml $(OUTPUTDIR)/Payload/AngelAuraAmethyst.app/AngelAuraAmethyst; \
	elif [ '$(PLATFORM)' == '6' ]; then \
		ldid -S$(SOURCEDIR)/entitlements.codesign.xml $(OUTPUTDIR)/Payload/AngelAuraAmethyst.app/AngelAuraAmethyst; \
	else \
		ldid -S$(SOURCEDIR)/entitlements.sideload.xml $(OUTPUTDIR)/Payload/AngelAuraAmethyst.app/AngelAuraAmethyst; \
	fi
	chmod -R 755 $(OUTPUTDIR)/Payload
	# Always run the platform retag — it's idempotent on already-iOS-tagged
	# Mach-Os, and catches dylibs we drop in fresh from Maven (which ship
	# tagged platform=macos and would be silently rejected by iOS dyld).
	# Originally guarded by `[ PLATFORM != 2 ]` on the assumption that all
	# committed dylibs were already iOS-tagged — that broke when v19 added
	# the 3.3.5 lwjgl-stb dylib straight from upstream.
	$(call METHOD_MACHO,$(OUTPUTDIR)/Payload/AngelAuraAmethyst.app,$(call METHOD_CHANGE_PLAT,$(PLATFORM),$$file)); \
	$(call METHOD_MACHO,$(OUTPUTDIR)/java_runtimes,$(call METHOD_CHANGE_PLAT,$(PLATFORM),$$file));
	echo '[Amethyst v$(VERSION)] payload - end'

deploy:
	echo '[Amethyst v$(VERSION)] deploy - start'
	cd $(OUTPUTDIR); \
	if [ '$(IOS)' = '1' ]; then \
		ldid -S $(WORKINGDIR)/AngelAuraAmethyst.app || exit 1; \
		ldid -S$(SOURCEDIR)/entitlements.trollstore.xml $(WORKINGDIR)/AngelAuraAmethyst.app/AngelAuraAmethyst || exit 1; \
		sudo mv $(WORKINGDIR)/*.dylib $(PREFIX)Applications/AngelAuraAmethyst.app/Frameworks/ || exit 1; \
		sudo mv $(WORKINGDIR)/AngelAuraAmethyst.app/AngelAuraAmethyst $(PREFIX)Applications/AngelAuraAmethyst.app/AngelAuraAmethyst || exit 1; \
		sudo mv $(SOURCEDIR)/JavaApp/build/*.jar $(PREFIX)Applications/AngelAuraAmethyst.app/libs/ || exit 1; \
		cd $(PREFIX)Applications/AngelAuraAmethyst.app/Frameworks || exit 1; \
		sudo chown -R 501:501 $(PREFIX)Applications/AngelAuraAmethyst.app/* || exit 1; \
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
	echo '[Amethyst v$(VERSION)] deploy - end'

package: payload
	echo '[Amethyst v$(VERSION)] package - start'
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
	echo '[Amethyst v$(VERSION)] package - end'
	
dsym: payload
	echo '[Amethyst v$(VERSION)] dsym - start'
	dsymutil --arch arm64 $(OUTPUTDIR)/Payload/AngelAuraAmethyst.app/AngelAuraAmethyst; \
	rm -rf $(OUTPUTDIR)/AngelAuraAmethyst.dSYM; \
	mv $(OUTPUTDIR)/Payload/AngelAuraAmethyst.app/AngelAuraAmethyst.dSYM $(OUTPUTDIR)/AngelAuraAmethyst.dSYM
	echo '[Amethyst v$(VERSION)] dsym - end'
	
codesign:
	echo '[Amethyst v$(VERSION)] codesign - start'
	cp '$(PROVISIONING)' $(OUTPUTDIR)/Payload/AngelAuraAmethyst.app/embedded.mobileprovision
	$(call METHOD_MACHO,$(OUTPUTDIR)/Payload/AngelAuraAmethyst.app,$(call METHOD_CODESIGN,$(SIGNING_TEAMID),$$file))
	$(call METHOD_MACHO,$(OUTPUTDIR)/java_runtimes,$(call METHOD_CODESIGN,$(SIGNING_TEAMID),$$file))
	echo '[Amethyst v$(VERSION)] codesign - end'

clean:
	echo '[Amethyst v$(VERSION)] clean - start'
	rm -rf $(WORKINGDIR)
	rm -rf JavaApp/build
	rm -rf $(OUTPUTDIR)
	echo '[Amethyst v$(VERSION)] clean - end'

		

.PHONY: all clean check native java jre lwgjl dep_mg assets payload package dsym deploy help codesign
