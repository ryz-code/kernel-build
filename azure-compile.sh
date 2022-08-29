#!/usr/bin/env bash
 
# Main Declaration
function ENVIRONTMENT() {
export KERNEL_NAME=GINKGO-AZURE-CLANG
export KBUILD_BUILD_USER=$BUILD_USER
export KBUILD_BUILD_HOST=$BUILD_HOST
export KBUILD_COMPILER_STRING="$CLANG_VER with $LLD_VER"

KERNEL_ROOTDIR=$CIRRUS_WORKING_DIR/KERNEL
DEVICE_DEFCONFIG=vendor/sixteen_defconfig
IMGS=$KERNEL_ROOTDIR/out/arch/arm64/boot/Image.gz-dtb

CLANG_ROOTDIR=$CIRRUS_WORKING_DIR/AZURE-CLANG
CLANG_VER="$("$CLANG_ROOTDIR"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
LLD_VER="$("$CLANG_ROOTDIR"/bin/ld.lld --version | head -n 1)"

DATE=$(date +"%F-%S")
START=$(date +"%s")
}

# Checking environtment
# Warning !! Dont Change anything there without known reason.
function CHECK() {
echo ================================================
echo BUILDER NAME = ${KBUILD_BUILD_USER}
echo BUILDER HOSTNAME = ${KBUILD_BUILD_HOST}
echo DEVICE_DEFCONFIG = ${DEVICE_DEFCONFIG}
echo TOOLCHAIN_VERSION = ${KBUILD_COMPILER_STRING}
echo CLANG_ROOTDIR = ${CLANG_ROOTDIR}
echo KERNEL_ROOTDIR = ${KERNEL_ROOTDIR}
echo ================================================
}

# Compile
COMPILE(){
cd ${KERNEL_ROOTDIR}

make -j$(nproc) O=out ARCH=arm64 SUBARCH=arm64 ${DEVICE_DEFCONFIG}
make -j$(nproc) ARCH=arm64 SUBARCH=arm64 O=out \
      CC=${CLANG_ROOTDIR}/bin/clang \
      LD=${CLANG_ROOTDIR}/bin/ld.lld \
      CROSS_COMPILE=${CLANG_ROOTDIR}/bin/aarch64-linux-gnu- \
      CROSS_COMPILE_ARM32=${CLANG_ROOTDIR}/bin/arm-linux-gnueabi-

if ! [ -a "$IMGS" ]; then
FIN-ERROR
fi

git clone --depth=1 $GH_TOKEN@github.com/c3eru/anykernel -b ginkgo $CIRRUS_WORKING_DIR/AnyKernel

cp $IMGS $CIRRUS_WORKING_DIR/AnyKernel
}

# Push kernel to channel
function PUSH() {
cd $CIRRUS_WORKING_DIR/AnyKernel
zip -r9 $KERNEL_NAME-${DATE}.zip *
ZIP=$(echo *.zip)

curl -F document=@$ZIP "https://api.telegram.org/$TG_TOKEN/sendDocument" \
      -F chat_id="$TG_CHAT_ID" \
      -F "disable_web_page_preview=true" \
      -F "parse_mode=html" \
      -F caption="$KERNEL_NAME
=======================
🐧 Linux version: $KERNEL_VERSION
🌿 Branch: $BRANCH
🎁 Top commit: $LATEST_COMMIT
👩‍💻 Commit author by: $COMMIT_BY
💡 Compiler: $TOOLCHAIN_VERSION
=======================
Compile took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s)."

rm -rf *.zip
}

# Fin Error
function FIN-ERROR() {
curl -s -X POST "https://api.telegram.org/$TG_TOKEN/sendMessage" -d chat_id="$TG_CHAT_ID" \
      -d "disable_web_page_preview=true" \
      -d "parse_mode=html" \
      -d text="==============================%0A<b>    Building Kernel AZURE-CLANG Failed!</b>%0A==============================" \

curl -s -X POST "https://api.telegram.org/$TG_TOKEN/sendSticker" \
      -d sticker="CAACAgIAAx0CXjGT1gACDRRhYsUKSwZJQFzmR6eKz2aP30iKqQACPgADr8ZRGiaKo_SrpcJQIQQ" \
      -d chat_id="$TG_CHAT_ID"
      
exit 1
}

# Info
function INFO() {
cd $KERNEL_ROOTDIR
KERNEL_VERSION=$(cat $KERNEL_ROOTDIR/out/.config | grep Linux/arm64 | cut -d " " -f3)
TOOLCHAIN_VERSION=$(cat $KERNEL_ROOTDIR/out/include/generated/compile.h | grep LINUX_COMPILER | cut -d '"' -f2)
TRIGGER_SHA="$(git rev-parse HEAD)"
LATEST_COMMIT="$(git log --pretty=format:'%s' -1)"
COMMIT_BY="$(git log --pretty=format:'%an' -1)"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
}

ENVIRONTMENT
CHECK
COMPILE
END=$(date +"%s")
DIFF=$(($END - $START))
INFO
PUSH
 
