# SPDX-License-Identifier: GPL-2.0-or-later

cmake_minimum_required(VERSION 3.20)
project(AudioViz CXX)

# Prebuilt third-party static libraries. The same layout is used by the
# Windows PowerShell builder and the Unix/Android CMake builder:
#   <workspace>/third_party/dist/include/fftw3.h, sndfile.h
#   <workspace>/third_party/dist/lib/fftw3(.lib|.a), sndfile(.lib|.a), ...
set(AUDIOVIZ_THIRDPARTY "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/dist" CACHE PATH
    "Directory containing the AudioViz third-party include/ and lib/ folders")
set(AUDIOVIZ_THIRDPARTY_INCLUDE "${AUDIOVIZ_THIRDPARTY}/include")
set(AUDIOVIZ_THIRDPARTY_LIB "${AUDIOVIZ_THIRDPARTY}/lib")

find_path(AUDIOVIZ_FFTW_INCLUDE_DIR NAMES fftw3.h
    HINTS "${AUDIOVIZ_THIRDPARTY_INCLUDE}"
    NO_DEFAULT_PATH NO_CMAKE_FIND_ROOT_PATH)
find_path(AUDIOVIZ_SNDFILE_INCLUDE_DIR NAMES sndfile.h
    HINTS "${AUDIOVIZ_THIRDPARTY_INCLUDE}"
    NO_DEFAULT_PATH NO_CMAKE_FIND_ROOT_PATH)

find_library(AUDIOVIZ_FFTW_LIBRARY NAMES fftw3
    HINTS "${AUDIOVIZ_THIRDPARTY_LIB}"
    NO_DEFAULT_PATH NO_CMAKE_FIND_ROOT_PATH)
find_library(AUDIOVIZ_SNDFILE_LIBRARY NAMES sndfile
    HINTS "${AUDIOVIZ_THIRDPARTY_LIB}"
    NO_DEFAULT_PATH NO_CMAKE_FIND_ROOT_PATH)
find_library(AUDIOVIZ_VORBISFILE_LIBRARY NAMES vorbisfile
    HINTS "${AUDIOVIZ_THIRDPARTY_LIB}"
    NO_DEFAULT_PATH NO_CMAKE_FIND_ROOT_PATH)
find_library(AUDIOVIZ_VORBISENC_LIBRARY NAMES vorbisenc
    HINTS "${AUDIOVIZ_THIRDPARTY_LIB}"
    NO_DEFAULT_PATH NO_CMAKE_FIND_ROOT_PATH)
find_library(AUDIOVIZ_VORBIS_LIBRARY NAMES vorbis
    HINTS "${AUDIOVIZ_THIRDPARTY_LIB}"
    NO_DEFAULT_PATH NO_CMAKE_FIND_ROOT_PATH)
find_library(AUDIOVIZ_OGG_LIBRARY NAMES ogg
    HINTS "${AUDIOVIZ_THIRDPARTY_LIB}"
    NO_DEFAULT_PATH NO_CMAKE_FIND_ROOT_PATH)
foreach(_required_path IN ITEMS
    AUDIOVIZ_FFTW_INCLUDE_DIR
    AUDIOVIZ_SNDFILE_INCLUDE_DIR
    AUDIOVIZ_FFTW_LIBRARY
    AUDIOVIZ_SNDFILE_LIBRARY
    AUDIOVIZ_VORBISFILE_LIBRARY
    AUDIOVIZ_VORBISENC_LIBRARY
    AUDIOVIZ_VORBIS_LIBRARY
    AUDIOVIZ_OGG_LIBRARY)
    if(NOT ${_required_path})
        message(FATAL_ERROR "AudioViz dependency not found: ${_required_path}. Expected under ${AUDIOVIZ_THIRDPARTY}")
    endif()
endforeach()

# Android compiles the JNI bridge; every other platform compiles the plain source.
if(ANDROID)
    message("Building AudioViz for Android (JNI bridge)")
    add_library(AudioViz SHARED "native-lib.cpp")
else()
    message("Building AudioViz native extension")
    add_library(AudioViz SHARED "AudioViz.cpp")
endif()

if (CMAKE_VERSION VERSION_GREATER 3.12)
  set_property(TARGET AudioViz PROPERTY CXX_STANDARD 20)
endif()

if(MSVC)
  target_compile_options(AudioViz PRIVATE /W3 /utf-8)
endif()

target_include_directories(AudioViz PRIVATE
    "${AUDIOVIZ_FFTW_INCLUDE_DIR}"
    "${AUDIOVIZ_SNDFILE_INCLUDE_DIR}")
target_link_libraries(AudioViz PRIVATE
    "${AUDIOVIZ_FFTW_LIBRARY}"
    "${AUDIOVIZ_SNDFILE_LIBRARY}"
    "${AUDIOVIZ_VORBISFILE_LIBRARY}"
    "${AUDIOVIZ_VORBISENC_LIBRARY}"
    "${AUDIOVIZ_VORBIS_LIBRARY}"
    "${AUDIOVIZ_OGG_LIBRARY}")

if(UNIX AND NOT APPLE AND NOT ANDROID)
    target_link_libraries(AudioViz PRIVATE m dl)
endif()
