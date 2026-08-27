#!/bin/bash
# =====================================================================
# 💫 Build Script — HYBRID MODE
# 🔧 Created by Michikoextv2
# =====================================================================

# 🎨 Warna
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
RESET='\033[0m'
BOLD='\033[1m'

# =====================================================================
# 📂 Direktori & Variabel Utama
# =====================================================================
KERNEL_DIR="$(pwd)"
OUT_DIR="$KERNEL_DIR/out"
CLANG_DIR="$(realpath "$KERNEL_DIR/../clang/install")"
GCC32_DIR="$(realpath "$KERNEL_DIR/../gcc32/gcc-arm")"
AK3_REPO="https://github.com/Michikoextv2/AK3-Surya.git"
AK3_BRANCH="screepy"
AK3_DIR="$KERNEL_DIR/AnyKernel3"
ARCH="arm64"
BUILD_LOG="$KERNEL_DIR/build.log"
DATE="$(date +"%Y-%m-%d_%H-%M")"

# =====================================================================
# 🧠 Info Sistem
# =====================================================================
CPU_CORES=$(nproc --all)
HOST_OS=$(uname -o)
HOST_KERNEL=$(uname -r)
HOST_CPU=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | sed 's/^ //')

clear
echo -e "${MAGENTA}${BOLD}=============================================================="
echo -e "  💫 MICHIKO Build Script — FINAL HYBRID MODE"
echo -e "==============================================================${RESET}"
echo -e "${CYAN}👤 Dibuat oleh   :${RESET} ${GREEN}Michikoextv2${RESET}"
echo -e "${YELLOW}🧠 CPU           :${RESET} ${GREEN}${HOST_CPU}${RESET}"
echo -e "${YELLOW}💻 Host          :${RESET} ${GREEN}${HOST_OS} (${HOST_KERNEL})${RESET}"
echo -e "${YELLOW}🧵 CPU Cores     :${RESET} ${GREEN}${CPU_CORES}${RESET}"
echo -e "${YELLOW}📄 Build Log     :${RESET} ${GREEN}${BUILD_LOG}${RESET}"
echo -e "${MAGENTA}==============================================================${RESET}\n"

# =====================================================================
# 🔍 Cek Toolchain
# =====================================================================
if [ ! -f "$CLANG_DIR/bin/clang" ]; then
    echo -e "${RED}❌ Clang tidak ditemukan di: $CLANG_DIR${RESET}"
    echo -e "${YELLOW}   Pastikan folder 'clang/install/' ada di direktori induk.${RESET}"
    exit 1
fi

if [ ! -f "$CLANG_DIR/bin/ld.lld" ]; then
    echo -e "${YELLOW}⚠️  ld.lld tidak ditemukan di Clang, menggunakan system lld...${RESET}"
    sudo apt install -y lld &>/dev/null
fi

if [ ! -d "$GCC32_DIR/bin" ]; then
    echo -e "${RED}❌ GCC ARM32 tidak ditemukan di: $GCC32_DIR${RESET}"
    echo -e "${YELLOW}   Pastikan folder 'gcc32/gcc-arm/bin/' ada dan berisi arm-eabi-*.${RESET}"
    exit 1
fi

# Tampilkan versi Clang setelah PATH diset
export PATH="$CLANG_DIR/bin:$GCC32_DIR/bin:$PATH"
CLANG_VERSION=$("$CLANG_DIR/bin/clang" --version | head -n 1)
echo -e "${YELLOW}🧰 Toolchain     :${RESET} ${GREEN}${CLANG_VERSION}${RESET}\n"

# =====================================================================
# 🌿 Environment Variables
# =====================================================================
export USE_CCACHE=1
export KBUILD_BUILD_HOST="xyz"
export KBUILD_BUILD_USER="standalone"

# =====================================================================
# 🔍 Auto Detect Defconfig
# =====================================================================
CONFIG_PATH="$KERNEL_DIR/arch/arm64/configs"
mapfile -t DEFCONFIGS < <(ls "$CONFIG_PATH" | grep -E "defconfig$")

