# Linux on Chromebook user/developer tool
These instructions will create a bootable environment on sdcard or USB
stick where you can switch between booting Linux and the stock ChromeOS.
No changes are made to the internal eMMC drive, and your new Linux install
will run completely from external storage. This is the recommended setup
for those that just want to take a test drive, or don't want to give up
ChromeOS.

By default this version will install either the upstream Debian sid
or Gentoo rootfs tarballs on all supported architectures, with the
additional option of minimal Debian stretch/buster or Ubuntu bionic
console installs on arm only (from which you can easily install your
favorite desktop, eg, ``lubuntu-desktop``).

You must be running the latest ChromeOS prior to installation.

The following Chromebooks have been tested with this tool.
- Samsung Chromebook XE303C12 (snow - arm/lpae)
- ASUS Chromebook Flip C100PA (veyron-minnie - arm/lpae)
- CTL J2 Chromebook for Education (veyron-jerry - arm/lpae)
- Acer CB5-311 Chromebook 13, 2GB (nyan-big - arm/lpae)
- Acer C810-T78Y Chromebook 13, 4GB (nyan-big - arm/lpae)
- Samsung Chromebook Plus (kevin - arm64)

## Switch to developer mode - NOTE this will reset your chromebook device!!
1. Turn off the laptop.
2. To invoke Recovery mode, you hold down the ESC and Refresh keys and
   poke the Power button.
3. At the Recovery screen press Ctrl-D (there's no prompt - you have to
   know to do it).
4. Confirm switching to developer mode by pressing enter, and the laptop
   will reboot and reset the system. This takes about 10-15 minutes.

Note: After enabling developer mode, you will need to press Ctrl-D each
      time you boot, or wait 30 seconds to continue booting ChromeOS.

## Enable booting from external storage
1. After booting into developer mode, at the login screen hold Ctrl and Alt
   and poke the F2 (right arrow) key. This will open up the developer console.
2. Type ``chronos`` at the login screen and sudo to root (hint: read the prompt
   and set a user password after sudo-ing).
3. Then type this to enable USB booting:
```sh
# enable_dev_usb_boot
```
4. Reboot the system to allow the change to take effect. Now you can use
   Ctrl-U to boot from external media, or Ctrl-D to boot from emmc.

## Create a USB or SD for dual booting
```sh
$ ./chromebook-setup.sh help
```
For example, to create a bootable SD card for the Samsung Chromebook
Plus (arm64) with Debian sid:
```sh
$ ./chromebook-setup.sh do_everything --architecture=arm64 --storage=/dev/sdX
```

## Enable virtualization for arm chromebooks (eg, nyan-big) if
   allowed by the firmware:
```sh
$ ENABLE_HYP=1 ./chromebook-setup.sh do_everything --architecture=arm --storage=/dev/sdX
```

## Select a minimal Ubuntu LTS release using an mmc card device:
```sh
$ DO_BIONIC=1 ./chromebook-setup.sh do_everything --architecture=arm --storage=/dev/mmcblkX
```

Note: The above minimal debian/ubuntu roots are console only, but you are
      free to install the desktop of your choice (see the comments in the
      two main script files for more info).  You may select from stretch,
      buster, or bionic. After connecting, do ``sudo apt-get update/upgrade``
      and then try ``sudo apt-get install xubuntu-desktop`` on bionic.

## Select an even more minimal Gentoo stage (either musl or glibc)
```sh
$ DO_GENTOO=1 USE_LIBC=musl ./chromebook-setup.sh do_everything --architecture=arm --storage=/dev/sdX
```

## Note about ethernet
If your device has wired ethernet (including USB) *and* you're using one
of the cloud image variants then you can enable the alternate cloud image
config with `HAVE_ETHERNET=1` on the cmdline:

```sh
$ DO_BIONIC=1 HAVE_ETHERNET=1 ./chromebook-setup.sh do_everything --architecture=arm64 --storage=/dev/sdX
```

