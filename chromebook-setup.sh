#!/usr/bin/env bash
# This file:
#
#  - Chromebook tool to create a bootable media device with various
#    flavors of rootfs.
#
# Usage:
#
#  OVERRIDE=1 ./chromebook-setup.sh COMMAND [ARGS] OPTIONS
#
# Based on mali_chromebook-setup_006 scripts by Guillaume Tucker
#  - https://community.arm.com/graphics/b/blog/posts/linux-on-chromebook-with-arm-mali-gpu
#

# Exit on error. Append "|| true" if you expect an error.
set -e
# Turn on traces, useful while debugging but commented out by default
#set -x

source chromebook-config.sh

print_usage_exit()
{
    local arg_ret="${1-1}"

    echo "
Chromebook Linux media builder.

Environment variables:

  CROSS_COMPILE

    Standard variable to use a cross-compiler toolchain.  If it is not
    already defined before calling this script, it will be set by
    default in this script to match the toolchain downloaded using the
    get_toolchain command.

Usage:

  OVERRIDE=1 $0 COMMAND [ARGS] OPTIONS

  Only COMMAND and ARGS are positional arguments; the OPTIONS can be
  placed anywhere and in any order.  The definition of ARGS varies
  with each COMMAND.

Overrides:

  USE_LATEST_RC:

  Set USE_LATEST_RC=true (or anything not zero-length) to enable the
  latest ``-rc*`` kernel tag instead of the latest release tag.

  NO_LPAE:

  Set NO_LPAE=true (or anything not zero-length) to disable support
  for LPAE on ARM chromebooks.  Note the resulting kernel will
  boot on ARM CPUs with ``lpae`` support but will be limited to
  no more than 2 GBs of ram.

  ENABLE_HYP:
  Set ENABLE_HYP=true (or anything not zero-length) to enable HYP mode
  for KVM acceleration (requires lpae and virtualization cpu flags).
  DO NOT set NO_LPAE if you need this.

  USE_KALI:

  Set USE_KALI=true (or anything not zero-length) to use the kali linux
  kernel source repository instead of linux-stable.

  DO_[STRETCH|BUSTER|XENIAL|BIONIC]:

  Set one of the above to use a recent mininal release targeted at
  embedded devices. These are console-only but include nginx, connman,
  and wpa_supplicant (among other things). Note that wifi modules may
  need extra firmware, eg, veyron-minnie requires updated blobs to
  activate the interface:

    brcmfmac4354-sdio.{bin,txt}

  DO_TOUCH:

  Use the mainline Ubuntu Touch rootfs; note this works without an actual
  touchscreen, but is mainly targeted at touchscreen-only devices (ie,
  phones and tablets).  Well suited to touch chromebooks, albeit with a
  few rough edges (and possibly some splinters). Also note this is not
  console-only rootfs (duh...)

  DO_GENTOO:

  Use a Gentoo stage tarball as rootfs.  Defaults to hardened stage if
  available; requires setting one of glibc or musl if enabled.  Note
  the caveats about firmware apply double for Gentoo stages (since
  ``/lib/firmware`` is completely empty).  You will need to manually
  populate the firmware tree before you can activate things like USB
  and networking on some chromebooks (eg, nyan-big).

  USE_LIBC:

  Must be set to either ``musl`` or ``glibc`` if DO_GENTOO is enabled.

Options:

  The following options are common to all commands.  Only --storage
  and --architecture are compulsory.

  --storage=PATH
    Path to the Chromebook storage device or directory i.e.
      /dev/sdb for the SD card.
      /srv/nfs/rootfs for a NFS mount point.
"
echo "  --architecture=ARCH
    Chromebook architecture, needs to be one of the following: arm | arm64 | x86_64"

echo "Supported devices:

"
for chromebook_variant in "${!chromebook_names[@]}"
do
    echo "      $chromebook_variant (${chromebook_names[$chromebook_variant]})"
done

echo "Available commands:

  help
    Print this help message.

  do_everything
    Do everything in one command with default settings.

  format_storage
    Format the storage device to be used as a bootable SD card or USB
    stick on the Chromebook.  The device passed to the --storage
    option is used.

  mount_rootfs
    Mount the root partition in a local rootfs directory.  The partition
    will remain mounted in order to run other commands.

  setup_rootfs [ARCHIVE]
    Install the rootfs on the storage device specified with --storage.
    If ARCHIVE is not provided then the default one will be automatically
    downloaded and used.  The standard rootfs URL is:
        $DEBIAN_ROOTFS_URL

  get_toolchain
    Download and extract the cross-compiler toolchain needed to build
    the Linux kernel.  It is fixed to this version:
        $TOOLCHAIN_URL

    In order to use an alternative toolchain, the CROSS_COMPILE
    environment variable can be set before calling this script to
    point at the toolchain of your choice.

  get_kernel [URL]
    Get the latest kernel source code. The optional URL argument is to
    specify an alternative Git repository, the default one being:
        $KERNEL_URL

  config_kernel
    Configure the Linux kernel.

  build_kernel
    Compile the Linux kernel modules.

  deploy_kernel_modules
    Install the Linux kernel modules on the rootfs.

  build_bootstub
    Build the ChromeOS bootstub.efi.

  build_vboot
    Build vboot image.

  deploy_vboot
    Install the kernel vboot image on the boot partition of the storage
    device.

  eject_storage
    Eject removable media.

Commands useful for development workflow:

  deploy_kernel
    Compile the Linux kernel, its modules, the vboot image and deploy all
    on the storage device (uses existing rootfs).

  do_rootfs
    Create and mount device root partition and deploy rootfs, then stop.

For example, to do everything on a SD card for the ASUS Chromebook Flip
C100PA (arm):

  $0 do_everything --architecture=arm --storage=/dev/sdX

or to do the same to use NFS for the root filesystem:

  $0 do_everything --architecture=arm --storage=/srv/nfs/nfsroot

"

    exit $arg_ret
}

