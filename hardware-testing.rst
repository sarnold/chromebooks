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

Results
=======

.. list-table::
   :widths: 9 11 9 33
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
   * 5.3.0-rc6
     - kevin
     - default
     - works: mostly everything but xorg/drm/modesetting (needs
       more kernel testing)