if [ ${#DEFCONFIGS[@]} -eq 0 ]; then
    echo -e "${RED}❌ Tidak ada defconfig ditemukan di $CONFIG_PATH${RESET}"
    exit 1
elif [ ${#DEFCONFIGS[@]} -eq 1 ]; then
    DEFCONFIG="${DEFCONFIGS[0]}"
    echo -e "${GREEN}✅ Ditemukan satu defconfig: ${DEFCONFIG}${RESET}"
else
    echo -e "${YELLOW}📋 Pilih defconfig yang ingin digunakan:${RESET}"
    select DEFCONFIG in "${DEFCONFIGS[@]}"; do
        if [[ -n "$DEFCONFIG" ]]; then
            echo -e "${GREEN}✅ Menggunakan defconfig: $DEFCONFIG${RESET}"
            break
        else
            echo -e "${RED}❌ Pilihan tidak valid, coba lagi.${RESET}"
        fi
    done
fi

# =====================================================================
# 🗑️ Hapus AnyKernel3 Lama (jika ada)
# =====================================================================
if [ -d "$AK3_DIR" ]; then
    echo -e "\n${YELLOW}🗑️  Menghapus AnyKernel3 lama...${RESET}"
    rm -rf "$AK3_DIR"
fi

# =====================================================================
# 🧹 Bersihkan Build Lama
# =====================================================================
echo -e "${CYAN}🧹 Membersihkan build lama...${RESET}"
make -C "$KERNEL_DIR" O="$OUT_DIR" clean &>/dev/null
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
rm -f "$BUILD_LOG"

# =====================================================================
# ⚙️ Generate Defconfig
# =====================================================================
echo -e "${YELLOW}⚙️  Menghasilkan defconfig (${DEFCONFIG})...${RESET}"
make -C "$KERNEL_DIR" O="$OUT_DIR" ARCH="$ARCH" "$DEFCONFIG" 2>&1 | tee -a "$BUILD_LOG"
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo -e "${RED}❌ Gagal generate defconfig. Pastikan file '${DEFCONFIG}' ada.${RESET}"
    exit 1
fi

# =====================================================================
# 🧭 Menuconfig Opsional
# =====================================================================
read -rp "$(echo -e "${MAGENTA}🧭 Ingin buka menuconfig sebelum build? (y/n): ${RESET}")" menu
[[ "$menu" =~ ^[Yy]$ ]] && make -C "$KERNEL_DIR" O="$OUT_DIR" ARCH="$ARCH" menuconfig

# =====================================================================
# 🔥 Pilih Level Optimasi Polly (FoxeClang)
# =====================================================================
echo -e "${YELLOW}🔥 Pilih level optimasi Polly:${RESET}"
echo -e "  ${CYAN}1)${RESET} Tanpa Polly   — Build standar"
echo -e "  ${CYAN}2)${RESET} Basic Polly   — Aman, rekomendasi daily build"
echo -e "  ${CYAN}3)${RESET} Medium Polly  — Tambah vectorization"
echo -e "  ${CYAN}4)${RESET} Full Polly    — Paling agresif, test dulu"
read -rp "$(echo -e "${MAGENTA}Pilih (1-4) [default: 2]: ${RESET}")" polly_choice

case "$polly_choice" in
    1) KCFLAGS=""
       echo -e "${GREEN}✅ Tanpa Polly${RESET}" ;;
    3) KCFLAGS="-mllvm -polly -mllvm -polly-vectorizer=stripmine"
       echo -e "${GREEN}✅ Medium Polly aktif${RESET}" ;;
    4) KCFLAGS="-mllvm -polly -mllvm -polly-vectorizer=stripmine -mllvm -polly-parallel"
       echo -e "${YELLOW}⚠️  Full Polly aktif — pastikan kernel sudah stabil${RESET}" ;;
    *) KCFLAGS="-mllvm -polly"
       echo -e "${GREEN}✅ Basic Polly aktif (default)${RESET}" ;;
