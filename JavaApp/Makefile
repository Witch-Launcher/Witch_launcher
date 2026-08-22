# Prerequisite variables
SOURCEDIR := src
OUTPUTDIR := build
# JavaApp can be built directly as well as via the repository Makefile.  Do
# not assume its caller supplied BOOTJDK: that made the empty value expand to
# `/javac` in both local builds and CI.  Prefer an explicit BOOTJDK, then the
# active JAVA_HOME, then macOS's registered JDK 8, and finally javac on PATH.
BOOTJDK ?= $(shell if [ -n "$$JAVA_HOME" ] && [ -x "$$JAVA_HOME/bin/javac" ]; then printf '%s/bin' "$$JAVA_HOME"; elif [ -x /usr/libexec/java_home ]; then /usr/libexec/java_home -v 1.8 2>/dev/null | awk '{print $$0 "/bin"}'; else which javac 2>/dev/null | xargs dirname; fi)
ifeq (,$(shell test -x "$(BOOTJDK)/javac" && test -x "$(BOOTJDK)/jar" && echo ok))
$(error JDK 8 was not found. Set BOOTJDK=/path/to/jdk8/bin (or JAVA_HOME=/path/to/jdk8))
endif
# javac/mktemp defaults to /var/folders on the system volume; on a nearly-full
# boot drive that fails with "No space left on device". Keep staging on the
# project volume instead (see root Makefile java -j2 note).
# NOTE: JDK 8 on macOS ignores the TMPDIR env var for its own java.io.tmpdir,
# so -J-Djava.io.tmpdir must be passed explicitly, otherwise the javac JVM's
# own temp files (native library extraction etc.) still land on the boot
# volume and fail with "could not create parent directories" when it is full.
JAVAC_TMPDIR := $(abspath $(OUTPUTDIR)/.javac-tmp)
export TMPDIR := $(JAVAC_TMPDIR)

$(shell mkdir -p $(JAVAC_TMPDIR))

SOURCES := $(shell find $(SOURCEDIR) -type f -name '*.java')
CLASSES := $(SOURCES:$(SOURCEDIR)/%.java=$(OUTPUTDIR)/%.class)

TARGETS := $(shell find $(SOURCEDIR) -mindepth 1 -maxdepth 1 -type d)
TARGETS := $(TARGETS:$(SOURCEDIR)/%=$(OUTPUTDIR)/%.jar)
TARGETS += $(OUTPUTDIR)/lwjgl-3.3.3.jar $(OUTPUTDIR)/lwjgl-3.3.6.jar $(OUTPUTDIR)/lwjgl-3.4.1.jar $(OUTPUTDIR)/cacio-init-agent.jar

# Add all jars to classpath and allow compiling with private API
JCFLAGS := -J-Djava.io.tmpdir=$(JAVAC_TMPDIR) -cp "$(subst $() $(),:,$(wildcard $(SOURCEDIR)/*/):$(wildcard libs/*/*.jar))" -XDignore.symbol.file

all: $(TARGETS)
	
# Sometimes the CI produces empty class file resulting in broken jar, so we check and abort here
check_empty_classes:
	@set -e
	@echo "Checking for empty class files"
	$(eval EMPTY_CLASSES := $(shell find $(OUTPUTDIR) -name '*.class' -size 0 | grep -v '\$$' || true))
	@if [ -n "$(EMPTY_CLASSES)" ]; then \
		echo "Error: found empty class files: $(EMPTY_CLASSES)"; \
		exit 1; \
	fi

# Rules for building java class
$(CLASSES): $(OUTPUTDIR)/%.class: $(SOURCEDIR)/%.java
	@set -e; \
	src="$<"; \
	out="$(dir $@)"; \
	base="$$(basename "$$src" .java)"; \
	echo "Compiling $$src"; \
	mkdir -p "$$out"; \
	find "$$out" -maxdepth 1 -name "$$base*.class" -delete; \
	staging="$$(mktemp -d)"; \
	trap 'rm -rf "$$staging"' EXIT; \
	"$(BOOTJDK)/javac" $(JCFLAGS) -d "$$staging" "$$src"; \
	count=$$(find "$$staging" -name "$$base*.class" | wc -l | tr -d ' '); \
	if [ "$$count" -eq 0 ]; then \
		echo "Error: javac produced no class files for $$src"; \
		exit 1; \
	fi; \
	find "$$staging" -name "$$base*.class" -exec cp {} "$$out" \;

$(OUTPUTDIR)/launcher.jar: $(CLASSES)
	@set -e
	@echo "Creating $@"
	@cp -r $(SOURCEDIR)/launcher/META-INF $(basename $@)/ 2>/dev/null || true
	@mkdir -p $(basename $@)/lwjglfix
	@unzip -o -p libs/lwjgl41/lwjgl.jar org/lwjgl/system/Library.class > $(basename $@)/lwjglfix/Library.class
	@mkdir -p $(basename $@)/launchwrapper
	@cp libs/launchwrapper-1.12.jar $(basename $@)/launchwrapper/launchwrapper-1.12.jar
	@find $(basename $@) -name '*.class' -size 0 | grep -v '\$$' && { echo "Error: found empty class files"; exit 1; } || true
	@$(BOOTJDK)/jar -cf $@ -C $(basename $@) .
	# com.apple.ios.audio must live in EXACTLY ONE jar so it is exported by
	# only one module. It stays in launcher.jar (module "launcher") and is
	# stripped from the lwjgl jars below; otherwise the Forge 26.x bootstrap
	# sees "Modules launcher and lwjgl export package com.apple.ios.audio" and
	# aborts with a ResolutionException. The class files must stay on disk
	# so they keep working from the launcher jar.