opts=$(getopt -o "s:" -l "storage:,architecture:" -- "$@")
eval set -- "$opts"

while true; do
    case "$1" in
        --storage)
            CB_SETUP_STORAGE="$2"
            shift 2
            ;;
        --architecture)
            CB_SETUP_ARCH="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Internal error"
            exit 1
            ;;
    esac
done

cmd="$1"
[ -z "$cmd" ] && print_usage_exit
shift

# -----------------------------------------------------------------------------
# Options sanitising

[ -n "$CB_SETUP_STORAGE" ] || {
    echo "Incorrect path/storage device passed to the --storage option."
    print_usage_exit
}

if [ -b "$CB_SETUP_STORAGE" ]; then
    storage_is_media_device=true
else
    storage_is_media_device=false
fi

[ "$CB_SETUP_ARCH" = "arm" ] || [ "$CB_SETUP_ARCH" == "arm64" ] || [ "$CB_SETUP_ARCH" == "x86_64" ] || {
    echo "Incorrect architecture device passed to the --architecture option."
    print_usage_exit
}

DEBIAN_ROOTFS_URL="$ROOTFS_BASE_URL/debian-$DEBIAN_SUITE-chromebook-$DEBIAN_ARCH.tar.gz"

if [ "$CB_SETUP_ARCH" == "x86_64" ]; then
    GENTOO_STAGE_URL="${GENTOO_MIRROR}${GENTOO_AMD64_BASE}${AMD64_STAGE}"
elif [ "$CB_SETUP_ARCH" == "arm64" ]; then
    GENTOO_STAGE_URL="${GENTOO_MIRROR}${GENTOO_ARM64_BASE}${ARM64_STAGE}"
    UBUNTU_TOUCH_URL="${TOUCH_URL}${TOUCH_BASE}${TOUCH_TARBALL}"
    TOOLCHAIN="$ARM64_TOOLCHAIN"
    TOOLCHAIN_URL="$ARM64_TOOLCHAIN_URL"
    [ -z "$CROSS_COMPILE" ] && export CROSS_COMPILE=\
