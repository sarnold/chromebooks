# chromebook-config.sh - Configuration file for chromebook-setup

# stuff required for snow/peach for now
#  from google: nv_uboot-snow-simplefb.kpart
#
# set NVUBOOT=1 to enable  (not wired yet))

# default rootfs and toolchain (arm)
TOOLCHAIN="gcc-arm-8.2-2018.08-x86_64-arm-linux-gnueabihf"
TOOLCHAIN_URL="https://developer.arm.com/-/media/Files/downloads/gnu-a/8.2-2018.08/$TOOLCHAIN.tar.xz"
# arm64 rootfs and toolchain
ARM64_TOOLCHAIN="gcc-arm-8.2-2018.08-x86_64-aarch64-linux-gnu"
ARM64_TOOLCHAIN_URL="https://developer.arm.com/-/media/Files/downloads/gnu-a/8.2-2018.08/$ARM64_TOOLCHAIN.tar.xz"

# debian rootfs images
DEBIAN_SUITE="sid"
ROOTFS_BASE_URL="https://people.collabora.com/~eballetbo/debian/images/"

GENTOO_ARCH="${CB_SETUP_ARCH}"
[ "$CB_SETUP_ARCH" == "x86_64" ] && GENTOO_ARCH="amd64"

# the gentoo url sorting really needs refactoring
GENTOO_MIRROR="https://gentoo.osuosl.org/releases/${GENTOO_ARCH}/autobuilds/"

if [[ -n $DO_GENTOO ]]; then
    if [[ $USE_LIBC == "glibc" ]]; then
        GENTOO_AMD64_BASE="latest-stage3-amd64-openrc.txt"
        GENTOO_ARM64_BASE="latest-stage3-arm64-openrc.txt"
        GENTOO_ARM_BASE="latest-stage3-armv7a_hardfp-openrc.txt"
    elif [[ $USE_LIBC == "musl" ]]; then
        GENTOO_AMD64_BASE="latest-stage3-amd64-musl-hardened.txt"
        GENTOO_ARM64_BASE="latest-stage3-arm64-musl-hardened.txt"
        GENTOO_ARM_BASE="latest-stage3-armv7a_hardfp_musl-hardened-openrc.txt"
    else
        echo "No libc was defined!! Set USE_LIBC to one of: musl or glibc!!"
        exit 1
    fi

    AMD64_PATH=$(wget -O- ${GENTOO_MIRROR}${GENTOO_AMD64_BASE} | grep stage3 | cut -f1 -d" ")
    ARM64_PATH=$(wget -O- ${GENTOO_MIRROR}${GENTOO_ARM64_BASE} | grep stage3 | cut -f1 -d" ")
    ARM_PATH=$(wget -O- ${GENTOO_MIRROR}${GENTOO_ARM_BASE} | grep stage3 | cut -f1 -d" ")

    AMD64_STAGE=$(echo "${AMD64_PATH}" | cut -f2 -d/)
    ARM64_STAGE=$(echo "${ARM64_PATH}" | cut -f2 -d/)
    ARM_STAGE=$(echo "${ARM_PATH}" | cut -f2 -d/)
    #ARM_STAGE="stage4-armv7a-hardfp-20201015.tar.bz2"
fi

# alternate minimal rootfs for debian and ubuntu on arm
# note these are console only but they do have wifi tools
# for now, browse the ALT_BASE_URL to look for updates
ALT_BASE_URL="https://rcn-ee.com/rootfs/eewiki/minfs/"
ALT_UBASE_URL="https://github.com/VCTLabs/RootStock-NG/releases/download/v2023.09/"

DEB_ARCH="${CB_SETUP_ARCH}"
[ "$CB_SETUP_ARCH" == "arm" ] && DEB_ARCH="armhf"

STRETCH_BASE="debian-9.12-minimal-armhf-2020-02-10"
BUSTER_BASE="debian-10.13-minimal-${DEB_ARCH}-2022-12-20"
BULLSEYE_BASE="debian-11.7-minimal-${DEB_ARCH}-2023-07-14"
BOOKWORM_BASE="debian-12.1-minimal-${DEB_ARCH}-2023-08-22"

XENIAL_BASE="ubuntu-16.04.4-minimal-armhf-2018-03-26"
BIONIC_BASE="ubuntu-18.04.6-minimal-armhf-2022-12-20"
FOCAL_BASE="ubuntu-20.04.5-minimal-armhf-2023-07-14"

BIONIC_UBASE="ubuntu-18.04.6-minimal-arm64-2023-09-28"
FOCAL_UBASE="ubuntu-20.04.6-minimal-arm64-2023-09-28"
JAMMY_UBASE="ubuntu-22.04.3-minimal-arm64-2023-09-28"

XENIAL_CLOUD="https://cloud-images.ubuntu.com/xenial/current"

BIONIC_CLOUD="https://cloud-images.ubuntu.com/bionic/current"
FOCAL_CLOUD="https://cloud-images.ubuntu.com/focal/current"
JAMMY_CLOUD="https://cloud-images.ubuntu.com/jammy/current"

STRETCH_TARBALL="${STRETCH_BASE}.tar.xz"
BUSTER_TARBALL="${BUSTER_BASE}.tar.xz"
BULLSEYE_TARBALL="${BULLSEYE_BASE}.tar.xz"
BOOKWORM_TARBALL="${BOOKWORM_BASE}.tar.xz"