## Note about logins
The minimal Debian/Ubuntu rootfs user logins are displayed on the console
prompt: ``[debian|ubuntu]:temppwd``. The Gentoo stage3/4 tarballs have no
user yet, so the root passwd has been blanked. The Ubuntu Cloud images
(currently arm64 only) also use the above `[ubuntu]:temppwd`` login.
The default Debian rootfs never booted properly for me, so I don't know
what the login details are (you'll need to mount your boot device and
inspect/edit the shadow file yourself).

## Note about signed kernel images
Both armv7 and arm64 devices require the proper device tree blobs in the
signed kernel.fit image that goes into the chromeos kernel partition. This
is normally the .dtb file for the target device, however the default arm
kernel image contains the .dtb blobs for all supported chromebook devices.
This works fine on everything except the original samsung chromebook (snow)
so we also build a separate signed kernel image for the snow chromebook
with only the single blob.  If you have a snow chromebook you'll need to
manually ``dd`` the image to the first partition on the sdcard or usb
stick (see below).

The kernel image artifacts are in the top level of the kernel source
tree:
- kernel.vboot - default (signed) kernel image
- vmlinux.kpart - signed kernel image for snow

For chromebook snow, wait for the script to complete and then manually
re-insert the boot device and verify the device name again (eg, ``/dev/sdb``),
then run the following command:
```sh
$ sudo dd if=linux-stable/vmlinux.kpart of=/dev/sdX1 bs=4M
```
Replace ``sdX`` with your device and adjust the directory name as needed.

## Appendix
### How to bootstrap a Gentoo stage install
If you choose a Gentoo stage, it will pull the latest (as of this writing)
hardened glibc or musl stage3/4 (depending on what is available).  The
stage3 tarballs *do* have ``rfkill`` but *do not* have any firmware or
wpa_supplicant. The quick-and-dirty firmware answer is just copy ``/lib/firmware``
from your host to the target rootfs (the second partition).  This will make
USB devices work on tegra, however, you will need to build ``wpa_supplicant``
by hand if you need wifi to continue with the install (which is a total PITA).
Much easier to spend a few bucks on a USB ethernet adapter...

See the default stage settings in the ``chromebook-config.sh`` script.
You may need to pre-build firmware/wifi support in a chroot first and
create your own stage4 tarball; just update the config script with the
name of your stage4 file and drop it in this directory before running
the setup script.

### How to bootstrap Ubuntu Touch install

Build your chromebook boot device with DO_TOUCH=1 then re-insert and mount
your boot media; this may or may not boot correctly, so the "safe" approach
is to make two boot devices (one sdcard and one USB stick) using the Touch
tarball for one, and one of the other targets (Ubuntu or Debian) for the
second device.  Use the second device to boot your chromebook and then
chroot into your Ubuntu Touch rootfs.

Since the Touch rootfs is not quite ready to boot fully, follow the
post-install steps to complete the config in your chroot; note you may
need to copy /etc/resolv.conf to your chroot first.  You will also need
to clone the ubports rootfs-builder repo from gitlab and move the repo
to root's $HOME dir on the Touch rootfs:
```sh
$ git clone https://gitlab.com/ubports/core/rootfs-builder-debos.git
```
Enter the chroot, then:

1. Fix the TERM environment var:
```sh
# export TERM=xterm-256color
```
2. Restore the ``_apt`` user:
```sh
# adduser _apt --force-badname --system --no-create-home --disabled-password --disabled-login
```
3. Set default user password:
```sh
# echo phablet:phablet | chpasswd
```
4. Change to the rootfs-builder source tree:
```
# cd ~/rootfs-builder-debos
```
Copy the contents under mods-overlay/ to the right places in the rootfs:
```sh
$ tree -A rootfs-builder-debos/mods-overlay/
rootfs-builder-debos/mods-overlay/
├── etc
│   └── init
│       ├── repowerd.override
│       ├── ssh-keygen.conf
│       └── ttyS0.conf
└── usr
    └── bin
        └── ssh-keygen.sh
```
5. Run the (generic armhf) setup scripts from the rootfs-builder tree:
```sh
# scripts/add-mainline-repos.sh
# scripts/enable-mesa.sh
```
6. Refresh the kernel module dependencies; use the directory name from
   your install under ``/lib/modules``:
```
# depmod -a 5.3.0-00001-gc094c373f029
```
6. Install the linux-firmware package:
```sh
# dpkg -i files/linux-firmware_1.182_all.deb
```
7. Exit the chroot, power off and remove your (chroot) boot device, then
   power it back up and wait for the Ubuntu Touch setup wizard.  Enjoy!

### How to enable wireless/bluetooth in a debian/ubuntu console image
If you choose one of the minimal rootfs options, the default state of both
wifi and bluetooth is "soft blocked".  The default networking tool is also
connman (as opposed to NetworkManager or the basic net scripts) so setting
a manual static config in ``/etc/network/interfaces`` will not work.  The
default connman settings are in ``/var/lib/connman/settings`` but only
wired ethernet is enabled out of the box.

If you have a USB ethernet adapter, try it and use it to update the packages
and install ``rfkill``.  If you don't have a USB ethernet adapter, then you
will need to manually enable wifi as shown below.

Steps:

* download the rfkill deb pkg for your architecture and release
* copy the deb pkg to your sdcard or USB stick
* boot the chromebook and install the rfkill deb pkg
* manually run rfkill and then connmanctl to configure wifi

*If* your chromebook is veyron-minnie/jerry then you will also need to download
some new firmware files *before* configuring wifi (otherwise skip this part).
The Arch Linux packaging host has the files available for their veyron-firmware
package:

https://archlinuxarm.org/builder/src/veyron/

Download the two files for 4354-sdio:

```
../
99-veyron-brcm.rules                               01-Jul-2015 04:31                 330
BCM4354_003.001.012.0306.0659.hcd                  01-Jul-2015 04:31               72132
brcmfmac4354-sdio.bin                              30-Oct-2016 23:15              507752
brcmfmac4354-sdio.txt                              30-Oct-2016 23:15                2722
sd8787_uapsta_cros.bin                             26-Jun-2015 02:37              411888
sd8797_uapsta_cros.bin                             26-Jun-2015 02:37              460440
sd8897_uapsta_cros.bin                             26-Jun-2015 02:37              741240

