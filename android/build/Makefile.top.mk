LOCAL_PATH := $(_BUILD_ROOT)

# Returns first parameter if the compiler is clang, otherwise
# return the second parameter
if-target-clang = $(if $(filter clang,$(BUILD_TARGET_CC_TYPE)),$1,$2)
if-host-clang   = $(if $(filter clang,$(BUILD_HOST_CC_TYPE)),$1,$2)

# Ruturns first parameter if target os is windows, otherwise
# return the second parameter
#
# We have two different targets, "windows" and "windows_msvc," where
# the first is built with mingw, and the latter is built with the Windows
# SDK.
if-target-any-windows = \
        $(if $(filter windows,$(BUILD_TARGET_OS_FLAVOR)),$1,$2)

ifeq (,$(CONFIG_MIN_BUILD))
ifeq (,$(CONFIG_AEMU64_ONLY))
    # This defines EMULATOR_BUILD_32BITS to indicate that 32-bit binaries
    # must be generated by the build system. We only do this for windows
    EMULATOR_BUILD_32BITS := $(strip $(filter windows,$(BUILD_TARGET_OS)))
endif   # !CONFIG_TESTS_ONLY
endif   # !CONFIG_MIN_BUILD

# No more 32 bits windows.
EMULATOR_BUIL32BITS:=

# This defines EMULATOR_BUILD_64BITS to indicate that 64-bit binaries
# must be generated by the build system.
EMULATOR_BUILD_64BITS := $(strip $(filter linux darwin windows windows_msvc,$(BUILD_TARGET_OS)))

# We only build 64 bits.
EMULATOR_PROGRAM_BITNESS := 64

# A function that includes a file only if 32-bit binaries are necessary,
# or if LOCAL_IGNORE_BITNESS is defined for the current module.
# $1: Build file to include.
include-if-bitness-32 = \
    $(if $(strip $(LOCAL_IGNORE_BITNESS)$(filter true,$(LOCAL_HOST_BUILD))$(EMULATOR_BUILD_32BITS)),\
        $(eval include $1))

# A function that includes a file only of EMULATOR_BUILD_64BITS is not empty.
# or if LOCAL_IGNORE_BITNESS is defined for the current module.
# $1: Build file to include.
include-if-bitness-64 = \
    $(if $(strip $(LOCAL_IGNORE_BITNESS)$(filter true,$(LOCAL_HOST_BUILD))$(EMULATOR_BUILD_64BITS)),\
        $(eval include $1))

BUILD_WARNING_CFLAGS := -Wall -Wno-unknown-pragmas -Wno-sign-compare
BUILD_WARNING_CXXFLAGS := -Wdelete-non-virtual-dtor

BUILD_TARGET_CFLAGS := \
    -g -fno-exceptions \
    $(call if-target-clang,, -fno-unwind-tables) \
    $(BUILD_WARNING_CFLAGS)
BUILD_TARGET_CXXFLAGS := \
    -DGOOGLE_PROTOBUF_NO_RTTI \
    $(BUILD_WARNING_CXXFLAGS)

ifneq (windows_msvc,$(BUILD_TARGET_OS))
    BUILD_TARGET_CXXFLAGS += -fno-rtti
endif

BUILD_OPT_CFLAGS :=
BUILD_OPT_LDFLAGS :=

ifeq ($(BUILD_DEBUG),true)
    BUILD_OPT_CFLAGS += -O0 -DANDROID_DEBUG
    # Enable code coverage for debug builds.
    BUILD_TARGET_CFLAGS += $(call if-target-clang, -fprofile-instr-generate -fcoverage-mapping -fprofile-arcs -ftest-coverage)
    BUILD_OPT_LDFLAGS += $(call if-target-clang, -fprofile-instr-generate -fcoverage-mapping -fprofile-arcs -ftest-coverage --coverage)

    # Always enable address sanitizer for clang builds in debug mode if no specific sanitizer is requested.
    ifeq (,$(BUILD_SANITIZER))
      BUILD_SANITIZER = $(call if-target-clang,address)
    endif
