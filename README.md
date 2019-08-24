# Chromebook developer tool
These instructions will create a dual-booting environment where you can
switch between booting Debian and the stock ChromeOS. No changes are made
to the internal eMMC drive, and your new Debian install will run
completely from external storage. This is the recommended setup for those
that just want to take a test drive, or don't want to give up ChromeOS.

You must be running the latest ChromeOS prior to installation.

The following Chromebooks have been tested with this tool.
- ASUS Chromebook Flip C100PA (C100PA - arm/lpae)
- CTL J2 Chromebook for Education (NBCJ2 - arm)
- Acer CB5-311 Chromebook 13, 2GB (CB5-311 - arm/lpae)
- Acer C810-T78Y Chromebook 13, 4GB (C810-T78Y - arm/lpae)
- Samsung Chromebook Plus (XE513C24 - arm64)

## Switch to developer mode
1. Turn off the laptop.
2. To invoke Recovery mode, you hold down the ESC and Refresh keys and
   poke the Power button.
3. At the Recovery screen press Ctrl-D (there's no prompt - you have to
   know to do it).
4. Confirm switching to developer mode by pressing enter, and the laptop
   will reboot and reset the system. This takes about 10-15 minutes.

Note: After enabling developer mode, you will need to press Ctrl-D each
      time you boot, or wait 30 seconds to continue booting.

## Enable booting from external storage
1. After booting into developer mode, hold Ctrl and Alt and poke the F2
   key. This will open up the developer console.
2. Type root to the login screen.
3. Then type this to enable USB booting:
```sh
$ enable_dev_usb_boot
```
4. Reboot the system to allow the change to take effect.

## Create a USB or SD for dual booting
```sh
$ ./chromebook-setup.sh help
```
For example, to create bootable SD card for the Samsung Chromebook Plus (arm64):
```sh
$ ./chromebook-setup.sh do_everything --architecture=arm64 --storage=/dev/sdX
```

## Enable LPAE for arm chromebooks (eg, nyan-big)
```
$ USE_LPAE=1 ./chromebook-setup.sh do_everything --architecture=arm --storage=/dev/sdX
```

## Select a minimal Debian release or latest Ubuntu LTS release
```
$ DO_BIONIC=1 USE_LPAE=1 ./chromebook-setup.sh do_everything --architecture=arm --storage=/dev/mmcblkX
```

Note the above minimal debian/ubuntu roots are console only, but you are free
to install the desktop of your choice (see the comments in the two main script
files for more info).  You may select from stretch, buster, or bionic.

## Appendix
### How to enable wireless/bluetooth in a console image
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

Click on the architecture you installed, ie, either arm, arm64, or x86_64.

Browse the debian mirros and pick one (eg, http.us.debian.org) and download
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
# sudo rfkill list
```
If you see ``Soft blocked: yes`` for the Wireless LAN device, then run:
```sh
# sudo rfkill unblock wifi
# sudo rfkill unblock all
```
Then reboot and run ``sudo rfkill list`` again to make sure the soft block
was removed.  NOW you can configure the access point and psk.

Second:

To connect to an open AP, run the following commands, otherwise run the
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
If the connection fails, try rebooting and/or moving closer to the AP. Once
you have a connection, use the ``iwconfig`` command to check signal level and
link quality.


### How to create a Debian image for Chromebooks
You can build the Chromebook image for a specific suite and architecture
like this:
```sh
$ debos -t arch:"arm64" debos/images/lxde-desktop/debimage.yaml
```
The images can be built for different architectures (supported architectures
are armhf, arm64 and amd64)

## References:

https://wiki.archlinux.org/index.php/ConnMan
https://www.erdahl.io/2016/04/configuring-wifi-on-beagleboardorg.html
