set(_GEN_ARGS use_gold=false target_cpu=\\"${TARGET_CPU}\\" target_os=\\"${TARGET_OS}\\" is_component_build=false)
# Let's not bring in protobuf, as it prevents us from using grpc.
# We also must make sure we are not using the unstable libcxx, lest you want
# your std::strings be broken.
set(_GEN_ARGS ${_GEN_ARGS} rtc_enable_protobuf=false libcxx_abi_unstable=false)

if (MSVC OR XCODE)
  set(_GEN_ARGS ${_GEN_ARGS} is_debug=$<$<CONFIG:Debug>:true>$<$<CONFIG:Release>:false>$<$<CONFIG:RelWithDebInfo>:false>$<$<CONFIG:MinSizeRel>:false>)
  set(_NINJA_BUILD_DIR out/$<$<CONFIG:Debug>:Debug>$<$<CONFIG:Release>:Release>$<$<CONFIG:RelWithDebInfo>:Release>$<$<CONFIG:MinSizeRel>:Release>)
elseif (CMAKE_BUILD_TYPE MATCHES Debug)
  set(_GEN_ARGS ${_GEN_ARGS} is_debug=true)
  set(_NINJA_BUILD_DIR out/Debug)
else (MSVC OR XCODE)
  set(_GEN_ARGS ${_GEN_ARGS} is_debug=false)
  set(_NINJA_BUILD_DIR out/Release)
endif (MSVC OR XCODE)

if (MSVC)
   # Make sure we are not creating weirdness with libc++ vs msvc std lib.
   set(_GEN_ARGS ${_GEN_ARGS} is_clang=false "")
endif()

if (BUILD_TESTS)
  set(_GEN_ARGS ${_GEN_ARGS} rtc_include_tests=true)
else (BUILD_TESTS)
  set(_GEN_ARGS ${_GEN_ARGS} rtc_include_tests=false)
endif (BUILD_TESTS)

if (GN_EXTRA_ARGS)
  set(_GEN_ARGS ${_GEN_ARGS} ${GN_EXTRA_ARGS})
endif (GN_EXTRA_ARGS)

if (WIN32)
  set(_GN_EXECUTABLE gn.bat)
else (WIN32)
  set(_GN_EXECUTABLE gn)
endif (WIN32)

set(_GEN_COMMAND ${_GN_EXECUTABLE} gen ${_NINJA_BUILD_DIR} --args=\"${_GEN_ARGS}\")