else
    ifneq (windows,$(BUILD_TARGET_OS))
        BUILD_OPT_CFLAGS += -O3 -DNDEBUG=1
    else
    # for windows, qemu1 will crash with O3, lets stay with O2 until qemu1 is gone
        BUILD_OPT_CFLAGS += -O2 -DNDEBUG=1
    endif
    BUILD_OPT_CFLAGS += -fvisibility=hidden
endif

ifeq (windows,$(BUILD_TARGET_OS))
   BUILD_TARGET_CFLAGS += -falign-functions -ftracer

   # pirama@google.com: We're building GCC with --enable-shared so we can get
   # libgcc_eh.a (which is needed for building with Clang).  But in this
   # config, the way the static libraries are built, the linker prefers to use
   # symbols from the shared library instead of the static library.  In our
   # setup, this'd imply carrying the shared libgcc*.DLL as extra baggage.
   # We're instead using -static-libgcc to prefer the static libraries (i.e.
   # the old behavior) even if shared libgcc is available.
   BUILD_OPT_LDFLAGS += -static-libgcc
endif

# Clang has strong opinions about our code, so lets start with
# suppressing most warnings.
CLANG_COMPILER_FLAGS= \
                      -D__STDC_CONSTANT_MACROS \
                      -D_LIBCPP_VERSION=__GLIBCPP__ \
                      -Wno-mismatched-tags \
                      -Wno-\#warnings \
                      -Wno-unused-variable \
                      -Wno-deprecated-declarations \
                      -Wno-c++14-extensions \
                      -Wno-array-bounds \
                      -Wno-builtin-requires-header \
                      -Wno-constant-conversion \
                      -Wno-deprecated-register \
                      -Wno-extern-c-compat \
                      -Wno-gnu-designator \
                      -Wno-inconsistent-missing-override \
                      -Wno-initializer-overrides \
                      -Wno-invalid-constexpr \
                      -Wno-macro-redefined \
                      -Wno-missing-braces \
                      -Wno-missing-field-initializers \
                      -Wno-parentheses-equality \
                      -Wno-pessimizing-move \
                      -Wno-pointer-bool-conversion \
                      -Wno-return-type-c-linkage \
                      -Wno-self-assign \
                      -Wno-shift-negative-value \
                      -Wno-string-plus-int \
                      -Wno-uninitialized \
                      -Wno-unknown-pragmas \
                      -Wno-unused-command-line-argument \
                      -Wno-unused-const-variable \
                      -Wno-unused-function \
                      -Wno-unused-lambda-capture \
                      -Wno-unused-private-field \
                      -Wno-unused-value \
                      -Wswitch \

ifeq (windows_msvc,$(BUILD_TARGET_OS))
    CLANG_COMPILER_FLAGS_TARGET= \
            $(CLANG_COMPILER_FLAGS) \
            -Wno-msvc-not-found \
            -Wno-expansion-to-defined \
            -Wno-ignored-attributes \
            -Wno-unused-local-typedef \
            -Wno-int-to-void-pointer-cast \
            -Wno-ignored-pragma-intrinsic \
            -Wno-pragma-pack \
            -Wno-microsoft-anon-tag \
            -Wno-incompatible-pointer-types \
            -Wno-invalid-token-paste \
            -Wno-microsoft-include \
            -Wno-microsoft-enum-forward-reference \
            -Wno-format \
            -Wno-incompatible-ms-struct \
            -Wno-return-type \
            -Wno-c++11-narrowing \
            -Wno-cast-calling-convention \
            -Wno-comment \
            -Wno-invalid-noreturn \
            -Wno-microsoft-cast \
            -Wno-unused-command-line-argument \
            -Wno-extra-tokens \
            -fcxx-exceptions \
            -fms-compatibility \
            -Wno-undefined-internal \
            -Wno-undefined-inline \
            -Wno-inconsistent-dllimport \
            -DLIEF_DISABLE_FROZEN=on \
            -DNOMINMAX \
            -D_MD \
            -D_DLL \
            -D_CRT_SECURE_NO_WARNINGS \
            -g \
            -Wl,-nodefaultlib:libcmt,-defaultlib:msvcrt,-defaultlib:oldnames

