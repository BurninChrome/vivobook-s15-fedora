# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Releases are tagged `vYYYY.MM.N`. The kernel package is versioned separately
(`kernel-vivobook`, see [packaging/kernel/README.md](packaging/kernel/README.md)).

## [Unreleased]

### Added
- **Fedora Silverblue 45** as the main target: `image/` builds a local
  bootable container image (`Containerfile`, `build.sh --switch`,
  `fetch-local.sh`, `build-kernel.sh`, `kargs.d`, kickstart) with the patched
  kernel, the stubble UKI from `kernel-uki-dtbloader` as
  `/usr/lib/modules/<kver>/vmlinuz` with the overlay merged in, firmware, UCM,
  suspend, Wi-Fi watchdog, Plymouth theme and Howdy. Updates and rollback go
  through `bootc`. Installation: `docs/install.md`; the Workstation guide moved
  to `docs/install-workstation.md`.
- `apply-dtb` handles the ostree layout (`/usr/lib/modules/<kver>/vmlinuz`,
  plus `devicetree`) and refuses to touch a booted read-only image;
  `patch-vmlinuz-dtb.py --no-backup`.
- `install-howdy.sh image`, `plymouth/install.sh --image` for the image build;
  the userspace scripts that change `/usr` refuse to run on a booted image.
- `tools/selftest.sh` checks the booted image and its kernel arguments.
- CI builds the image (stock kernel, no firmware).
- `modules-load/vivobook-s15-cpufreq.conf`: loads `scmi-cpufreq`, which has
  no modalias; without it the CPU cores never change frequency.
- Suspend (s2idle) with the experimental EC driver: patch 0411 (the Tj feed
  always restarts on resume, retries for modern standby enter/exit) and
  `userspace/suspend` (`allow_suspend=1`, s2idle). Tested: 12 suspends up to
  4 minutes, lid/keyboard/touchpad/power button wake, no EC reset.

### Changed
- Kernel: patches 0601-0604 revert the pm_clk conversion of the LPASS
  WSA/RX/TX/VA macros, fixing the 7.3 SoundWire regression (no sound after
  runtime resume). The udev workaround now applies only to kernels without
  them.
- EC (experimental): SoC Tj is averaged over all three CPU clusters
  (33 tsens zones instead of 26); patch 0410 adds `tj_use_max` to report the
  hottest zone instead. Under a 240 s all-core load the fans reach about
  6000 RPM and the cores stay at 88-92 C.


### Added
- Device tree overlay fragments: audio (WSA8845, WCD9385, DMIC), front camera
  (OV02C10), IR camera (HM1092 with IR LED); EC (`qcom-hamoa-ec`) as an
  opt-in experimental fragment (`EXPERIMENTAL_EC=yes`).
- kernel-install hook that applies the overlay to the DTB inside the UKI,
  `Makefile` for installing without packages, RPM spec for COPR.
- ALSA UCM profile with speakers, headphones and microphones; udev workaround
  for the LPASS runtime PM regression in 7.3.
- Kernel patch series for 7.3 (CCI power-on, HM1092, ASUS EC HID, EC fan
  control, PS883x DP pin F) and `packaging/kernel/prepare-srpm.sh`.
- Tools: `fetch-firmware.sh`, `selftest.sh`, `collect-hwinfo.sh`,
  `scan-private.sh`, `set-identity.sh`.
- Userspace: WirePlumber camera rule and OV02C10 gain helper, Howdy with the
  IR camera, HID-BPF keyboard alternative, Wi-Fi watchdog, Plymouth theme
  (logo extracted locally), boot time fixes.
