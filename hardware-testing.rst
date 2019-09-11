===========================
 Chromebook Kernel Testing
===========================

This is the result of testing on available hardware with various distros and
recent kernel versions (mainly 5.2.x and 5.3.x).  The default (debian sid)
had boot issues, so alternate/minimal rootfs options were added for testing.

* rootfs sources

  - gentoo mirrors / releases, experimental
  - eewiki arm debian / ubuntu releases

* script distro options tested

  - gentoo glibc or musl-hardened (arm, arm64)
  - ubuntu bionic (arm)
  - debian stretch/buster (arm)


What Does Work
--------------

* all models, except as noted below

  - usb 2/3 (firmware requirements vary)
  - wifi/bt (firmware requirements vary)
  - input devices (switches/keyboard/trackpad/touch)
  - battery/power status, clocks/thermal/cpufreq
  - hdmi and panel EDID display detection
  - drm and framebuffer display (console and xorg modesetting)
  - mainline gpu acceleration (drm/xorg/mesa)

    + requires latest xorg/mesa/libdrm/kernel
    + libdrm/mesa video cards (tegra/nouveau/lima/panfrost/exynos)
    + xorg modesetting driver (may need conf snippets)
    + dts patches for some models (eg, snow)

  - boots "standard" signed developer kernel
  - single multi_v7 kernel config for all armv7 devices


What Doesn't Work
-----------------

* snow rev 4

  - only boots from single-dtb kernel image
  - EDID panel resolution detection fails, no display without forcing 1366x768

* nyan-big - power button shutdown


Results
=======

Latest test results should be added to the top.


.. list-table::
   :widths: 12 14 10 33
   :header-rows: 1

   * - Kernel
     - Model
     - Image
     - Notes
   * - 5.3.0-rc6
     - nyan-big
     - default
     - works: console, wifi/usb (needs firmware), drm
   * - 5.3.0-rc6
     - veyron-minnie
     - default
     - works: console, wifi/usb (needs firmware), drm
   * - 5.3.0-rc6
     - snow (rev 4)
     - single
     - works: mostly everything but panel edid (force 1366x768)
   * - 5.3.0-rc6
     - kevin
     - default
     - works: mostly everything but xorg/drm/modesetting (needs
       more kernel testing)