#    ifneq (,$(EMULATOR_BUILD_32BITS))
#        CLANG_COMPILER_FLAGS_TARGET += -target i386-pc-win32
#    else
#        CLANG_COMPILER_FLAGS_TARGET += -target x86_64-pc-win32
#    endif

    CLANG_COMPILER_CXXFLAGS_TARGET= \
            -std=c++14 \
            -Werror=c++14-compat

    # clang-intrins directory was taken from clang/host/linux-x86/clang-4679922/lib64/clang/7.0.1/include
    # We can't simply include the directory here because clang will be it's a system directory and ignore it.
    # We want the clang's intrinsic headers to be first in the search path instead of msvc's.
    # Maybe we can just take out msvc's intrinsic headers instead?
#    CLANG_COMPILER_FLAGS_TARGET += \
#            -I$(MSVC_DIR)/clang-intrins/include \
#            -I$(MSVC_DIR)/msvc/include \
#            -I$(MSVC_DIR)/win10sdk/include/10.0.16299.0/ucrt \
#            -I$(MSVC_DIR)/win10sdk/include/10.0.16299.0/um \
#            -I$(MSVC_DIR)/win10sdk/include/10.0.16299.0/winrt \
#            -I$(MSVC_DIR)/win10sdk/include/10.0.16299.0/hypervisor \
#            -I$(MSVC_DIR)/win10sdk/include/10.0.16299.0/shared

    # oldnames.lib is a wrapper for posix to the ISO C++ conformant functions (read -> _read, etc.).
    # Need to also link with msvcrt.lib for some symbols in oldnames.lib.
#    CLANG_COMPILER_LDFLAGS_TARGET = \
#            $(CLANG_COMPILER_FLAGS_TARGET) \
#            -fuse-ld=lld \
#            -L$(MSVC_DIR)/msvc/lib/x64 \
#            -L$(MSVC_DIR)/win10sdk/lib/10.0.16299.0/ucrt/x64 \
#            -L$(MSVC_DIR)/win10sdk/lib/10.0.16299.0/um/x64
endif

# Add your tidy checks here.
CLANG_TIDY_CHECKS=-*, \
                  modernize-*. \
                  google*, \
                  misc-macro-parentheses, \
                  performance*, \
                  google-readability*, \
                  google-runtime-references \

# Let's not "FIX" every header we can get our hands on.
# You can use the regex in a smart way to exclude headers that
# you do not want to be analyzed.
CLANG_TIDY_HEADER_INCLUDE=android.*(!Compiler.h)

ifeq (windows_msvc,$(BUILD_TARGET_OS))
# Have to separate target and host flags because things like emugen need to be
# compiled to the host system.
BUILD_TARGET_CFLAGS += $(call if-target-clang,$(CLANG_COMPILER_FLAGS_TARGET))
BUILD_TARGET_CXXFLAGS += $(call if-target-clang,$(CLANG_COMPILER_CXXFLAGS_TARGET))
BUILD_HOST_CFLAGS   += $(call if-host-clang,$(CLANG_COMPILER_FLAGS))
else
BUILD_TARGET_CFLAGS += $(call if-target-clang,$(CLANG_COMPILER_FLAGS))
BUILD_HOST_CFLAGS   += $(call if-host-clang,$(CLANG_COMPILER_FLAGS))
endif

ifeq (true,$(BUILD_ENABLE_LTO))
  BUILD_OPT_CFLAGS += -flto
  BUILD_OPT_LDFLAGS += -flto
endif

BUILD_TARGET_CFLAGS += $(BUILD_OPT_CFLAGS)

ifdef BUILD_SNAPSHOT_PROFILE
    BUILD_TARGET_CFLAGS += -DSNAPSHOT_PROFILE=$(BUILD_SNAPSHOT_PROFILE)
endif

# Generate position-independent binaries. Don't add -fPIC when targetting
# Windows, because newer toolchain complain loudly about it, since all
# Windows code is position-independent.
ifneq ($(filter linux darwin,$(BUILD_TARGET_OS)),)
  BUILD_TARGET_CFLAGS += -fPIC
endif

