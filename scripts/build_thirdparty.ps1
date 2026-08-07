<#
.LICENSE
    SPDX-License-Identifier: GPL-2.0-or-later

.SYNOPSIS
    Build FFTW, libogg, libvorbis, and libsndfile as static libraries for the
    AudioViz extension.

.DESCRIPTION
    Produces:
        <workspace>/third_party/dist/include/fftw3.h, sndfile.h, ogg/, vorbis/
        <workspace>/third_party/dist/lib/fftw3.lib, sndfile.lib,
                     ogg.lib, vorbis.lib, vorbisenc.lib, vorbisfile.lib

    libsndfile is built with Ogg Vorbis enabled (external codecs), so the
    extension can decode .ogg files. The AudioViz fork of libsndfile relaxes
    the upstream requirement that FLAC/Opus be present too (see the
    "AudioViz local patch" comment in cmake/SndFileChecks.cmake).

    Run from a VS Developer PowerShell (or "x64 Native Tools Command Prompt"),
    or invoke it via VsDevCmd.bat (see README). CMake and Ninja are taken from
    PATH first and fall back to the copies bundled with Visual Studio.

.EXAMPLE
    powershell -File scripts/build_thirdparty.ps1
#>
[CmdletBinding()]
param(
    [string]$WorkspaceRoot = ''
)

$ErrorActionPreference = 'Stop'
if (-not $WorkspaceRoot) {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $WorkspaceRoot = Split-Path -Parent $scriptDir
}
$root = [System.IO.Path]::GetFullPath($WorkspaceRoot)

$fftwSrc = Join-Path $root 'fftw-3.3.11'
$sndfileSrc = Join-Path $root 'libsndfile'
$oggSrc = Join-Path $root 'libogg'
$vorbisSrc = Join-Path $root 'third_party\src\libvorbis-1.3.7'
$buildRoot = Join-Path $root 'third_party\build'
$dist = Join-Path $root 'third_party\dist'
$distInclude = Join-Path $root 'third_party\dist\include'
$distLib = Join-Path $root 'third_party\dist\lib'

foreach ($p in @($fftwSrc, $sndfileSrc, $oggSrc, $vorbisSrc)) {
    if (-not (Test-Path -LiteralPath $p)) { throw "Source directory not found: $p" }
}

# --- Locate CMake / Ninja (PATH first, then the VS-bundled copies) ----------
function Find-Tool([string]$Name, [string[]]$CandidateDirs) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($d in $CandidateDirs) {
        $p = Join-Path $d ($Name + '.exe')
        if (Test-Path -LiteralPath $p) { return $p }
    }
    throw "Could not find $Name.exe. Install CMake/Ninja or run from a VS developer shell."
}

$vsRoot = $env:ProgramFiles + '\Microsoft Visual Studio'
$cmakeDirs = @(
    "$vsRoot\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin",
    "$vsRoot\2022\Professional\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin",
    "$vsRoot\2022\Enterprise\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin",
    "$vsRoot\18\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin",
    "$vsRoot\18\Professional\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin",
    "$vsRoot\18\Enterprise\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin"
)
$ninjaDirs = $cmakeDirs | ForEach-Object { Split-Path $_ -Parent }

$cmake = Find-Tool 'cmake' $cmakeDirs
$ninja = Find-Tool 'ninja' $ninjaDirs
$ninjaDir = Split-Path $ninja -Parent

Write-Host "Using cmake : $cmake"
Write-Host "Using ninja : $ninja"

function Invoke-Cmake {
    param([string]$Source, [string]$Build, [string[]]$Defines)
    $args = @('-S', $Source, '-B', $Build, '-G', 'Ninja',
              "-DCMAKE_MAKE_PROGRAM=$ninja", '-DCMAKE_BUILD_TYPE=Release',
              '-DCMAKE_POSITION_INDEPENDENT_CODE=ON') + $Defines
    Write-Host "==> cmake configure: $($args -join ' ')"
    & $cmake @args
    if ($LASTEXITCODE -ne 0) { throw "cmake configure failed for $Source" }

    Write-Host "==> cmake build: $Build"
    & $cmake --build $Build
    if ($LASTEXITCODE -ne 0) { throw "cmake build failed for $Source" }
}

New-Item -ItemType Directory -Force -Path $distInclude, $distLib | Out-Null

# --- FFTW 3 (double precision, static, SSE2) --------------------------------
Write-Host ''
Write-Host '########## FFTW 3 ##########'
$fftwBuild = Join-Path $buildRoot 'fftw'
Invoke-Cmake -Source $fftwSrc -Build $fftwBuild -Defines @(
    '-DCMAKE_POLICY_VERSION_MINIMUM=3.5',
    '-DBUILD_SHARED_LIBS=OFF',
    '-DBUILD_TESTS=OFF',
    '-DENABLE_FLOAT=OFF',
    '-DENABLE_LONG_DOUBLE=OFF',
    '-DENABLE_QUAD_PRECISION=OFF',
    '-DENABLE_THREADS=OFF',
    '-DENABLE_OPENMP=OFF',
    '-DENABLE_SSE2=ON',
    '-DENABLE_AVX=OFF',
    '-DENABLE_AVX2=OFF'
)

$fftwLib = Get-ChildItem -Path $fftwBuild -Recurse -Filter 'fftw3.lib' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $fftwLib) { throw 'fftw3.lib was not produced by the FFTW build.' }
Copy-Item -LiteralPath $fftwLib.FullName -Destination (Join-Path $distLib 'fftw3.lib') -Force
Copy-Item -LiteralPath (Join-Path $fftwSrc 'api\fftw3.h') -Destination $distInclude -Force
Write-Host "FFTW OK: $($fftwLib.FullName)"