# Build LWJGL 3.3.3
$(OUTPUTDIR)/lwjgl-3.3.3.jar: $(CLASSES)
	@set -e
	@echo "Creating $@"
	@mkdir -p $(OUTPUTDIR)/lwjgl33_lib
	@cd $(OUTPUTDIR)/lwjgl33_lib && $(BOOTJDK)/jar -xf "../../../lwjgl.jar" && rm -rf META-INF
	@cd $(OUTPUTDIR)/lwjgl33_lib && find ../../libs/lwjgl -name 'lwjgl*.jar' ! -name 'lwjgl.jar' -exec $(BOOTJDK)/jar -xf {} \; && rm -rf META-INF
	@cd $(OUTPUTDIR)/lwjgl33_lib && $(BOOTJDK)/jar -xf "../../libs/lwjgl/lwjgl.jar" && rm -rf META-INF
	@cp -R $(OUTPUTDIR)/lwjgl/* $(OUTPUTDIR)/lwjgl33_lib/
	@$(BOOTJDK)/jar -cf $@ -C $(OUTPUTDIR)/lwjgl33_lib .

# Build LWJGL 3.3.6
$(OUTPUTDIR)/lwjgl-3.3.6.jar: $(CLASSES)
	@set -e
	@echo "Creating $@"
	@mkdir -p $(OUTPUTDIR)/lwjgl36_lib
	@cd $(OUTPUTDIR)/lwjgl36_lib && $(BOOTJDK)/jar -xf "../../../lwjgl.jar" && rm -rf META-INF
	@cd $(OUTPUTDIR)/lwjgl36_lib && find ../../libs/lwjgl36 -name 'lwjgl*.jar' ! -name 'lwjgl.jar' -exec $(BOOTJDK)/jar -xf {} \; && rm -rf META-INF
	@cd $(OUTPUTDIR)/lwjgl36_lib && $(BOOTJDK)/jar -xf "../../libs/lwjgl36/lwjgl.jar" && rm -rf META-INF
	@cp -R $(OUTPUTDIR)/lwjgl/* $(OUTPUTDIR)/lwjgl36_lib/
	@$(BOOTJDK)/jar -cf $@ -C $(OUTPUTDIR)/lwjgl36_lib .

$(OUTPUTDIR)/lwjgl-3.4.1.jar: $(CLASSES)
	@set -e
	@echo "Creating $@"
	@mkdir -p $(OUTPUTDIR)/lwjgl41_lib
	@cd $(OUTPUTDIR)/lwjgl41_lib && $(BOOTJDK)/jar -xf "../../../lwjgl.jar" && rm -rf META-INF
	@cd $(OUTPUTDIR)/lwjgl41_lib && find ../../libs/lwjgl41 -name 'lwjgl*.jar' ! -name 'lwjgl.jar' -exec $(BOOTJDK)/jar -xf {} \; && rm -rf META-INF
	@cd $(OUTPUTDIR)/lwjgl41_lib && $(BOOTJDK)/jar -xf "../../libs/lwjgl41/lwjgl.jar" && rm -rf META-INF
	@cp -R $(OUTPUTDIR)/lwjgl/* $(OUTPUTDIR)/lwjgl41_lib/
	# Forge 26.2 builds a JPMS layer containing the classpath jars; the merged
	# org/jspecify from lwjgl-core would split the package with the real
	# org.jspecify:jspecify jar -> "Split package: org.jspecify". Strip it.
	@rm -rf $(OUTPUTDIR)/lwjgl41_lib/org/jspecify
	@$(BOOTJDK)/jar -cf $@ -C $(OUTPUTDIR)/lwjgl41_lib .

# Legacy alias
$(OUTPUTDIR)/lwjgl.jar: $(OUTPUTDIR)/lwjgl-3.3.3.jar
	@cp $< $@

$(OUTPUTDIR)/patchjna_agent.jar: $(CLASSES)
	@set -e
	@mv $(basename $@)/com/sun/jna/Platform.class $(basename $@)/com/sun/jna/Platform.class.patch
	@echo "Creating $@"
	@$(BOOTJDK)/jar -cfm $@ $(SOURCEDIR)/patchjna_agent.txt -C $(basename $@) .

$(OUTPUTDIR)/cacio-init-agent.jar: $(CLASSES)
	@set -e
	@echo "Creating $@"
	@$(BOOTJDK)/jar -cfm $@ $(SOURCEDIR)/cacio_init_agent.txt -C $(basename $@) .

clean:
	rm -rf $(OUTPUTDIR)

.SUFFIXES: .java
.PHONY: all clean