SSH_KEY_REGEN="tools/sys-mods/regenerate_ssh_host_keys"
NETPLAN_CFG="tools/cloud/99-config.yaml"
CLOUD_INIT_CFG="tools/cloud/99-data.cfg"
[[ -n $HAVE_ETHERNET ]] && CLOUD_INIT_CFG="99-data-eth.cfg"

if [ "$CB_SETUP_ARCH" == "arm" ]; then
    XENIAL_TARBALL="${XENIAL_BASE}.tar.xz"
    BIONIC_TARBALL="${BIONIC_BASE}.tar.xz"
    FOCAL_TARBALL="${FOCAL_BASE}.tar.xz"
elif [ "$CB_SETUP_ARCH" == "arm64" ]; then
    if [[ -n $DO_BIONIC || -n $DO_XENIAL || -n $DO_FOCAL || -n $DO_JAMMY ]]; then
        if [[ -n $DO_CLOUD ]]; then
            XENIAL_TARBALL="${XENIAL_CLOUD}/xenial-server-cloudimg-${DEB_ARCH}-root.tar.xz"
            BIONIC_TARBALL="${BIONIC_CLOUD}/bionic-server-cloudimg-${DEB_ARCH}-root.tar.xz"
            FOCAL_TARBALL="${FOCAL_CLOUD}/focal-server-cloudimg-${DEB_ARCH}-root.tar.xz"
            JAMMY_TARBALL="${JAMMY_CLOUD}/jammy-server-cloudimg-${DEB_ARCH}-root.tar.xz"
        else
            BIONIC_BASE="${BIONIC_UBASE}"
            BIONIC_TARBALL="${BIONIC_UBASE}.tar.xz"
            FOCAL_BASE="${FOCAL_UBASE}"
            FOCAL_TARBALL="${FOCAL_UBASE}.tar.xz"
            JAMMY_BASE="${JAMMY_UBASE}"
            JAMMY_TARBALL="${JAMMY_UBASE}.tar.xz"
            ALT_BASE_URL="${ALT_UBASE_URL}"
            DO_REGEN_KEYS="1"
        fi
    fi
fi

ALT_DEB_URL="https://rcn-ee.com/rootfs/debian-arm64-minimal/2022-01-30/"
#BULLSEYE_BASE64="debian-11.2-minimal-arm64-2022-01-30"
#BULLSEYE_TARBALL64="${BULLSEYE_BASE64}.tar.xz"

TOUCH_ARM_URL="https://ci.ubports.com/job/xenial-mainline-edge-rootfs-armhf/"
TOUCH_ARM64_URL="https://ci.ubports.com/job/xenial-mainline-edge-rootfs-arm64/"
TOUCH_BASE="lastSuccessfulBuild/artifact/out/"
TOUCH_ARM_TARBALL="ubuntu-touch-xenial-edge-armhf-rootfs.tar.gz"
#TOUCH_ARM_TARBALL="ubuntu-touch-xenial-edge-armhf-rootfs-cfgd.tar.bz2"
TOUCH_ARM64_TARBALL="ubuntu-touch-xenial-edge-arm64-rootfs.tar.gz"

if [[ -n $USE_KALI ]]; then
    KRNL_SRC_DIR="linux-kali"
else
    KRNL_SRC_DIR="linux-stable"
fi

KERNEL_URL="git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git"
KALI_KERNEL_URL="https://gitlab.com/kalilinux/packages/linux.git"

if [[ -n $DO_STRETCH || -n $DO_BUSTER || -n $DO_BULLSEYE || -n $DO_BOOKWORM || -n $DO_BIONIC || -n $DO_XENIAL || -n $DO_FOCAL || -n $DO_JAMMY ]]; then
    if [[ -n $DO_STRETCH ]]; then
        ROOTFS="debian-stretch"
        BASE_DIR="${STRETCH_BASE}"
    elif [[ -n $DO_BUSTER ]]; then
        ROOTFS="debian-buster"
        BASE_DIR="${BUSTER_BASE}"
    elif [[ -n $DO_BULLSEYE ]]; then
        ROOTFS="debian-bullseye"
        BASE_DIR="${BULLSEYE_BASE}"
    elif [[ -n $DO_BOOKWORM ]]; then
        ROOTFS="debian-bookworm"
        BASE_DIR="${BOOKWORM_BASE}"
    elif [[ -n $DO_BIONIC ]]; then
        ROOTFS="ubuntu-bionic"
        BASE_DIR="${BIONIC_BASE}"
    elif [[ -n $DO_XENIAL ]]; then
        ROOTFS="ubuntu-xenial"
        BASE_DIR="${XENIAL_BASE}"
    elif [[ -n $DO_FOCAL ]]; then
        ROOTFS="ubuntu-focal"
        BASE_DIR="${FOCAL_BASE}"
    elif [[ -n $DO_JAMMY ]]; then
        ROOTFS="ubuntu-jammy"
        BASE_DIR="${JAMMY_BASE}"
    fi
    ROOTFS_BASE_URL="${ALT_BASE_URL}"
    if [ "$CB_SETUP_ARCH" == "arm64" ]; then
        ROOTFS_BASE_URL="${ALT_UBASE_URL}"
    fi
fi

# Current Working Directory
CWD=$PWD

# Chromebook-specific config.

declare -A chromebook_names=(
    ["XE303C12"]="Samsung Chromebook"
    ["C100PA"]="ASUS Chromebook Flip C100PA"
    ["NBCJ2"]="CTL J2 Chromebook for Education"
    ["CB5-311"]="Acer Chromebook 13"
    ["C810-T78Y"]="Acer Chromebook 13 4GB"
    ["XE513C24"]="Samsung Chromebook Plus"
)