```

and copy ``brcmfmac4354-sdio.*`` to ``/lib/firmware/brcm/``:
```sh
$ wget https://archlinuxarm.org/builder/src/veyron/brcmfmac4354-sdio.bin
$ wget https://archlinuxarm.org/builder/src/veyron/brcmfmac4354-sdio.txt
$ sudo cp -v brcmfmac4354-sdio.* /media/rootfs/lib/firmware/brcm/
```
(assuming you have mounted your stick/card to ``/media/rootfs``)

If not veyron, start here.

First:

Go to the debian/ubuntu package page for rfkill; in this example we use
debian buster:  https://packages.debian.org/buster/rfkill

For ubuntu, start here
ubuntu bionic:  https://launchpad.net/ubuntu/bionic/armhf/rfkill/2.31.1-0.4ubuntu3

Click on the architecture you installed, ie, either armhf, arm64, or x86_64.

Browse the debian mirrors and pick one (eg, http.us.debian.org) and download
the rfkill deb package:
```sh
$ wget http://http.us.debian.org/debian/pool/main/u/util-linux/rfkill_2.33.1-0.1_armhf.deb
```
Copy it to your sdcard/stick, boot up your chromebook, and install it:
```sh
$ sudo dpkg -i rfkill_2.33.1-0.1_armhf.deb
```
To see the state, run:
```sh
$ sudo rfkill list
```
If you see ``Soft blocked: yes`` for the Wireless LAN device, then run:
```sh
$ sudo rfkill unblock wifi
$ sudo rfkill unblock all
```
Then reboot and run ``sudo rfkill list`` again to make sure the soft block
was removed.  NOW you can configure the access point and psk.

Second:

To connect to an open AP, see the Arch wiki section, otherwise run the
interactive connmanctl shell to configure access.  See the Arch Linux wiki
for more details.

To setup WPA/PSK we need to run some commands in the actual connmanctl shell;
depending on the distro, it may or may not require sudo to run connmanctl
(feel free to try it first without sudo).  Now run the command with no
arguments:
```sh
$ connmanctl
```
First verify tethering status.  Tethering must be disabled to be associated
with an access point:
```sh
connmanctl> tether wifi off
Disabled tethering for wifi
```
Now scan for access points and display services found:
```sh
connmanctl> scan wifi
Scan completed for wifi
connmanctl> services
    MyAccessPoint           wifi_abc_managed_psk
```
Now connect to the access point, then quit:
```sh
connmanctl> agent on
Agent registered
connmanctl> connect wifi_abc_managed_psk
Agent RequestInput wifi_abc_managed_psk
  Passphrase = [ Type=psk, Requirement=mandatory, Alternates=[ WPS ] ]
  WPS = [ Type=wpspin, Requirement=alternate ]
Passphrase? passphrase
Connected wifi_abc_managed_psk
connmanctl> quit
```
(note you can use tab-complete on the long service name)

If the connection fails, try rebooting and/or moving closer to the AP. Once
you have a connection, use the ``iwconfig`` command to check signal level and
link quality.

### Note about wifi on Ubuntu Touch
For a bootstrap install of Ubuntu Touch on veyron-minnie, the process to
enable wifi is slightly different than shown above.  After the rfkill
step to release the wifi soft block, use the ``nmcli`` tool instead of
``connmanctl``.  Open a terminal and do:
```sh
$ sudo nmcli radio wifi on
```
Check the new state with:
```sh
$ sudo nmcli radio
```
Then open the Settings app and look for your local wifi AP.

### How to create a Debian image for Chromebooks
You can build the Chromebook image for a specific suite and architecture
like this:
```sh
$ debos -t arch:"arm64" debos/images/lxde-desktop/debimage.yaml
```
The images can be built for different architectures (supported architectures
are armhf, arm64 and amd64).

## References:

Gentoo Embedded:

https://wiki.gentoo.org/wiki/Embedded_Handbook
https://wiki.gentoo.org/wiki/Embedded_systems

Ubuntu Touch:

https://github.com/ubports/unity8
https://gitlab.com/ubports/core/rootfs-builder-debos/tree/master

Wifi Setup:

https://wiki.archlinux.org/index.php/ConnMan
https://www.erdahl.io/2016/04/configuring-wifi-on-beagleboardorg.html
