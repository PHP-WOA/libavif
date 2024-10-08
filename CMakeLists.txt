# Copyright 2019 Joe Drago. All rights reserved.
# SPDX-License-Identifier: BSD-2-Clause

cmake_minimum_required(VERSION 3.15)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
# Specify search path for CMake modules to be loaded by include()
# and find_package()
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/Modules")

project(libavif LANGUAGES C VERSION 0.9.0)

# Set C99 as the default
set(CMAKE_C_STANDARD 99)

# SOVERSION scheme: MAJOR.MINOR.PATCH
#   If there was an incompatible interface change:
#     Increment MAJOR. Set MINOR and PATCH to 0
#   If there was a compatible interface change:
#     Increment MINOR. Set PATCH to 0
#   If the source code was changed, but there were no interface changes:
#     Increment PATCH.
set(LIBRARY_VERSION_MAJOR 10)
set(LIBRARY_VERSION_MINOR 0)
set(LIBRARY_VERSION_PATCH 0)
set(LIBRARY_VERSION "${LIBRARY_VERSION_MAJOR}.${LIBRARY_VERSION_MINOR}.${LIBRARY_VERSION_PATCH}")
set(LIBRARY_SOVERSION ${LIBRARY_VERSION_MAJOR})

option(BUILD_SHARED_LIBS "Build shared avif library" ON)
set(CMAKE_STATIC_LIBRARY_SUFFIX "_a.lib")

option(AVIF_ENABLE_WERROR "Treat all compiler warnings as errors" ON)

option(AVIF_CODEC_AOM "Use the AOM codec for encoding/decoding (see AVIF_CODEC_AOM_DECODE/AVIF_CODEC_AOM_ENCODE)" OFF)
option(AVIF_CODEC_DAV1D "Use the dav1d codec for decoding" OFF)
option(AVIF_CODEC_LIBGAV1 "Use the libgav1 codec for decoding" OFF)
option(AVIF_CODEC_RAV1E "Use the rav1e codec for encoding" OFF)
option(AVIF_CODEC_SVT "Use the SVT-AV1 codec for encoding" OFF)

# These options allow libavif to only link against / use libaom's encoder or decoder, instead of being forced to use both
option(AVIF_CODEC_AOM_DECODE "if AVIF_CODEC_AOM is on, use/offer libaom's decoder" ON)
option(AVIF_CODEC_AOM_ENCODE "if AVIF_CODEC_AOM is on, use/offer libaom's encoder" ON)

option(AVIF_LOCAL_AOM "Build the AOM codec by providing your own copy of the repo in ext/aom (see Local Builds in README)" OFF)
option(AVIF_LOCAL_DAV1D "Build the dav1d codec by providing your own copy of the repo in ext/dav1d (see Local Builds in README)" OFF)
option(AVIF_LOCAL_LIBGAV1 "Build the libgav1 codec by providing your own copy of the repo in ext/libgav1 (see Local Builds in README)" OFF)
option(AVIF_LOCAL_RAV1E "Build the rav1e codec by providing your own copy of the repo in ext/rav1e (see Local Builds in README)" OFF)
option(AVIF_LOCAL_SVT "Build the SVT-AV1 codec by providing your own copy of the repo in ext/SVT-AV1 (see Local Builds in README)" OFF)

if(AVIF_LOCAL_LIBGAV1)
    enable_language(CXX)
endif()

if(APPLE)
    set(XCRUN xcrun)
else()
    set(XCRUN)
endif()