$PWD/$TOOLCHAIN/bin/aarch64-linux-gnu-
else
    GENTOO_STAGE_URL="${GENTOO_MIRROR}${GENTOO_ARM_BASE}${ARM_STAGE}"
    UBUNTU_TOUCH_URL="${TOUCH_URL}${TOUCH_BASE}${TOUCH_TARBALL}"
    [ -z "$CROSS_COMPILE" ] && export CROSS_COMPILE=\
$PWD/$TOOLCHAIN/bin/arm-linux-gnueabihf-
fi

export ARCH=$CB_SETUP_ARCH

# use alternate rootfs from RCN
if [[ -n $DO_STRETCH ]]; then
    ALT_ROOTFS_URL="$ROOTFS_BASE_URL/$STRETCH_TARBALL"
elif [[ -n $DO_BUSTER ]]; then
    ALT_ROOTFS_URL="$ROOTFS_BASE_URL/$BUSTER_TARBALL"
elif [[ -n $DO_BIONIC ]]; then
    ALT_ROOTFS_URL="$ROOTFS_BASE_URL/$BIONIC_TARBALL"
elif [[ -n $DO_XENIAL ]]; then
    ALT_ROOTFS_URL="$ROOTFS_BASE_URL/$XENIAL_TARBALL"
elif [[ -n $DO_GENTOO ]]; then
    ALT_ROOTFS_URL="${GENTOO_STAGE_URL}"
elif [[ -n $DO_TOUCH ]]; then
    ALT_ROOTFS_URL="${UBUNTU_TOUCH_URL}"
else
    ALT_ROOTFS_URL=""
fi

# -----------------------------------------------------------------------------
# Utility functions

jopt()
{
    echo "-j"$(grep -c processor /proc/cpuinfo)
}

ensure_command() {
    # ensure_command foo foo-package
    sudo which "$1" 2>/dev/null 1>/dev/null || (
        echo "Install required command $1 from package $2, e.g. sudo apt-get install $2"
        exit 1
    )
}

set_alt_archive()
{
    if [[ -n $DO_STRETCH || -n $DO_BUSTER || -n $DO_BIONIC || -n $DO_XENIAL ]]; then
        case $ROOTFS in
        stretch)
            debian_archive="${STRETCH_TARBALL}"
            ;;
        buster)
            debian_archive="${BUSTER_TARBALL}"
            ;;
        bionic)
            debian_archive="${BIONIC_TARBALL}"
            ;;
        xenial)
            debian_archive="${XENIAL_TARBALL}"
            ;;
        esac
    fi
}

process_alt_archive()
{
    if [[ -n $DO_STRETCH || -n $DO_BUSTER || -n $DO_BIONIC || -n $DO_XENIAL ]]; then
        if [[ ! -d "${BASE_DIR}" && -f "${debian_archive}" ]]; then
            echo "Unpacking alt rootfs $debian_archive"
            tar xf "${debian_archive}"
        fi
        debian_archive=$(find "${BASE_DIR}" -maxdepth 2 -name \*"${ROOTFS}"\*.tar)
        echo "Alt rootfs: ${debian_archive}"
    fi
}