# Ensure that <inttypes.h> always defines all interesting macros.
BUILD_TARGET_CFLAGS += -D__STDC_LIMIT_MACROS=1 -D__STDC_FORMAT_MACROS=1
BUILD_HOST_CFLAGS   += -D__STDC_LIMIT_MACROS=1 -D__STDC_FORMAT_MACROS=1

# Ensure we treat warnings as errors. For third-party libraries, this must
# be disabled with -Wno-error
ifneq (,$(filter windows windows_msvc linux, $(BUILD_TARGET_OS)))
  BUILD_TARGET_CFLAGS += -Werror
endif

# TODO: Remove this when the Breakpad headers have been fixed to not use
#       MSVC-specific #pragma calls.
BUILD_TARGET_CFLAGS += \
        $(call if-target-any-windows, -Wno-unknown-pragmas,)

BUILD_TARGET_CFLAGS32 :=
BUILD_TARGET_CFLAGS64 :=

BUILD_TARGET_LDLIBS :=
BUILD_TARGET_LDLIBS32 :=
BUILD_TARGET_LDLIBS64 :=

BUILD_TARGET_LDFLAGS := $(BUILD_OPT_LDFLAGS)

ifeq (darwin,$(BUILD_TARGET_OS))
  BUILD_TARGET_LDFLAGS += -w
endif

ifeq (windows_msvc,$(BUILD_TARGET_OS))
  BUILD_TARGET_LDFLAGS += $(call if-target-clang,$(CLANG_COMPILER_LDFLAGS_TARGET))
endif

BUILD_TARGET_LDFLAGS32 :=
BUILD_TARGET_LDFLAGS64 :=

ifneq (,$(BUILD_SANITIZER))
    BUILD_TARGET_CFLAGS += -fsanitize=$(BUILD_SANITIZER) -g3
    ifeq ($(BUILD_SANITIZER),address)
        BUILD_TARGET_CFLAGS += -fno-omit-frame-pointer
    endif
    # Pass the right sanitizer flags to clang/gcc linker
    BUILD_TARGET_LDFLAGS += $(call if-target-clang, -fsanitize=$(BUILD_SANITIZER))
endif
# Enable large-file support (i.e. make off_t a 64-bit value).
# Fun fact: The mingw32 toolchain still uses 32-bit off_t values by default
# even when generating Win64 binaries, so modify MY_CFLAGS instead of
# MY_CFLAGS32.
BUILD_TARGET_CFLAGS += -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE

ifeq ($(BUILD_TARGET_OS),freebsd)
  BUILD_TARGET_CFLAGS += -I /usr/local/include
endif

ifeq ($(BUILD_TARGET_OS_FLAVOR),windows)
  # we need Win32 features that are available since Windows 7 (NT 6.1)
  BUILD_TARGET_CFLAGS += -DWINVER=0x601 -D_WIN32_WINNT=0x601 -mcx16
  # LARGEADDRESSAWARE gives more address space to 32-bit process
  BUILD_TARGET_LDFLAGS32 += -Xlinker --large-address-aware -mcx16
  # Reduce the default stack reserve size on 32-bit Windows as we don't have
  # much space there.
  BUILD_TARGET_LDFLAGS32 += -Xlinker --stack -Xlinker 1048576

  # have linker build build-id section for symbol lookup in crash reporting
  BUILD_TARGET_LDFLAGS += -Xlinker --build-id -mcx16
endif

ifeq ($(BUILD_TARGET_OS),darwin)
    BUILD_TARGET_CFLAGS += -D_DARWIN_C_SOURCE=1
    # Clang annoys everyone with a warning about empty struct size being
    # different in C and C++.
    BUILD_TARGET_CFLAGS += -Wno-extern-c-compat

    # Use regular fseek/ftell as those are 64-bit compatible.
    BUILD_TARGET_CFLAGS += -Dftello64=ftell -Dfseeko64=fseek
endif

# NOTE: The following definitions are only used by the standalone build.
BUILD_TARGET_EXEEXT :=
BUILD_TARGET_DLLEXT := .so
BUILD_TARGET_STATIC_PREFIX := lib
BUILD_TARGET_STATIC_LIBEXT := .a
ifeq ($(BUILD_TARGET_OS_FLAVOR),windows)
  BUILD_TARGET_EXEEXT := .exe
  BUILD_TARGET_DLLEXT := .dll
