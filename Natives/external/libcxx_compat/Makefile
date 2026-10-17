# Makefile for libc++ C++23 compat dylib for iOS
# Provides std::__1::bad_expected_access<void> symbols missing from iOS 16.x libc++

SDK       ?= $(shell xcrun --sdk iphoneos --show-sdk-path)
ARCH      ?= arm64
DEPLOY    ?= 14.0
CXX       ?= c++
OUTDIR    ?= $(shell pwd)/build

CXXFLAGS  = -arch $(ARCH) -std=c++23 -miphoneos-version-min=$(DEPLOY) -fPIC \
            -isysroot $(SDK) -O2 -fvisibility=hidden -fvisibility-inlines-hidden
LDFLAGS   = -arch $(ARCH) -dynamiclib -flat_namespace -undefined dynamic_lookup \
            -miphoneos-version-min=$(DEPLOY) -isysroot $(SDK) \
            -install_name @rpath/libc++_compat.dylib \
            -lc++

.PHONY: all clean

all: $(OUTDIR)/libc++_compat.dylib

$(OUTDIR):
	mkdir -p $(OUTDIR)

$(OUTDIR)/libcxx_compat.o: libcxx_compat.cpp | $(OUTDIR)
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(OUTDIR)/libc++_compat.dylib: $(OUTDIR)/libcxx_compat.o | $(OUTDIR)
	$(CXX) $(LDFLAGS) -o $@ $<
	@echo "[libcxx_compat] Built $@"
	@echo "[libcxx_compat] Size: $$(wc -c < $@) bytes"

clean:
	rm -rf $(OUTDIR)