# --- libogg (static) ---------------------------------------------------------
Write-Host ''
Write-Host '########## libogg ##########'
$oggBuild = Join-Path $buildRoot 'ogg'
Invoke-Cmake -Source $oggSrc -Build $oggBuild -Defines @(
    '-DCMAKE_POLICY_VERSION_MINIMUM=3.5',
    '-DBUILD_SHARED_LIBS=OFF',
    '-DBUILD_TESTING=OFF'
)

$oggLib = Get-ChildItem -Path $oggBuild -Recurse -Filter 'ogg.lib' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $oggLib) { throw 'ogg.lib was not produced by the libogg build.' }
Copy-Item -LiteralPath $oggLib.FullName -Destination (Join-Path $distLib 'ogg.lib') -Force
New-Item -ItemType Directory -Force -Path (Join-Path $distInclude 'ogg') | Out-Null
Copy-Item -Path (Join-Path $oggSrc 'include\ogg\*.h') -Destination (Join-Path $distInclude 'ogg') -Force
Write-Host "libogg OK: $($oggLib.FullName)"

# --- libvorbis (static) ------------------------------------------------------
Write-Host ''
Write-Host '########## libvorbis ##########'
$vorbisBuild = Join-Path $buildRoot 'vorbis'
Invoke-Cmake -Source $vorbisSrc -Build $vorbisBuild -Defines @(
    '-DCMAKE_POLICY_VERSION_MINIMUM=3.5',
    '-DBUILD_SHARED_LIBS=OFF',
    '-DBUILD_TESTING=OFF',
    "-DOGG_ROOT=$dist",
    "-DOGG_INCLUDE_DIR=$distInclude",
    "-DOGG_LIBRARY=$(Join-Path $distLib 'ogg.lib')"
)

$vorbisLibs = Get-ChildItem -Path $vorbisBuild -Recurse -Include 'vorbis.lib','vorbisenc.lib','vorbisfile.lib' -ErrorAction SilentlyContinue
foreach ($name in @('vorbis.lib', 'vorbisenc.lib', 'vorbisfile.lib')) {
    $lib = $vorbisLibs | Where-Object { $_.Name -eq $name } | Select-Object -First 1
    if (-not $lib) { throw "$name was not produced by the libvorbis build." }
    Copy-Item -LiteralPath $lib.FullName -Destination (Join-Path $distLib $name) -Force
}
New-Item -ItemType Directory -Force -Path (Join-Path $distInclude 'vorbis') | Out-Null
Copy-Item -Path (Join-Path $vorbisSrc 'include\vorbis\*.h') -Destination (Join-Path $distInclude 'vorbis') -Force
Write-Host "libvorbis OK: $(Join-Path $distLib 'vorbis.lib')"

# --- libsndfile (static, Ogg Vorbis enabled) ---------------------------------
Write-Host ''
Write-Host '########## libsndfile ##########'
$sndBuild = Join-Path $buildRoot 'sndfile'
Invoke-Cmake -Source $sndfileSrc -Build $sndBuild -Defines @(
    '-DCMAKE_POLICY_VERSION_MINIMUM=3.5',
    '-DBUILD_SHARED_LIBS=OFF',
    '-DENABLE_EXTERNAL_LIBS=ON',
    "-DOGG_ROOT=$dist",
    "-DOGG_INCLUDE_DIR=$distInclude",
    "-DOGG_LIBRARY=$(Join-Path $distLib 'ogg.lib')",
    "-DVORBIS_ROOT=$dist",
    "-DVorbis_ROOT=$dist",
    "-DVorbis_Vorbis_INCLUDE_DIR=$distInclude",
    "-DVorbis_Vorbis_LIBRARY=$(Join-Path $distLib 'vorbis.lib')",
    "-DVorbis_Enc_INCLUDE_DIR=$distInclude",
    "-DVorbis_Enc_LIBRARY=$(Join-Path $distLib 'vorbisenc.lib')",
    "-DVorbis_File_INCLUDE_DIR=$distInclude",
    "-DVorbis_File_LIBRARY=$(Join-Path $distLib 'vorbisfile.lib')",
    '-DENABLE_MPEG=OFF',
    '-DBUILD_PROGRAMS=OFF',
    '-DBUILD_EXAMPLES=OFF',
    '-DBUILD_TESTING=OFF',
    '-DENABLE_CPACK=OFF',
    '-DENABLE_PACKAGE_CONFIG=OFF',
    '-DINSTALL_PKGCONFIG_MODULE=OFF'
)

$sndLib = Get-ChildItem -Path $sndBuild -Recurse -Filter 'sndfile.lib' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $sndLib) { throw 'sndfile.lib was not produced by the libsndfile build.' }
Copy-Item -LiteralPath $sndLib.FullName -Destination (Join-Path $distLib 'sndfile.lib') -Force
Copy-Item -LiteralPath (Join-Path $sndfileSrc 'include\sndfile.h') -Destination $distInclude -Force
Copy-Item -LiteralPath (Join-Path $sndfileSrc 'include\sndfile.hh') -Destination $distInclude -Force -ErrorAction SilentlyContinue
Write-Host "libsndfile OK: $($sndLib.FullName)"

Write-Host ''
Write-Host "Third-party static libraries installed to: $(Join-Path $root 'third_party\dist')"