endif
ifeq ($(BUILD_TARGET_OS),darwin)
  BUILD_TARGET_DLLEXT := .dylib
endif

ifeq ($(BUILD_TARGET_OS),windows_msvc)
  BUILD_TARGET_STATIC_PREFIX :=
  BUILD_TARGET_STATIC_LIBEXT := .lib
endif

# Some CFLAGS below use -Wno-missing-field-initializers but this is not
# supported on GCC 3.x which is still present under Cygwin.
# Find out by probing GCC for support of this flag. Note that the test
# itself only works on GCC 4.x anyway.
GCC_W_NO_MISSING_FIELD_INITIALIZERS := -Wno-missing-field-initializers
ifeq ($(BUILD_TARGET_OS),windows)
    ifeq (,$(shell gcc -Q --help=warnings 2>/dev/null | grep missing-field-initializers))
        $(info emulator: Ignoring unsupported GCC flag $(GCC_W_NO_MISSING_FIELD_INITIALIZERS))
        GCC_W_NO_MISSING_FIELD_INITIALIZERS :=
    endif
endif

ifeq ($(BUILD_TARGET_OS),windows)
  # Ensure that printf() et al use GNU printf format specifiers as required
  # by QEMU. This is important when using the newer Mingw64 cross-toolchain.
  # See http://sourceforge.net/apps/trac/mingw-w64/wiki/gnu%20printf
  BUILD_TARGET_CFLAGS += -D__USE_MINGW_ANSI_STDIO=1
endif

# Enable warning, except those related to missing field initializers
# (the QEMU coding style loves using these).
# Also disable the strict overflow checking, as GCC sometimes inlines so much
# with LTO enabled that it finds some comparisons to become a + b < a just
# because of inlining, with no original relying on the overflow at all.
#
BUILD_TARGET_CFLAGS += \
    $(GCC_W_NO_MISSING_FIELD_INITIALIZERS) -Wno-strict-overflow

BUILD_TARGET_CXXFLAGS += -Wno-invalid-offsetof

# Needed to build block.c on Linux/x86_64.
BUILD_TARGET_CFLAGS += -D_GNU_SOURCE=1

# Some system headers use '__packed' instead of '__attribute__((packed))'
BUILD_TARGET_CFLAGS += -D__packed=__attribute\(\(packed\)\)

# Copy the current target cflags into the host ones.
ifneq ($(BUILD_TARGET_OS), windows_msvc)
    BUILD_HOST_CXXFLAGS += $(BUILD_TARGET_CXXFLAGS)
    BUILD_HOST_LDFLAGS += $(BUILD_TARGET_LDFLAGS)
endif

# A useful function that can be used to start the declaration of a host
# module. Avoids repeating the same stuff again and again.
# Usage:
#
#  $(call start-emulator-library, <module-name>)
#
#  ... declarations
#
#  $(call end-emulator-library)
#
start-emulator-library = \
    $(eval include $(CLEAR_VARS)) \
    $(eval LOCAL_MODULE := $1) \
    $(eval LOCAL_MODULE_CLASS := STATIC_LIBRARIES) \
    $(eval LOCAL_BUILD_FILE := $(BUILD_HOST_STATIC_LIBRARY))

# Used with start-emulator-library
end-emulator-library = \
    $(eval $(end-emulator-module-ev)) \

define-emulator-prebuilt-library = \
    $(call start-emulator-library,$1) \
    $(eval LOCAL_BUILD_FILE := $(PREBUILT_STATIC_LIBRARY)) \
    $(eval LOCAL_SRC_FILES := $2) \
    $(eval $(end-emulator-module-ev)) \

start-emulator-shared-lib = \
    $(call start-emulator-shared-lib,$1) \
    $(eval LOCAL_MODULE_CLASS := SHARED_LIBRARIES) \
    $(eval LOCAL_BUILD_FILE := $(BUILD_HOST_SHARED_LIBRARY)) \

