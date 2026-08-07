#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

# Build the static dependencies used by AudioViz. This is intentionally kept
# source-based so Linux, macOS, iOS, and Android do not depend on shared
# libraries installed on the runner.

usage() {
    cat <<'EOF'
Usage: build_thirdparty.sh [options]

Options:
  --root DIR              Repository root (default: script parent)
  --dist DIR              Output dist directory (default: ROOT/third_party/dist)
  --build DIR             Build directory (default: ROOT/third_party/build/unix)
  --toolchain FILE        CMake toolchain file, for Android/iOS builds
  --android-abi ABI       Android ABI (also sets Android mode)
  --android-platform API  Android API level (default: 19)
  --cmake-arg ARG         Additional CMake cache entry without the -D prefix
  -h, --help              Show this help
EOF
}

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist="${root}/third_party/dist"
build_root="${root}/third_party/build/unix"
toolchain=""
android_abi=""
android_platform="19"
cmake_args=()

while (($#)); do
    case "$1" in
        --root) root="$(cd "$2" && pwd)"; shift 2 ;;
        --dist) dist="$(cd "$2" && pwd)"; shift 2 ;;
        --build) build_root="$(cd "$2" 2>/dev/null || { mkdir -p "$2"; cd "$2"; } && pwd)"; shift 2 ;;
        --toolchain) toolchain="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"; shift 2 ;;
        --android-abi) android_abi="$2"; shift 2 ;;
        --android-platform) android_platform="$2"; shift 2 ;;
        --cmake-arg) cmake_args+=("-D$2"); shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

cmake_bin="${CMAKE:-cmake}"
ninja_bin="${NINJA:-ninja}"

if ! command -v "$cmake_bin" >/dev/null 2>&1; then
    echo "cmake was not found" >&2
    exit 1
fi
if ! command -v "$ninja_bin" >/dev/null 2>&1; then
    echo "ninja was not found" >&2
    exit 1
fi

fftw_src="${root}/fftw-3.3.11"
ogg_src="${root}/libogg"
vorbis_src="${root}/third_party/src/libvorbis-1.3.7"
sndfile_src="${root}/libsndfile"
libsndfile_patch_script="${root}/scripts/patch_libsndfile.cmake"

"${cmake_bin}" "-DSNDFILE_SOURCE=${sndfile_src}" -P "${libsndfile_patch_script}"

mkdir -p "${dist}/include" "${dist}/lib" "${build_root}"

common_args=(
    -G Ninja
    "-DCMAKE_MAKE_PROGRAM=${ninja_bin}"
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON
    -DBUILD_SHARED_LIBS=OFF
)

if [[ -n "${toolchain}" ]]; then
    common_args+=("-DCMAKE_TOOLCHAIN_FILE=${toolchain}")
fi
if [[ -n "${android_abi}" ]]; then
    common_args+=("-DANDROID_ABI=${android_abi}" "-DANDROID_PLATFORM=android-${android_platform}")
fi

configure_build_install() {
    local name="$1"
    local source="$2"
    shift 2
    local build="${build_root}/${name}"
    rm -rf "${build}"
    mkdir -p "${build}"
    "${cmake_bin}" -S "${source}" -B "${build}" "${common_args[@]}" "$@" \
        "${cmake_args[@]}" \
        -DCMAKE_INSTALL_PREFIX="${dist}"
    "${cmake_bin}" --build "${build}" --parallel
    "${cmake_bin}" --install "${build}"
}

echo "==> Building FFTW"
configure_build_install fftw "${fftw_src}" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DBUILD_TESTS=OFF \
    -DENABLE_FLOAT=OFF \
    -DENABLE_LONG_DOUBLE=OFF \
    -DENABLE_QUAD_PRECISION=OFF \
    -DENABLE_THREADS=OFF \
    -DENABLE_OPENMP=OFF \
    -DENABLE_SSE2=ON \
    -DENABLE_AVX=OFF \
    -DENABLE_AVX2=OFF

echo "==> Building libogg"
configure_build_install ogg "${ogg_src}" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DBUILD_TESTING=OFF \
    -DINSTALL_DOCS=OFF \
    -DINSTALL_PKG_CONFIG_MODULE=OFF \
    -DINSTALL_CMAKE_PACKAGE_MODULE=OFF

ogg_include="${dist}/include"
ogg_lib="${dist}/lib/$( [[ "${OSTYPE:-}" == msys* ]] && echo ogg.lib || echo libogg.a )"

echo "==> Building libvorbis"
configure_build_install vorbis "${vorbis_src}" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DBUILD_TESTING=OFF \
    -DINSTALL_CMAKE_PACKAGE_MODULE=OFF \
    -DINSTALL_PKG_CONFIG_MODULE=OFF \
    -DOGG_INCLUDE_DIR="${ogg_include}" \
    -DOGG_LIBRARY="${ogg_lib}"

echo "==> Building libsndfile"
configure_build_install sndfile "${sndfile_src}" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DBUILD_TESTING=OFF \
    -DBUILD_PROGRAMS=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DENABLE_CPACK=OFF \
    -DENABLE_PACKAGE_CONFIG=OFF \
    -DINSTALL_PKGCONFIG_MODULE=OFF \
    -DENABLE_EXTERNAL_LIBS=ON \
    -DENABLE_MPEG=OFF \
    -DOGG_INCLUDE_DIR="${dist}/include" \
    -DOGG_LIBRARY="${ogg_lib}" \
    -DVORBIS_ROOT="${dist}" \
    -DVorbis_ROOT="${dist}" \
    -DVorbis_Vorbis_INCLUDE_DIR="${dist}/include" \
    -DVorbis_Vorbis_LIBRARY="${dist}/lib/$( [[ "${OSTYPE:-}" == msys* ]] && echo vorbis.lib || echo libvorbis.a )" \
    -DVorbis_Enc_INCLUDE_DIR="${dist}/include" \
    -DVorbis_Enc_LIBRARY="${dist}/lib/$( [[ "${OSTYPE:-}" == msys* ]] && echo vorbisenc.lib || echo libvorbisenc.a )" \
    -DVorbis_File_INCLUDE_DIR="${dist}/include" \
    -DVorbis_File_LIBRARY="${dist}/lib/$( [[ "${OSTYPE:-}" == msys* ]] && echo vorbisfile.lib || echo libvorbisfile.a )"

cp "${fftw_src}/api/fftw3.h" "${dist}/include/fftw3.h"
cp "${sndfile_src}/include/sndfile.h" "${dist}/include/sndfile.h"

echo "==> Third-party dependencies installed in ${dist}"
