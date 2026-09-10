#!/bin/bash
# =====================================================================
# Michiko Kernel — CI Build Script (Non-interactive)
# Compatible with GitHub Actions / headless environments
# Created by Michikoextv2
# =====================================================================

set -euo pipefail

# -------------------------------------------------------
# Paths — resolved relative to the kernel source root
# -------------------------------------------------------
KERNEL_DIR="$(pwd)"
OUT_DIR="$KERNEL_DIR/out"
CLANG_DIR="${CLANG_DIR:-$KERNEL_DIR/../foxe-clang/install}"
GCC32_DIR="${GCC32_DIR:-$KERNEL_DIR/../fox-gcc32}"
BUILD_LOG="$KERNEL_DIR/build.log"

ARCH="arm64"
DATE=$(TZ=Asia/Jakarta date +"%Y%m%d%H%M")

# -------------------------------------------------------
# Build environment
# -------------------------------------------------------
export USE_CCACHE=1
export KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST:-github-ci}"
export KBUILD_BUILD_USER="${KBUILD_BUILD_USER:-michiko}"
export PATH="$CLANG_DIR/bin:$GCC32_DIR/bin:$PATH"

# -------------------------------------------------------
# Toolchain validation
# -------------------------------------------------------
if [ ! -f "$CLANG_DIR/bin/clang" ]; then
    echo "ERROR: Clang not found at $CLANG_DIR/bin/clang"
    exit 1
fi

if [ ! -f "$CLANG_DIR/bin/ld.lld" ]; then
    echo "WARNING: ld.lld not found in toolchain, falling back to system lld"
fi

CLANG_VERSION=$("$CLANG_DIR/bin/clang" --version)
CLANG_VERSION="${CLANG_VERSION%%$'\n'*}"
CPU_CORES=$(nproc --all)

echo "======================================================"
echo " Michiko Kernel CI Build"
echo "======================================================"
echo " Toolchain : $CLANG_VERSION"
echo " GCC32 dir : $GCC32_DIR"
echo " CPU cores : $CPU_CORES"
echo " Arch      : $ARCH"
echo " Out dir   : $OUT_DIR"
echo " Build log : $BUILD_LOG"
echo "======================================================"

# -------------------------------------------------------
# Defconfig — surya_defconfig
# -------------------------------------------------------
DEFCONFIG="surya_defconfig"
CONFIG_FILE="$KERNEL_DIR/arch/arm64/configs/$DEFCONFIG"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: $CONFIG_FILE not found"
    exit 1
fi

echo "Using defconfig: $DEFCONFIG"

# -------------------------------------------------------
# Clean previous build
# -------------------------------------------------------
echo ""
echo "Cleaning previous build..."
make clean O="$OUT_DIR" &>/dev/null || true
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
rm -f "$BUILD_LOG"

# -------------------------------------------------------
# Generate .config
# -------------------------------------------------------
echo "Generating defconfig ($DEFCONFIG)..."
make O="$OUT_DIR" ARCH="$ARCH" "$DEFCONFIG" 2>&1 | tee -a "$BUILD_LOG"
DEFCONFIG_STATUS=${PIPESTATUS[0]}

if [ "$DEFCONFIG_STATUS" -ne 0 ]; then
    echo "ERROR: defconfig generation failed. Check $BUILD_LOG"
    exit 1
fi

# Polly
KCFLAGS="-mllvm -polly"

# -------------------------------------------------------
# Build kernel
# -------------------------------------------------------
echo ""
echo "Starting kernel build with $CPU_CORES threads..."
BUILD_START=$(date +%s)

make -j"$CPU_CORES" \
    O="$OUT_DIR" \
    ARCH="$ARCH" \
    CC="$CLANG_DIR/bin/clang" \
    LD="$CLANG_DIR/bin/ld.lld" \
    AR="$CLANG_DIR/bin/llvm-ar" \
    NM="$CLANG_DIR/bin/llvm-nm" \
    STRIP="$CLANG_DIR/bin/llvm-strip" \
    OBJCOPY="$CLANG_DIR/bin/llvm-objcopy" \
    OBJDUMP="$CLANG_DIR/bin/llvm-objdump" \
    READELF="$CLANG_DIR/bin/llvm-readelf" \
    LLVM=1 \
    LLVM_IAS=1 \
    CLANG_TRIPLE="aarch64-linux-gnu-" \
    CROSS_COMPILE="aarch64-linux-gnu-" \
    CROSS_COMPILE_ARM32="arm-eabi-" \
    ${KCFLAGS:+KCFLAGS="$KCFLAGS"} \
    2>&1 | tee -a "$BUILD_LOG"

BUILD_STATUS=${PIPESTATUS[0]}
BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - BUILD_START))
# -------------------------------------------------------
# Verify output
# -------------------------------------------------------
IMAGE="$OUT_DIR/arch/arm64/boot/Image.gz"
DTB="$OUT_DIR/arch/arm64/boot/dtb.img"
DTBO="$OUT_DIR/arch/arm64/boot/dtbo.img"

echo ""
echo "======================================================"
if [ -f "$IMAGE" ]; then
    echo "Build SUCCESS"
    echo "Image    : $IMAGE"
    echo "Duration : ${BUILD_TIME}s"
    [ -f "$DTB" ]  && echo "DTB      : $DTB"  || echo "WARNING  : dtb.img not found"
    [ -f "$DTBO" ] && echo "DTBO     : $DTBO" || echo "WARNING  : dtbo.img not found"
else
    echo "Build FAILED — Image.gz not found"
    echo "Duration : ${BUILD_TIME}s"
    echo "Check    : $BUILD_LOG"
    exit 1
fi
echo "======================================================"
