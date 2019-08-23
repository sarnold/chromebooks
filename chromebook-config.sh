# chromebook-config.sh - Configuration file for chromebook-setup

# default rootfs and toolchain (arm)
TOOLCHAIN="gcc-arm-8.2-2018.08-x86_64-arm-linux-gnueabihf"
TOOLCHAIN_URL="https://developer.arm.com/-/media/Files/downloads/gnu-a/8.2-2018.08/$TOOLCHAIN.tar.xz"
# arm64 rootfs and toolchain
ARM64_TOOLCHAIN="gcc-arm-8.2-2018.08-x86_64-aarch64-linux-gnu"
ARM64_TOOLCHAIN_URL="https://developer.arm.com/-/media/Files/downloads/gnu-a/8.2-2018.08/$ARM64_TOOLCHAIN.tar.xz"

# debian rootfs images
DEBIAN_SUITE="sid"
ROOTFS_BASE_URL="https://people.collabora.com/~eballetbo/debian/images/"

# alternate minimal rootfs for debian and ubuntu on arm
# note these are console only but they do have wifi tools
# for now, browse the ALT_BASE_URL to look for updates
ALT_BASE_URL="https://rcn-ee.com/rootfs/eewiki/minfs/"
STRETCH_BASE="debian-9.9-minimal-armhf-2019-08-11"
BUSTER_BASE="debian-10.0-minimal-armhf-2019-08-11"
BIONIC_BASE="ubuntu-18.04.3-minimal-armhf-2019-08-11"

STRETCH_TARBALL="${STRETCH_BASE}.tar.xz"
BUSTER_TARBALL="${BUSTER_BASE}.tar.xz"
BIONIC_TARBALL="${BIONIC_BASE}.tar.xz"

KERNEL_URL="git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"
KALI_KERNEL_URL="https://gitlab.com/kalilinux/packages/linux.git"

if [[ -n $DO_STRETCH || -n $DO_BUSTER || -n $DO_BIONIC ]]; then
    if [[ -n $DO_STRETCH ]]; then
        ROOTFS="debian-stretch"
        BASE_DIR="${STRETCH_BASE}"
    elif [[ -n $DO_BUSTER ]]; then
        ROOTFS="debian-buster"
        BASE_DIR="${BUSTER_BASE}"
    elif [[ -n $DO_BIONIC ]]; then
        ROOTFS="ubuntu-bionic"
        BASE_DIR="${BIONIC_BASE}"
    fi
    ROOTFS_BASE_URL="${ALT_BASE_URL}"
fi

# Current Working Directory
CWD=$PWD

# Chromebook-specific config.

declare -A chromebook_names=(
    ["C100PA"]="ASUS Chromebook Flip C100PA"
    ["NBCJ2"]="CTL J2 Chromebook for Education"
    ["XE513C24"]="Samsung Chromebook Plus"
    ["CB5-311-T6R7"]="Acer Chromebook 13"
)
