param (
    [Parameter(Mandatory)] $architecture,
    [Parameter(Mandatory)] $vs
)

$ErrorActionPreference = "Stop"

if ($architecture -eq "x86") {
    $platform = "Win32"
} else {
    $platform = "x64"
}

if ($vs -eq "vs16") {
    $generator = "Visual Studio 16 2019"
} else {
}

Set-Location "ext"
git clone -b "v2.0.2" --depth 1 "https://aomedia.googlesource.com/aom"
Set-Location "aom"
New-Item "build.libavif" -ItemType "directory"
Set-Location "build.libavif"
cmake -G "$generator" -A "$platform" -DENABLE_DOCS=0 -DENABLE_EXAMPLES=0 -DENABLE_TESTDATA=0 -DENABLE_TESTS=0 -DENABLE_TOOLS=0 -DENABLE_NASM=1 -DENABLE_SSE2=0 -DENABLE_SSE3=0 DENABLE_SSSE3=0 -DENABLE_SSE4_1=0 -DENABLE_SSE4_2=0 -DENABLE_AVX=0 -DENABLE_AVX2=0 ..
msbuild "/t:Build" "/p:Configuration=Release" "/p:Platform=$platform" "AOM.sln"
xcopy "Release\*.lib" "."
Set-Location "..\..\.."

cmake "$generator" -A "$platform" -DAVIF_CODEC_AOM=1 -DAVIF_LOCAL_AOM=1 -DAVIF_ENABLE_WERROR=0 .
msbuild "/t:Build" "/p:Configuration=Release" "/p:Platform=$platform" "libavif.sln"
xcopy "Release\avif.dll" "winlibs\bin\*"
xcopy "include\avif\avif.h" "winlibs\include\avif\*"
xcopy "Release\avif.lib" "winlibs\lib\*"