find_partitions_by_id()
{
    unset CB_SETUP_STORAGE1 CB_SETUP_STORAGE2

    for device in /dev/disk/by-id/*; do
        if [ `realpath $device` = $CB_SETUP_STORAGE ]; then
            if echo "$device" | grep -q -- "-part[0-9]*$"; then
                echo "device $MMC must not be a partition part ($device)" 1>&2
                exit 1
            fi
            for part_id in `ls "$device-part"*`; do
                local part=`realpath $part_id`
                local part_no=`echo $part_id | sed -e 's/.*-part//g'`
                if test "$part_no" = 1; then
                    CB_SETUP_STORAGE1=$part
                elif test "$part_no" = 2; then
                    CB_SETUP_STORAGE2=$part
                fi
            done
	    break
        fi
    done
}

wait_for_partitions_to_appear()
{
    for device in /dev/disk/by-id/*; do
        if [ `realpath $device` = $CB_SETUP_STORAGE ]; then
            if echo "$device" | grep -q -- "-part[0-9]*$"; then
                echo "device $CB_SETUP_STORAGE must not be a partition part ($device)" 1>&2
                exit 1
            fi

            if [ ! -e ${device}-part1 ]; then
                echo -n "Waiting for partitions to appear ."

                while [ ! -e ${device}-part1 ]
                do
                    sleep 1
                    echo -n "."
                done
                echo " done"
            fi
        fi
    done
}

create_fit_image()
{
    if [ "$CB_SETUP_ARCH" != "x86_64" ]; then
         # Devicetree binaries
         local dtbs=""
         local kernel=""
         local compression=""

         if [ "$CB_SETUP_ARCH" == "arm" ]; then
             kernel="zImage"
             compression="none"
             dtbs=" \
                   -b arch/arm/boot/dts/exynos5250-snow.dtb \
                   -b arch/arm/boot/dts/exynos5250-snow-rev5.dtb \
                   -b arch/arm/boot/dts/exynos5420-peach-pit.dtb \
                   -b arch/arm/boot/dts/exynos5800-peach-pi.dtb \
                   -b arch/arm/boot/dts/rk3288-veyron-minnie.dtb \
                   -b arch/arm/boot/dts/rk3288-veyron-jerry.dtb \
                   -b arch/arm/boot/dts/rk3288-veyron-speedy.dtb \
                   -b arch/arm/boot/dts/tegra124-nyan-big.dtb"
         else
             kernel="Image.lz4"
             compression="lz4"

             # Compress image
             rm -f arch/${CB_SETUP_ARCH}/boot/Image.lz4 || true
             lz4 arch/${CB_SETUP_ARCH}/boot/Image arch/${CB_SETUP_ARCH}/boot/Image.lz4

             dtbs="-b arch/arm64/boot/dts/rockchip/rk3399-gru-kevin.dtb"
         fi

         mkimage -D "-I dts -O dtb -p 2048" -f auto -A ${CB_SETUP_ARCH} -O linux -T kernel -C $compression -a 0 \
                 -d arch/${CB_SETUP_ARCH}/boot/$kernel $dtbs \
                 kernel.itb
    else
	echo "TODO: create x86_64 FIT image, now using a raw image"
    fi
}

# -----------------------------------------------------------------------------
# Functions to run each command

cmd_help()
{
    print_usage_exit 0
}

cmd_format_storage()
{
    # Skip this command if is not a media device.
    if ! $storage_is_media_device; then return 0; fi

    echo "Creating partitions on $CB_SETUP_STORAGE"
    df 2>&1 | grep "$CB_SETUP_STORAGE" || true
    read -p "Continue? [N/y] " yn
    [ "$yn" = "y" ] || {
        echo "Aborted"
        exit 1
    }

    # Unmount any partitions automatically mounted
    sudo umount "$CB_SETUP_STORAGE"* > /dev/null 2>&1 || true

    # Clear the partition table
    sudo dd if=/dev/zero of=${CB_SETUP_STORAGE} bs=512 count=1
    sudo parted --script "$CB_SETUP_STORAGE" mklabel gpt

    # Create the GPT/MBR data
    sudo cgpt create "$CB_SETUP_STORAGE"
    sudo cgpt boot -p "$CB_SETUP_STORAGE"

    # add kernel image (boot) partition with priority, etc
    sudo cgpt add -i 1 -t kernel -b 8192 -s 32768 -l kernel -S 1 -T 5 -P 10 "$CB_SETUP_STORAGE"

    # need size first, then add rootfs partition
    TOTAL_SIZE=$(sudo cgpt show "${CB_SETUP_STORAGE}" | grep 'Sec GPT table' | awk '{ print $1 }')
    sudo cgpt add -i 2 -t data -b 40960 -s `expr  "${TOTAL_SIZE}" - 40960` -l rootfs "$CB_SETUP_STORAGE"

    # Tell the system to refresh what it knows about the disk partitions
    sudo partprobe "$CB_SETUP_STORAGE"
    sleep 2

    wait_for_partitions_to_appear
    find_partitions_by_id

    sudo mkfs.ext4 -L ROOT-A "$CB_SETUP_STORAGE2"

    echo "Done."

    # the full do_everything command sometimes silently fails here :(
    sleep 2
}

cmd_mount_rootfs()
{
    # Skip this command if is not a media device.
    if ! $storage_is_media_device; then return 0; fi

    find_partitions_by_id

    echo "Mounting rootfs partition..."

    #udisksctl mount -b "$CB_SETUP_STORAGE2" > /dev/null 2>&1 || true
    udisksctl mount -b "$CB_SETUP_STORAGE2"
    ROOTFS_DIR=$(findmnt -n -o TARGET --source $CB_SETUP_STORAGE2)

    # Verify that the disk is mounted, otherwise exit
    if [ -z "$ROOTFS_DIR" ]; then exit 1; fi

    echo "Done."
}

cmd_setup_rootfs()
{
    local debian_url="${1:-$DEBIAN_ROOTFS_URL}"
    local debian_archive=$(basename $debian_url)

    set_alt_archive
    echo "Using tarball: ${debian_archive}"

    # Download the Debian rootfs archive if it's not already there.
    if [ ! -f "$debian_archive" ]; then
        echo "Rootfs archive not found, downloading from $debian_url"
        wget "$debian_url"
    fi

    process_alt_archive

    # Untar the rootfs archive.
    echo "Extracting files onto the partition"
    sudo tar xpf "${debian_archive}" --xattrs-include='*.*' --acls \
        --numeric-owner -C "${ROOTFS_DIR}"
    sudo chown root:root "${ROOTFS_DIR}/"
    sudo chmod 755 "${ROOTFS_DIR}/"

    # allow empty root passwd on gentoo rootfs
    if [[ -n $DO_GENTOO ]]; then
        echo "Allowing empty root password on Gentoo stage..."
        sudo sed -i -e "s|root:\*|root:|" "${ROOTFS_DIR}/etc/shadow"
    fi

    echo "Done."
}

cmd_get_toolchain()
{
    if [ "$CB_SETUP_ARCH" == "x86_64" ]; then
        echo "Using default distro toolchain"
        return 0
    fi

    [ -d "$TOOLCHAIN" ] && {
        echo "Toolchain already downloaded: $TOOLCHAIN"
        return 0
    }

    echo "Downloading and extracting toolchain: $url"
    curl -L "$TOOLCHAIN_URL" | tar xJf -

    echo "Done."
}

cmd_get_kernel()
{
    echo "Creating initial git repository if not already present..."

    local arg_url="${1-$KERNEL_URL}"
    local dir_name="$KRNL_SRC_DIR"

    # 1. Create initial git repository if not already present
    # 2. Checkout the latest release tagged
    [ -d $dir_name ] || {
        git clone "$arg_url" $dir_name
        cd "$dir_name"
        local tag
        if [[ -n $USE_LATEST_RC ]]; then
            tag=$(git describe --abbrev=0)
        else
            rtag=$(git describe --abbrev=0 --exclude="*rc*")
            tag=$(git tag --list "${rtag}.*" | sort -V | tail -n 1)
        fi
	git checkout ${tag} -b release-${tag}
	cd - > /dev/null
    }

    echo "Done."
}

cmd_config_kernel()
{
    echo "Configure the kernel..."

    local src_dir="${1-$KRNL_SRC_DIR}"

    cd $src_dir
    base_defconfig="arch/arm/configs/multi_v7_defconfig"

    # Create .config
    if [ "$CB_SETUP_ARCH" == "arm" ]; then
            if [ -z "${NO_LPAE}" ]; then
                if [ -n "$ENABLE_HYP" ]; then
                    echo "Enabling HYP mode kernel support..."
                    CPU_FRAGMENT="$CWD/fragments/multi-v7/lpae.cfg $CWD/fragments/multi-v7/kvm-hyp.cfg"
                else
                    echo "Enabling LPAE kernel support..."
                    CPU_FRAGMENT="$CWD/fragments/multi-v7/lpae.cfg"
                fi
            else
                echo "Cannot enable KVM host without LPAE"
            fi
            scripts/kconfig/merge_config.sh -m "${base_defconfig}" "${CPU_FRAGMENT}"  \
                $CWD/fragments/multi-v7/touch.cfg \
                $CWD/fragments/multi-v7/security.cfg \
                $CWD/fragments/multi-v7/power.cfg \
                $CWD/fragments/chromeos/wifi.config \
                $CWD/fragments/multi-v7/drm.cfg \
                $CWD/fragments/multi-v7/networking.cfg

    elif [ "$CB_SETUP_ARCH" == "arm64" ]; then
        scripts/kconfig/merge_config.sh -m arch/arm64/configs/defconfig \
            $CWD/fragments/arm64/chromebooks.cfg \
            $CWD/fragments/chromeos/wifi.config
    else
        scripts/kconfig/merge_config.sh -m arch/x86/configs/x86_64_defconfig \
            $CWD/fragments/x86_64/chromebooks.cfg \
            $CWD/fragments/chromeos/wifi.config
    fi

    make olddefconfig
    cd - > /dev/null

    echo "Done."
}

cmd_build_kernel()
{
    echo "Build kernel, modules and the device tree blobs..."

    local src_dir="${1-$KRNL_SRC_DIR}"

    cd $src_dir

    # Build kernel + modules + device tree blobs
    if [ "$CB_SETUP_ARCH" == "arm" ]; then
        # NOTE uImage is mainly only useful for snow/pi/pit
        # also, uImage needs to build zImage anyway...
        #LOADADDR="0x40008000" make uImage modules dtbs $(jopt)
        make zImage modules dtbs $(jopt)
    else
	    make $(jopt)
    fi

    create_fit_image

    if [ "$CB_SETUP_ARCH" == "arm" ]; then
        # we need a single dtb fit image for snow
        cp -v $CWD/tools/testing/kernel-snow.its \
            arch/arm/boot/kernel.its
        mkimage -f arch/arm/boot/kernel.its vmlinux.fit
        # and a small stub
        dd if=/dev/zero of=bootloader.bin bs=512 count=1
    fi
    cd - > /dev/null

    echo "Done."
}

cmd_deploy_kernel_modules()
{
    echo "Deploy the kernel modules on the rootfs..."

    local src_dir="${1-$KRNL_SRC_DIR}"

    cd $src_dir

    # Install the kernel modules on the rootfs
    sudo make modules_install INSTALL_MOD_PATH=$ROOTFS_DIR

    cd - > /dev/null

    echo "Done."
}

cmd_build_bootstub()
{
   echo "Build bootstub.efi..."

   cd bootstub

   make PREFIX=""

   cd - > /dev/null

   echo "Done."
}

cmd_build_vboot()
{
    local arch
    local bootloader
    local vmlinuz

    local src_dir="${1-$KRNL_SRC_DIR}"

    echo "Sign the kernels to boot with Chrome OS devices..."

    case "$CB_SETUP_ARCH" in
        arm|arm64)
            arch="arm"
            bootloader="boot_params"
            vmlinuz="${src_dir}/kernel.itb"
            ;;
        x86_64)
            arch="x86"
            bootloader="./bootstub/bootstub.efi"
            vmlinuz="${src_dir}/arch/x86/boot/bzImage"
            ;;
        *)
            echo "Unsupported vboot architecture"
	    exit 1
            ;;
    esac

    echo "root=PARTUUID=%U/PARTNROFF=1 rootwait rw console=tty0 noinitrd" > boot_params
    vbutil_kernel --pack $src_dir/kernel.vboot \
                       --keyblock /usr/share/vboot/devkeys/kernel.keyblock \
                       --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk \
                       --version 1 --config boot_params \
                       --bootloader $bootloader \
                       --vmlinuz $vmlinuz \
                       --arch $arch


    if [ "$CB_SETUP_ARCH" == "arm" ]; then
        # we also need a separate test image for snow manual install
        echo "root=PARTUUID=%U/PARTNROFF=1 rootwait rw console=tty0 noinitrd video=LVDS-1:1366x768" > boot_params
        vbutil_kernel --arch arm --pack $src_dir/vmlinux.kpart \
                           --keyblock /usr/share/vboot/devkeys/kernel.keyblock \
                           --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk \
                           --version 1 --config boot_params \
                           --bootloader $src_dir/bootloader.bin \
                           --vmlinuz $src_dir/vmlinux.fit
    fi

    echo "Done."
}

cmd_deploy_vboot()
{
    echo "Deploy vboot image on the boot partition..."

    local src_dir="${1-$KRNL_SRC_DIR}"

    if $storage_is_media_device; then
        find_partitions_by_id

        # Install it on the boot partition
        local boot="$CB_SETUP_STORAGE1"
        sudo dd if="$src_dir/kernel.vboot" of="$boot" bs=4M
    else
        if [ "$CB_SETUP_ARCH" != "x86_64" ]; then
            sudo cp -av "$src_dir/kernel.itb" "$ROOTFS_DIR/boot"
	else
            echo "WARNING: Not implemented for x86_64."
	fi
    fi

    echo "Done."
}

cmd_eject_storage()
{
    # Skip this command if is not a media device.
    if ! $storage_is_media_device; then return 0; fi

    echo "Ejecting storage device..."

    udisksctl unmount -b "$CB_SETUP_STORAGE2"
    udisksctl power-off -b "$CB_SETUP_STORAGE" > /dev/null 2>&1 || true

    if [[ -n $DO_GENTOO ]]; then
        echo "You will need to set a root passwd!!"
    fi

    echo "All done."
}

cmd_do_rootfs()
{
    cmd_format_storage
    cmd_mount_rootfs
    cmd_setup_rootfs $ALT_ROOTFS_URL
}

cmd_do_everything()
{
    cmd_format_storage
    cmd_mount_rootfs
    cmd_setup_rootfs $ALT_ROOTFS_URL
    cmd_get_toolchain
    if [[ -n $USE_KALI ]]; then
        cmd_get_kernel ${KALI_KERNEL_URL}
    else
        cmd_get_kernel
    fi
    cmd_config_kernel $KRNL_SRC_DIR
    cmd_build_kernel $KRNL_SRC_DIR
    cmd_deploy_kernel_modules $KRNL_SRC_DIR
    cmd_build_vboot $KRNL_SRC_DIR
    cmd_deploy_vboot $KRNL_SRC_DIR
    cmd_eject_storage
}

# -----------------------------------------------------------------------------
# Commands for development workflow

cmd_deploy_kernel()
{
    cmd_mount_rootfs
    cmd_build_kernel $KRNL_SRC_DIR
    cmd_deploy_kernel_modules $KRNL_SRC_DIR
    cmd_build_vboot $KRNL_SRC_DIR
    cmd_deploy_vboot $KRNL_SRC_DIR
    cmd_eject_storage
}

# These commands are required
ensure_command bc bc
ensure_command curl curl
ensure_command findmnt util-linux
ensure_command realpath realpath
ensure_command sgdisk gdisk
ensure_command lz4 lz4
ensure_command mkfs.ext4 e2fsprogs
ensure_command mkimage u-boot-tools
ensure_command udisksctl udisks2
ensure_command vbutil_kernel vboot-utils
ensure_command wget wget

# Run the command if it's valid, otherwise abort
type cmd_$cmd > /dev/null 2>&1 || print_usage_exit
cmd_$cmd $@

exit 0