# A varient of end-emulator-library for host programs instead
end-emulator-shared-lib = \
    $(eval LOCAL_LDLIBS += $(QEMU_SYSTEM_LDLIBS)) \
    $(if $(filter linux,$(BUILD_TARGET_OS)), \
      $(eval LOCAL_LDFLAGS += -Wl,-rpath=\$$$$ORIGIN/lib64:\$$$$ORIGIN/lib)) \
    $(if $(filter darwin,$(BUILD_TARGET_OS)), \
      $(eval LOCAL_LDFLAGS += -Wl,-install_name,@rpath/$(LOCAL_MODULE)$(BUILD_TARGET_DLLEXT))) \
    $(eval $(end-emulator-module-ev)) \

# A variant of start-emulator-program that also links the Google Benchmark
# library to the final program. Use with end-emulator-benchmark.
# NOTE: These are _not_ compiled by default, unless BUILD_BENCHMARKS is
# set to 'true', which happens is you call android/configure.sh with the
# --benchmarks option.
start-emulator-benchmark = \
  $(call start-emulator-program,$1)

# A variant of end-emulator-program for host benchmark programs instead.
end-emulator-benchmark = \
  $(eval LOCAL_C_INCLUDES += $$(GOOGLE_BENCHMARK_INCLUDES)) \
  $(eval LOCAL_STATIC_LIBRARIES += $$(GOOGLE_BENCHMARK_STATIC_LIBRARIES)) \
  $(eval LOCAL_LDLIBS += $$(GOOGLE_BENCHMARK_LDLIBS)) \
  $(call local-link-static-c++lib) \
  $(if $(filter true,$(BUILD_BENCHMARKS)),$(call end-emulator-program))

define end-emulator-module-ev
LOCAL_BITS := $$(BUILD_TARGET_BITS)
include $$(LOCAL_BUILD_FILE)
endef

# The common libraries
#
QEMU_SYSTEM_LDLIBS :=
ifeq ($(BUILD_TARGET_OS),windows_msvc)
    QEMU_SYSTEM_LDLIBS += -ladvapi32
endif

ifeq ($(BUILD_TARGET_OS),windows)
    QEMU_SYSTEM_LDLIBS += -lm -mwindows -mconsole
endif

ifeq ($(BUILD_TARGET_OS),freebsd)
    QEMU_SYSTEM_LDLIBS += -L/usr/local/lib -lm -lX11 -lutil
endif

ifeq ($(BUILD_TARGET_OS),linux)
    QEMU_SYSTEM_LDLIBS += -lm -lutil -lrt
endif

# amd64-mingw32msvc- toolchain still name it ws2_32.  May change it once amd64-mingw32msvc-
# is stabilized
QEMU_SYSTEM_LDLIBS += \
        $(call if-target-any-windows, \
        -lwinmm -lws2_32 -liphlpapi, \
        -lpthread)

ifeq ($(BUILD_TARGET_OS),darwin)
  QEMU_SYSTEM_FRAMEWORKS := \
      AudioUnit \
      AVFoundation \
      Cocoa \
      CoreAudio \
      CoreMedia \
      CoreVideo \
      ForceFeedback \
      IOKit \
      QTKit \
      VideoDecodeAcceleration \
      VideoToolbox

  QEMU_SYSTEM_LDLIBS += $(QEMU_SYSTEM_FRAMEWORKS:%=-Wl,-framework,%)
endif

ifneq ($(BUILD_TARGET_OS),windows_msvc)
ifeq ($(BUILD_TARGET_OS),windows)
    CXX_STD_LIB := -lstdc++
else
    CXX_STD_LIB := -lc++
endif
endif


# Always build 64 bits version
BUILD_TARGET_BITS := 64
BUILD_TARGET_ARCH := x86_64
BUILD_TARGET_SUFFIX := 64
BUILD_HOST_BITS := 64
BUILD_HOST_ARCH := x86_64
BUILD_HOST_SUFFIX := 64
include $(LOCAL_PATH)/android/build/Makefile.common.mk


$(foreach prebuilt_pair,$(PREBUILT_PATH_PAIRS), \
    $(eval $(call install-prebuilt, $(prebuilt_pair))))

$(foreach prebuilt_sym_pair,$(PREBUILT_SYMPATH_PAIRS), \
    $(eval $(call install-prebuilt-symlink, $(prebuilt_sym_pair))))

## VOILA!!