esac

# =====================================================================
# ⏱️ Mulai Build
# =====================================================================
BUILD_START=$(date +%s)
echo -e "\n${CYAN}🚀 Memulai proses build kernel dengan ${CPU_CORES} core...${RESET}"

make -j"$CPU_CORES" \
    -C "$KERNEL_DIR" \
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

# =====================================================================
# ✅ Cek Hasil Build
# =====================================================================
IMAGE="$OUT_DIR/arch/arm64/boot/Image.gz"
DTB="$OUT_DIR/arch/arm64/boot/dtb.img"
DTBO="$OUT_DIR/arch/arm64/boot/dtbo.img"

echo -e "\n${CYAN}==============================================================${RESET}"

if [ "$BUILD_STATUS" -ne 0 ] || [ ! -f "$IMAGE" ]; then
    echo -e "${RED}❌ Build kernel gagal. Periksa log di: ${BUILD_LOG}${RESET}"
    echo -e "${YELLOW}⏱️  Durasi Build : ${BUILD_TIME}s${RESET}"
    echo -e "${CYAN}==============================================================${RESET}"
    exit 1
fi

echo -e "${GREEN}✅ Build kernel berhasil!${RESET}"
echo -e "${YELLOW}⏱️  Durasi Build : ${GREEN}${BUILD_TIME}s${RESET}"
echo -e "${YELLOW}📦 Image Output : ${BLUE}${IMAGE}${RESET}"

# =====================================================================
# 📦 Clone AnyKernel3 & Packing
# =====================================================================
echo -e "\n${CYAN}📥 Mengkloning AnyKernel3...${RESET}"
git clone --depth=1 "$AK3_REPO" -b "$AK3_BRANCH" "$AK3_DIR"

if [ ! -d "$AK3_DIR" ]; then
    echo -e "${RED}❌ Gagal mengkloning AnyKernel3 dari: $AK3_REPO${RESET}"
    exit 1
fi

# Buat folder kernels jika belum ada
mkdir -p "$AK3_DIR/kernels"

# Copy artifact ke AnyKernel3/kernels/
echo -e "${YELLOW}📂 Menyalin kernel artifacts ke AnyKernel3/kernels/...${RESET}"

cp "$IMAGE" "$AK3_DIR/kernels/"
echo -e "  ${GREEN}✅ Image.gz disalin${RESET}"

if [ -f "$DTB" ]; then
    cp "$DTB" "$AK3_DIR/kernels/"
    echo -e "  ${GREEN}✅ dtb.img disalin${RESET}"
else
    echo -e "  ${YELLOW}⚠️  dtb.img tidak ditemukan, dilewati${RESET}"
fi

if [ -f "$DTBO" ]; then
    cp "$DTBO" "$AK3_DIR/kernels/"
    echo -e "  ${GREEN}✅ dtbo.img disalin${RESET}"
else
    echo -e "  ${YELLOW}⚠️  dtbo.img tidak ditemukan, dilewati${RESET}"
fi

# Buat flashable ZIP
ZIP_NAME="Millenia-Kernel-${DATE}.zip"
cd "$AK3_DIR" || exit 1
zip -r9 "$KERNEL_DIR/$ZIP_NAME" . -x "*.git*" 2>&1 | tee -a "$BUILD_LOG"
cd "$KERNEL_DIR" || exit 1

echo -e "\n${CYAN}==============================================================${RESET}"
echo -e "${GREEN}💾 Flashable ZIP : ${BLUE}${KERNEL_DIR}/${ZIP_NAME}${RESET}"
echo -e "${CYAN}==============================================================${RESET}"
echo -e "${MAGENTA}${BOLD}🎉 Congratulations by Michikoextv2 — Build Selesai!${RESET}\n"
