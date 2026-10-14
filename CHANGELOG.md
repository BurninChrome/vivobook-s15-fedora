# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Releases are tagged `vYYYY.MM.N`. The kernel package is versioned separately
(`kernel-vivobook`, see [packaging/kernel/README.md](packaging/kernel/README.md)).

## [Unreleased]

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
