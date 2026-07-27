#!/bin/bash
# =====================================================================
# 💫 Build Script — HYBRID MODE
# 🔧 Created by Michikoextv2
# =====================================================================

# Set date kernel
DATE="$(TZ=Asia/Jakarta date +%Y%m%d%H%M)"

# 🎨 Warna
RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'
BLUE='\033[1;34m'; CYAN='\033[1;36m'; MAGENTA='\033[1;35m'
RESET='\033[0m'; BOLD='\033[1m'

# 📂 Variabel utama
KERNEL_DIR=$(pwd)
OUT_DIR="$KERNEL_DIR/out"
CLANG_DIR="$KERNEL_DIR/../neutron-clang"
GCC32_DIR="$KERNEL_DIR/../arm-linux-androideabi-4.9"
ARCH="arm64"
BUILD_LOG="$KERNEL_DIR/build.log"
DATE=$(date +"%Y-%m-%d_%H-%M")

# 🧠 Info sistem
CPU_CORES=$(nproc)
CLANG_VERSION=$($CLANG_DIR/bin/clang --version | head -n 1)
HOST_OS=$(uname -o)
HOST_KERNEL=$(uname -r)
HOST_CPU=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | sed 's/^ //')

clear
echo -e "${MAGENTA}${BOLD}=============================================================="
echo -e " 💫 MICHIKO Build Script — FINAL HYBRID MODE"
echo -e "==============================================================${RESET}"
echo -e "${CYAN}👤 Dibuat oleh:${RESET} ${GREEN}Michikoextv2${RESET}"
echo -e "${YELLOW}🧰 Toolchain:${RESET} ${GREEN}${CLANG_VERSION}${RESET}"
echo -e "${YELLOW}🧠 CPU:${RESET} ${GREEN}${HOST_CPU}${RESET}"
echo -e "${YELLOW}💻 Host:${RESET} ${GREEN}${HOST_OS} (${HOST_KERNEL})${RESET}"
echo -e "${YELLOW}📄 Build Log:${RESET} ${GREEN}${BUILD_LOG}${RESET}"
echo -e "${MAGENTA}==============================================================${RESET}\n"

# 🔍 Cek toolchain
if [ ! -f "$CLANG_DIR/bin/clang" ]; then
    echo -e "${RED}❌ Clang tidak ditemukan di: $CLANG_DIR${RESET}"
    exit 1
fi

if [ ! -f "$CLANG_DIR/bin/ld.lld" ]; then
    echo -e "${YELLOW}⚠️ ld.lld tidak ditemukan, menggunakan system lld${RESET}"
    sudo apt install -y lld &>/dev/null
fi

export PATH="$CLANG_DIR/bin:$GCC32_DIR/bin:$PATH"

# Set environment variables
	export USE_CCACHE=1
	export KBUILD_BUILD_HOST=xyz
	export KBUILD_BUILD_USER=standalone
	
# 🔍 Auto detect defconfig
CONFIG_PATH="$KERNEL_DIR/arch/arm64/configs"
DEFCONFIGS=($(ls "$CONFIG_PATH" | grep -E "defconfig$"))

if [ ${#DEFCONFIGS[@]} -eq 0 ]; then
    echo -e "${RED}❌ Tidak ada defconfig ditemukan di $CONFIG_PATH${RESET}"
    exit 1
elif [ ${#DEFCONFIGS[@]} -eq 1 ]; then
    DEFCONFIG=${DEFCONFIGS[0]}
    echo -e "${GREEN}✅ Ditemukan satu defconfig: ${DEFCONFIG}${RESET}"
else
    echo -e "${YELLOW}Pilih defconfig yang ingin digunakan:${RESET}"
    select DEFCONFIG in "${DEFCONFIGS[@]}"; do
        if [[ -n "$DEFCONFIG" ]]; then
            echo -e "${GREEN}✅ Menggunakan defconfig: $DEFCONFIG${RESET}"
            break
        else
            echo -e "${RED}❌ Pilihan tidak valid, coba lagi.${RESET}"
        fi
    done
fi

# 🧹 Bersihkan build lama
echo -e "\n${CYAN}🧹 Membersihkan build lama...${RESET}"
make clean &>/dev/null
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
rm -f "$BUILD_LOG"

# ⚙️ Generate defconfig
echo -e "${YELLOW}⚙️ Menghasilkan defconfig (${DEFCONFIG})...${RESET}"
make O="$OUT_DIR" ARCH="$ARCH" "$DEFCONFIG" | tee -a "$BUILD_LOG"
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Gagal generate defconfig. Pastikan file '${DEFCONFIG}' ada.${RESET}"
    exit 1
fi

# 🧭 Menuconfig opsional
read -p "$(echo -e ${MAGENTA}'🧭 Ingin buka menuconfig sebelum build? (y/n): '${RESET})" menu
[[ "$menu" =~ ^[Yy]$ ]] && make O="$OUT_DIR" ARCH="$ARCH" menuconfig | tee -a "$BUILD_LOG"

# ⏱️ Timer mulai
BUILD_START=$(date +%s)

# 🚀 Build kernel
echo -e "\n${CYAN}🚀 Memulai proses build kernel...${RESET}"
make -j$(nproc --all) O="$OUT_DIR" ARCH="$ARCH" \
	CC=clang \
    	LD=ld.lld \
    	AR=llvm-ar \
    	NM=llvm-nm \
    	STRIP=llvm-strip \
    	OBJCOPY=llvm-objcopy \
    	OBJDUMP=llvm-objdump \
    	READELF=llvm-readelf \
    	LLVM=1 LLVM_IAS=1 \
       CROSS_COMPILE="$CLANG_DIR/bin/aarch64-linux-gnu-" \
     CROSS_COMPILE_ARM32="$GCC32_DIR/bin/arm-linux-androideabi-" \
    	2>&1 | tee -a "$BUILD_LOG"

# 🕒 Timer selesai
BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - BUILD_START))

# ✅ Hasil build
IMAGE="$OUT_DIR/arch/arm64/boot/Image.gz"

echo -e "\n${CYAN}==============================================================${RESET}"
if [ -f "$IMAGE" ]; then
    echo -e "${GREEN}✅ Build kernel berhasil!${RESET}"
    echo -e "${YELLOW}📦 Output:${RESET} ${BLUE}${IMAGE}${RESET}"
    # Rename hasil build otomatis
    FINAL_IMAGE="$KERNEL_DIR/Millenia-Kernel-${DATE}.img"
    cp "$IMAGE" "$FINAL_IMAGE"
    echo -e "${GREEN}💾 Disalin ke:${RESET} ${FINAL_IMAGE}"

else
    echo -e "${RED}❌ Build kernel gagal. Periksa ${BUILD_LOG}.${RESET}"
fi
echo -e "${YELLOW}⏱️ Durasi Build:${RESET} ${GREEN}${BUILD_TIME}s${RESET}"
echo -e "${CYAN}==============================================================${RESET}"
echo -e "${MAGENTA}${BOLD}🎉 Congratulations by Michikoextv2 — Build Selesai!${RESET}\n"