# ---------------------------------------------------------------------------------------
# This insanity is for people embedding libavif or making fully static or Windows builds.
# Any proper unix environment should ignore these entire following blocks.
option(AVIF_LOCAL_ZLIBPNG "Build zlib and libpng by providing your own copy inside the ext subdir." OFF)
if(AVIF_LOCAL_ZLIBPNG)
    add_subdirectory(ext/zlib)
    # Put the value of ZLIB_INCLUDE_DIR in the cache. This works around cmake behavior that has been updated by
    # cmake policy CMP0102 in cmake 3.17. Remove the CACHE workaround when we require cmake 3.17 or later. See
    # https://gitlab.kitware.com/cmake/cmake/-/issues/21343.
    set(ZLIB_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ext/zlib" CACHE PATH "zlib include dir")
    include_directories("${CMAKE_CURRENT_BINARY_DIR}/ext/zlib")
    set(CMAKE_DEBUG_POSTFIX "")

    # This is the only way I could avoid libpng going crazy if it found awk.exe, seems benign otherwise
    set(PREV_ANDROID ${ANDROID})
    set(ANDROID TRUE)
    set(PNG_BUILD_ZLIB "${CMAKE_CURRENT_SOURCE_DIR}/ext/zlib" CACHE STRING "" FORCE)
    set(PNG_SHARED OFF CACHE BOOL "")
    set(PNG_TESTS OFF CACHE BOOL "")
    add_subdirectory(ext/libpng)
    set(PNG_PNG_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ext/libpng")
    set(PNG_LIBRARY png_static)
    include_directories("${CMAKE_CURRENT_BINARY_DIR}/ext/libpng")
    set(ANDROID ${PREV_ANDROID})

    set(ZLIB_LIBRARY zlibstatic)
endif()
option(AVIF_LOCAL_JPEG "Build jpeg by providing your own copy inside the ext subdir." OFF)
if(AVIF_LOCAL_JPEG)
    add_subdirectory(ext/libjpeg)
    if("${CMAKE_SOURCE_DIR}" STREQUAL  "${CMAKE_CURRENT_SOURCE_DIR}")
        set(JPEG_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ext/libjpeg")
        set(JPEG_LIBRARY jpeg)
    else()
        set(JPEG_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ext/libjpeg" PARENT_SCOPE)
        set(JPEG_LIBRARY jpeg PARENT_SCOPE)
    endif()
endif()
option(AVIF_LOCAL_LIBYUV "Build libyuv by providing your own copy inside the ext subdir." OFF)
if(AVIF_LOCAL_LIBYUV)
    set(LIB_FILENAME "${CMAKE_CURRENT_SOURCE_DIR}/ext/libyuv/build/${CMAKE_STATIC_LIBRARY_PREFIX}yuv${CMAKE_STATIC_LIBRARY_SUFFIX}")
    if(NOT EXISTS "${LIB_FILENAME}")
        message(FATAL_ERROR "libavif(AVIF_LOCAL_LIBYUV): ${LIB_FILENAME} is missing, bailing out")
    endif()
    if("${CMAKE_SOURCE_DIR}" STREQUAL "${CMAKE_CURRENT_SOURCE_DIR}")
        set(LIBYUV_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ext/libyuv/include")
        set(LIBYUV_LIBRARY ${LIB_FILENAME})
    else()
        set(LIBYUV_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ext/libyuv/include" PARENT_SCOPE)
        set(LIBYUV_LIBRARY ${LIB_FILENAME} PARENT_SCOPE)
    endif()
endif()
# ---------------------------------------------------------------------------------------

# Enable all warnings
include(CheckCCompilerFlag)
if(CMAKE_C_COMPILER_ID MATCHES "Clang")
    MESSAGE(STATUS "libavif: Enabling warnings for Clang")
    add_definitions(
        -Weverything
        -Wno-bad-function-cast
        -Wno-cast-align
        -Wno-conversion
        -Wno-covered-switch-default
        -Wno-disabled-macro-expansion
        -Wno-documentation
        -Wno-documentation-unknown-command
        -Wno-double-promotion
        -Wno-float-equal
        -Wno-missing-noreturn
        -Wno-padded
        -Wno-sign-conversion
        -Wno-error=c11-extensions
    )
    # The detection of cross compilation by -Wpoison-system-directories has false positives on macOS because
    # --sysroot is implicitly added. Turn the warning off.
    if(NOT DEFINED HAVE_POISON_SYSTEM_DIRECTORIES_WARNING)
        check_c_compiler_flag(-Wpoison-system-directories HAVE_POISON_SYSTEM_DIRECTORIES_WARNING)
    endif()
    if(HAVE_POISON_SYSTEM_DIRECTORIES_WARNING)
        add_definitions(-Wno-poison-system-directories)
    endif()
    # MINGW declares printf with __attribute__ ((__unused__)) in stdio.h.
    # It is out of our control so we just ignore it.
    # See https://sourceforge.net/p/mingw-w64/bugs/868/
    if(MINGW)
        add_definitions(-Wno-used-but-marked-unused)
    endif()
elseif(CMAKE_C_COMPILER_ID MATCHES "GNU")
    MESSAGE(STATUS "libavif: Enabling warnings for GCC")
    add_definitions(-Wall -Wextra)
elseif(CMAKE_C_COMPILER_ID MATCHES "MSVC")
    MESSAGE(STATUS "libavif: Enabling warnings for MSVC")
    add_definitions(
        /Wall   # All warnings
        /wd4255 # Disable: no function prototype given
        /wd4324 # Disable: structure was padded due to alignment specifier
        /wd4668 # Disable: is not defined as a preprocessor macro, replacing with '0'
        /wd4710 # Disable: function not inlined
        /wd4711 # Disable: function selected for inline expansion
        /wd4738 # Disable: storing 32-bit float result in memory, possible loss of performance
        /wd4820 # Disable: bytes padding added after data member
        /wd4996 # Disable: potentially unsafe stdlib methods
        /wd5045 # Disable: Compiler will insert Spectre mitigation for memory load if /Qspectre switch specified
        # This tells MSVC to read source code as UTF-8 and assume console can only use ASCII (minimal safe).
        # libavif uses ANSI API to print to console, which is not portable between systems using different
        # languages and results in mojibake unless we only use codes shared by every code page: ASCII.
        # A C4556 warning will be generated on violation.
        # Commonly used /utf-8 flag assumes UTF-8 for both source and console, which is usually not the case.
        # Warnings can be suppressed but there will still be random characters printed to the console.
        /source-charset:utf-8 /execution-charset:us-ascii
    )
else()
    MESSAGE(FATAL_ERROR "libavif: Unknown compiler, bailing out")
endif()

if(AVIF_ENABLE_WERROR)
    # Warnings as errors
    if(CMAKE_C_COMPILER_ID MATCHES "Clang" OR CMAKE_C_COMPILER_ID MATCHES "GNU")
        add_definitions(-Werror)
    elseif(CMAKE_C_COMPILER_ID MATCHES "MSVC")
        add_definitions(/WX)
    else()
        MESSAGE(FATAL_ERROR "libavif: Unknown compiler, bailing out")
    endif()
endif()

if(AVIF_ENABLE_COVERAGE)
    if(CMAKE_C_COMPILER_ID MATCHES "Clang" OR CMAKE_C_COMPILER_ID MATCHES "GNU")
        MESSAGE(STATUS "libavif: Enabling coverage for Clang")
        add_definitions(-fprofile-instr-generate -fcoverage-mapping -O0)
        set(CMAKE_EXE_LINKER_FLAGS ${CMAKE_EXE_LINKER_FLAGS} "-fprofile-instr-generate -fcoverage-mapping")
    else()
        # TODO: Add support for other compilers
        message(WARNING "libavif: Ignoring request for coverage (AVIF_ENABLE_COVERAGE); only clang is currently supported.")
    endif()
endif()

set(AVIF_SRCS
    src/alpha.c
    src/avif.c
    src/colr.c
    src/io.c
    src/mem.c
    src/obu.c
    src/rawdata.c
    src/read.c
    src/reformat.c
    src/reformat_libyuv.c
    src/stream.c
    src/utils.c
    src/write.c
)

set(AVIF_PLATFORM_DEFINITIONS)
set(AVIF_PLATFORM_INCLUDES)
set(AVIF_PLATFORM_LIBRARIES)
if(UNIX)
    # Find out if we have threading available
    set(CMAKE_THREAD_PREFER_PTHREADS ON)
    set(THREADS_PREFER_PTHREAD_FLAG ON)
    find_package(Threads)
    set(AVIF_PLATFORM_LIBRARIES m Threads::Threads)
endif()

find_package(libyuv QUIET) # not required
if(libyuv_FOUND)
    message(STATUS "libavif: libyuv found, libyuv-based fast paths enabled.")
    set(AVIF_PLATFORM_DEFINITIONS ${AVIF_PLATFORM_DEFINITIONS} -DAVIF_LIBYUV_ENABLED=1)
    set(AVIF_PLATFORM_INCLUDES ${AVIF_PLATFORM_INCLUDES} ${LIBYUV_INCLUDE_DIR})
    set(AVIF_PLATFORM_LIBRARIES ${AVIF_PLATFORM_LIBRARIES} ${LIBYUV_LIBRARY})
else()
    message(STATUS "libavif: libyuv not found, libyuv-based fast paths disabled.")
endif()

set(AVIF_CODEC_DEFINITIONS)
set(AVIF_CODEC_INCLUDES)
set(AVIF_CODEC_LIBRARIES)

if(AVIF_CODEC_DAV1D)
    message(STATUS "libavif: Codec enabled: dav1d (decode)")
    set(AVIF_CODEC_DEFINITIONS ${AVIF_CODEC_DEFINITIONS} -DAVIF_CODEC_DAV1D=1)
    set(AVIF_SRCS ${AVIF_SRCS}
        src/codec_dav1d.c
    )

    if(AVIF_LOCAL_DAV1D)
        set(LIB_FILENAME "${CMAKE_CURRENT_SOURCE_DIR}/ext/dav1d/build/src/libdav1d.a")
        if(NOT EXISTS "${LIB_FILENAME}")
            message(FATAL_ERROR "libavif: ${LIB_FILENAME} is missing, bailing out")
        endif()

        set(AVIF_CODEC_INCLUDES ${AVIF_CODEC_INCLUDES}
            "${CMAKE_CURRENT_SOURCE_DIR}/ext/dav1d/build"
            "${CMAKE_CURRENT_SOURCE_DIR}/ext/dav1d/build/include"
            "${CMAKE_CURRENT_SOURCE_DIR}/ext/dav1d/build/include/dav1d"
            "${CMAKE_CURRENT_SOURCE_DIR}/ext/dav1d/include"
        )
        set(AVIF_CODEC_LIBRARIES ${AVIF_CODEC_LIBRARIES} ${LIB_FILENAME})
    else()
        # Check to see if dav1d is independently being built by the outer CMake project
        if(NOT TARGET dav1d)
            find_package(dav1d REQUIRED)
            set(AVIF_CODEC_INCLUDES ${AVIF_CODEC_INCLUDES} ${DAV1D_INCLUDE_DIR})
        endif()
        set(AVIF_CODEC_LIBRARIES ${AVIF_CODEC_LIBRARIES} ${DAV1D_LIBRARY})
    endif()

    if(UNIX AND NOT APPLE)
        set(AVIF_PLATFORM_LIBRARIES ${AVIF_PLATFORM_LIBRARIES} ${CMAKE_DL_LIBS}) # for dlsym
    endif()
endif()

if(AVIF_CODEC_LIBGAV1)
    message(STATUS "libavif: Codec enabled: libgav1 (decode)")
    set(AVIF_CODEC_DEFINITIONS ${AVIF_CODEC_DEFINITIONS} -DAVIF_CODEC_LIBGAV1=1)
    set(AVIF_SRCS ${AVIF_SRCS}
        src/codec_libgav1.c
    )

    if(AVIF_LOCAL_LIBGAV1)
        set(LIB_FILENAME "${CMAKE_CURRENT_SOURCE_DIR}/ext/libgav1/build/libgav1${CMAKE_STATIC_LIBRARY_SUFFIX}")
        if(NOT EXISTS "${LIB_FILENAME}")
            message(FATAL_ERROR "libavif: ${LIB_FILENAME} is missing, bailing out")
        endif()

        set(AVIF_CODEC_INCLUDES ${AVIF_CODEC_INCLUDES}
            "${CMAKE_CURRENT_SOURCE_DIR}/ext/libgav1/src"
        )
        set(AVIF_CODEC_LIBRARIES ${AVIF_CODEC_LIBRARIES} ${LIB_FILENAME})
    else()
        # Check to see if libgav1 is independently being built by the outer CMake project
        if(NOT TARGET libgav1)
            find_package(libgav1 REQUIRED)
            set(AVIF_CODEC_INCLUDES ${AVIF_CODEC_INCLUDES} ${LIBGAV1_INCLUDE_DIR})
        endif()
        set(AVIF_CODEC_LIBRARIES ${AVIF_CODEC_LIBRARIES} ${LIBGAV1_LIBRARY})
    endif()
endif()

if(AVIF_CODEC_RAV1E)
    message(STATUS "libavif: Codec enabled: rav1e (encode)")
    set(AVIF_CODEC_DEFINITIONS ${AVIF_CODEC_DEFINITIONS} -DAVIF_CODEC_RAV1E=1)
    set(AVIF_SRCS ${AVIF_SRCS}
        src/codec_rav1e.c
    )

    if(AVIF_LOCAL_RAV1E)
        set(LIB_FILENAME "${CMAKE_CURRENT_SOURCE_DIR}/ext/rav1e/target/release/${CMAKE_STATIC_LIBRARY_PREFIX}rav1e${CMAKE_STATIC_LIBRARY_SUFFIX}")
        if(NOT EXISTS "${LIB_FILENAME}")
            message(FATAL_ERROR "libavif: compiled rav1e library is missing (in ext/rav1e/target/release), bailing out")
        endif()

        set(AVIF_CODEC_INCLUDES ${AVIF_CODEC_INCLUDES}
            "${CMAKE_CURRENT_SOURCE_DIR}/ext/rav1e/target/release"
        )
        set(AVIF_CODEC_LIBRARIES ${AVIF_CODEC_LIBRARIES} ${LIB_FILENAME})
    else()
        # Check to see if rav1e is independently being built by the outer CMake project
        if(NOT TARGET rav1e)
            find_package(rav1e REQUIRED)
            set(AVIF_CODEC_INCLUDES ${AVIF_CODEC_INCLUDES} ${RAV1E_INCLUDE_DIR})
        endif()
        set(AVIF_CODEC_LIBRARIES ${AVIF_CODEC_LIBRARIES} ${RAV1E_LIBRARY})
    endif()

    # Unfortunately, rav1e requires a few more libraries
    if(WIN32)
        set(AVIF_PLATFORM_LIBRARIES ${AVIF_PLATFORM_LIBRARIES} ws2_32.lib userenv.lib)
    elseif(UNIX AND NOT APPLE)
        set(AVIF_PLATFORM_LIBRARIES ${AVIF_PLATFORM_LIBRARIES} ${CMAKE_DL_LIBS}) # for backtrace
    endif()
endif()

if(AVIF_CODEC_SVT)
    message(STATUS "libavif: Codec enabled: svt (encode)")
    set(AVIF_CODEC_DEFINITIONS ${AVIF_CODEC_DEFINITIONS} -DAVIF_CODEC_SVT=1)
    set(AVIF_SRCS ${AVIF_SRCS}
        src/codec_svt.c
    )

    if(AVIF_LOCAL_SVT)
        set(LIB_FILENAME "${CMAKE_CURRENT_SOURCE_DIR}/ext/SVT-AV1/Bin/Release/${CMAKE_STATIC_LIBRARY_PREFIX}SvtAv1Enc${CMAKE_STATIC_LIBRARY_SUFFIX}")
        if(NOT EXISTS "${LIB_FILENAME}")
            message(FATAL_ERROR "libavif: compiled svt library is missing (in ext/SVT-AV1/Bin/Release), bailing out")
        endif()

        set(AVIF_CODEC_INCLUDES ${AVIF_CODEC_INCLUDES}
            "${CMAKE_CURRENT_SOURCE_DIR}/ext/SVT-AV1/include"
        )
        set(AVIF_CODEC_LIBRARIES ${AVIF_CODEC_LIBRARIES} ${LIB_FILENAME})
    else()
        # Check to see if svt is independently being built by the outer CMake project
        if(NOT TARGET svt)
            find_package(svt REQUIRED)
            set(AVIF_CODEC_INCLUDES ${AVIF_CODEC_INCLUDES} ${SVT_INCLUDE_DIR})
        endif()
        set(AVIF_CODEC_LIBRARIES ${AVIF_CODEC_LIBRARIES} ${SVT_LIBRARY})
    endif()
endif()

if(AVIF_CODEC_AOM)
    set(AVIF_CODEC_DEFINITIONS ${AVIF_CODEC_DEFINITIONS} -DAVIF_CODEC_AOM=1)
    if(AVIF_CODEC_AOM_ENCODE AND AVIF_CODEC_AOM_DECODE)
        message(STATUS "libavif: Codec enabled: aom (encode/decode)")
        set(AVIF_CODEC_DEFINITIONS ${AVIF_CODEC_DEFINITIONS} -DAVIF_CODEC_AOM_ENCODE=1 -DAVIF_CODEC_AOM_DECODE=1)
    elseif(AVIF_CODEC_AOM_ENCODE)
        message(STATUS "libavif: Codec enabled: aom (encode only)")
        set(AVIF_CODEC_DEFINITIONS ${AVIF_CODEC_DEFINITIONS} -DAVIF_CODEC_AOM_ENCODE=1)
    elseif(AVIF_CODEC_AOM_DECODE)
        message(STATUS "libavif: Codec enabled: aom (decode only)")
        set(AVIF_CODEC_DEFINITIONS ${AVIF_CODEC_DEFINITIONS} -DAVIF_CODEC_AOM_DECODE=1)
    else()
        message(FATAL_ERROR "libavif: AVIF_CODEC_AOM is on, but both AVIF_CODEC_AOM_ENCODE and AVIF_CODEC_AOM_DECODE are off. Disable AVIF_CODEC_AOM to disable both parts of the codec.")
    endif()
    set(AVIF_SRCS ${AVIF_SRCS}
        src/codec_aom.c
    )
    if(AVIF_LOCAL_AOM)
        set(LIB_FILENAME "${CMAKE_CURRENT_SOURCE_DIR}/ext/aom/build.libavif/${CMAKE_STATIC_LIBRARY_PREFIX}aom${CMAKE_STATIC_LIBRARY_SUFFIX}")
        if(NOT EXISTS "${LIB_FILENAME}")
            message(FATAL_ERROR "libavif: ${LIB_FILENAME} is missing, bailing out")
        endif()

        set(AVIF_CODEC_INCLUDES ${AVIF_CODEC_INCLUDES}
            "${CMAKE_CURRENT_SOURCE_DIR}/ext/aom"
        )
        set(AVIF_CODEC_LIBRARIES ${AVIF_CODEC_LIBRARIES} ${LIB_FILENAME})
    else()
        # Check to see if aom is independently being built by the outer CMake project
        if(NOT TARGET aom)
            find_package(aom REQUIRED)
            set(AVIF_CODEC_INCLUDES ${AVIF_CODEC_INCLUDES} ${AOM_INCLUDE_DIR})
        endif()
        set(AVIF_CODEC_LIBRARIES ${AVIF_CODEC_LIBRARIES} ${AOM_LIBRARY})
    endif()
endif()

if(NOT AVIF_CODEC_AOM AND NOT AVIF_CODEC_DAV1D AND NOT AVIF_CODEC_LIBGAV1)
    message(WARNING "libavif: No decoding library is enabled.")
endif()

add_library(avif ${AVIF_SRCS})
set_target_properties(avif
                      PROPERTIES
                          VERSION ${LIBRARY_VERSION}
                          SOVERSION ${LIBRARY_SOVERSION}
                          C_VISIBILITY_PRESET hidden)
target_compile_definitions(avif
                           PRIVATE ${AVIF_PLATFORM_DEFINITIONS} ${AVIF_CODEC_DEFINITIONS})
target_link_libraries(avif
                      PRIVATE ${AVIF_CODEC_LIBRARIES} ${AVIF_PLATFORM_LIBRARIES})
target_include_directories(avif
                           PUBLIC $<BUILD_INTERFACE:${libavif_SOURCE_DIR}/include>
                                  $<INSTALL_INTERFACE:include>
                           PRIVATE ${AVIF_PLATFORM_INCLUDES} ${AVIF_CODEC_INCLUDES})
set(AVIF_PKG_CONFIG_EXTRA_CFLAGS "")
if(BUILD_SHARED_LIBS)
    target_compile_definitions(avif PUBLIC AVIF_DLL
                                    PRIVATE AVIF_BUILDING_SHARED_LIBS)
    set(AVIF_PKG_CONFIG_EXTRA_CFLAGS " -DAVIF_DLL")
    if(AVIF_LOCAL_LIBGAV1)
        set_target_properties(avif PROPERTIES LINKER_LANGUAGE "CXX")
    endif()
endif()

option(AVIF_BUILD_EXAMPLES "Build avif Examples." OFF)
if(AVIF_BUILD_EXAMPLES)
    set(AVIF_EXAMPLES
        avif_example_decode_memory
        avif_example_decode_file
        avif_example_decode_streaming
        avif_example_encode
    )

    foreach(EXAMPLE ${AVIF_EXAMPLES})
        add_executable(${EXAMPLE} examples/${EXAMPLE}.c)
        if(AVIF_LOCAL_LIBGAV1)
            set_target_properties(${EXAMPLE} PROPERTIES LINKER_LANGUAGE "CXX")
        endif()
        target_link_libraries(${EXAMPLE} avif ${AVIF_PLATFORM_LIBRARIES})
    endforeach()
endif()

if(CMAKE_SKIP_INSTALL_RULES)
    set(SKIP_INSTALL_ALL TRUE)
endif()

if(NOT SKIP_INSTALL_ALL)
    include(GNUInstallDirs)
endif()

option(AVIF_BUILD_APPS "Build avif apps." OFF)
if(AVIF_BUILD_APPS)
    find_package(ZLIB REQUIRED)
    find_package(PNG REQUIRED)
    find_package(JPEG REQUIRED)

    add_executable(avifenc
        apps/avifenc.c

        apps/shared/avifjpeg.c
        apps/shared/iccjpeg.c
        apps/shared/avifpng.c
        apps/shared/avifutil.c
        apps/shared/y4m.c
    )
    if(AVIF_LOCAL_LIBGAV1)
        set_target_properties(avifenc PROPERTIES LINKER_LANGUAGE "CXX")
    endif()
    target_link_libraries(avifenc avif ${AVIF_PLATFORM_LIBRARIES} ${PNG_LIBRARY} ${ZLIB_LIBRARY} ${JPEG_LIBRARY})
    target_include_directories(avifenc
                               PRIVATE
                                   $<TARGET_PROPERTY:avif,INTERFACE_INCLUDE_DIRECTORIES>
                                   ${CMAKE_CURRENT_SOURCE_DIR}/apps/shared
                                   ${PNG_PNG_INCLUDE_DIR}
                                   ${JPEG_INCLUDE_DIR})
    add_executable(avifdec
        apps/avifdec.c

        apps/shared/avifjpeg.c
        apps/shared/iccjpeg.c
        apps/shared/avifpng.c
        apps/shared/avifutil.c
        apps/shared/y4m.c
    )
    if(AVIF_LOCAL_LIBGAV1)
        set_target_properties(avifdec PROPERTIES LINKER_LANGUAGE "CXX")
    endif()
    target_link_libraries(avifdec avif ${AVIF_PLATFORM_LIBRARIES} ${PNG_LIBRARY} ${ZLIB_LIBRARY} ${JPEG_LIBRARY})
    target_include_directories(avifdec
                               PRIVATE
                                   $<TARGET_PROPERTY:avif,INTERFACE_INCLUDE_DIRECTORIES>
                                   ${CMAKE_CURRENT_SOURCE_DIR}/apps/shared
                                   ${PNG_PNG_INCLUDE_DIR}
                                   ${JPEG_INCLUDE_DIR})

    if(NOT SKIP_INSTALL_APPS AND NOT SKIP_INSTALL_ALL)
        install(TARGETS avifenc avifdec
            RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
            ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
            LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
        )
    endif()
endif()

option(AVIF_BUILD_TESTS "Build avif tests." OFF)
if(AVIF_BUILD_TESTS)
    add_executable(aviftest
        apps/shared/y4m.c
        tests/aviftest.c
        tests/cJSON.c
        tests/compare.c
        tests/testcase.c
    )
    if(AVIF_LOCAL_LIBGAV1)
        set_target_properties(aviftest PROPERTIES LINKER_LANGUAGE "CXX")
    endif()
    target_link_libraries(aviftest avif ${AVIF_PLATFORM_LIBRARIES})
    target_include_directories(aviftest PRIVATE apps/shared)

    add_executable(avifyuv
        tests/avifyuv.c
    )
    if(AVIF_LOCAL_LIBGAV1)
        set_target_properties(avifyuv PROPERTIES LINKER_LANGUAGE "CXX")
    endif()
    target_link_libraries(avifyuv avif ${AVIF_PLATFORM_LIBRARIES})

    add_custom_target(avif_test_all
        COMMAND $<TARGET_FILE:aviftest> ${CMAKE_CURRENT_SOURCE_DIR}/tests/data
        DEPENDS aviftest
    )

    if(AVIF_ENABLE_COVERAGE)
        add_custom_target(avif_coverage
            COMMAND LLVM_PROFILE_FILE=${CMAKE_BINARY_DIR}/aviftest.profraw $<TARGET_FILE:aviftest> ${CMAKE_CURRENT_SOURCE_DIR}/tests/data --io-only
            COMMAND ${XCRUN} llvm-profdata merge -sparse ${CMAKE_BINARY_DIR}/aviftest.profraw -o ${CMAKE_BINARY_DIR}/aviftest.profdata
            COMMAND cmake -E make_directory ${CMAKE_BINARY_DIR}/coverage
            COMMAND ${XCRUN} llvm-cov show $<TARGET_FILE:aviftest> -instr-profile=${CMAKE_BINARY_DIR}/aviftest.profdata -project-title=libavif --format html -output-dir=${CMAKE_BINARY_DIR}/coverage
            COMMAND echo Coverage report here: ${CMAKE_BINARY_DIR}/coverage/index.html
            DEPENDS aviftest
        )
    endif()
endif()

configure_file(libavif.pc.cmake ${CMAKE_CURRENT_BINARY_DIR}/libavif.pc @ONLY)

if(NOT SKIP_INSTALL_LIBRARIES AND NOT SKIP_INSTALL_ALL)
    install(TARGETS avif
        EXPORT ${PROJECT_NAME}-config
        RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
        ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
        LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    )

    if (BUILD_SHARED_LIBS)
        install(EXPORT ${PROJECT_NAME}-config
                DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME})

        include(CMakePackageConfigHelpers)
        write_basic_package_version_file(${PROJECT_NAME}-config-version.cmake
                                         VERSION ${PROJECT_VERSION}
                                         COMPATIBILITY SameMajorVersion)
        install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}-config-version.cmake
                DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME})
    endif()

    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/libavif.pc
            DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig)
endif()
if(NOT SKIP_INSTALL_HEADERS AND NOT SKIP_INSTALL_ALL)
    install(FILES include/avif/avif.h
        DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/avif"
    )
endif()

# ---------------------------------------------------------------------------------------
# Win32 (Visual Studio) fixups

macro(avif_set_folder_safe target folder)
    if(TARGET ${target})
        set_target_properties(${target} PROPERTIES FOLDER ${folder})
    endif()
endmacro()

macro(avif_exclude_safe target)
    if(TARGET ${target})
        set_target_properties(${target} PROPERTIES EXCLUDE_FROM_DEFAULT_BUILD True)
    endif()
endmacro()

if(WIN32)
    set_property(GLOBAL PROPERTY USE_FOLDERS ON)

    avif_set_folder_safe(avif "ext/avif")
    if(AVIF_BUILD_EXAMPLES)
        foreach(EXAMPLE ${AVIF_EXAMPLES})
            avif_set_folder_safe(${EXAMPLE} "ext/avif/examples")
        endforeach()
    endif()
    if(AVIF_LOCAL_ZLIBPNG)
        avif_set_folder_safe(example "ext/zlibpng")
        avif_set_folder_safe(genfiles "ext/zlibpng")
        avif_set_folder_safe(minigzip "ext/zlibpng")
        avif_set_folder_safe(png_static "ext/zlibpng")
        avif_set_folder_safe(zlib "ext/zlibpng")
        avif_set_folder_safe(zlibstatic "ext/zlibpng")

        # Don't bother building these targets
        avif_exclude_safe(example)
        avif_exclude_safe(genfiles)
        avif_exclude_safe(minigzip)
    endif()
    if(AVIF_LOCAL_JPEG)
        avif_set_folder_safe(jpeg "ext/libjpeg")
    endif()
endif()

add_subdirectory(contrib)
