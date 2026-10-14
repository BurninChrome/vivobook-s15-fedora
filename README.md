# Fedora on the ASUS Vivobook S 15 (S5507QAD, Snapdragon X Elite)

Device tree additions, kernel patches, packaging and tools that make
**Fedora 45 aarch64** usable as a daily system on the
**ASUS Vivobook S 15 S5507QAD** (Snapdragon X Elite X1E-78-100, "Hamoa", `x1e80100`).

> **Unofficial community project.** Not affiliated with or endorsed by ASUS,
> Qualcomm or the Fedora Project. Everything here changes how your laptop boots
> and talks to its embedded controller. Read [Warnings](#warnings) first.

<!-- Identity tokens (BurninChrome etc.) are set in identity.conf, see tools/set-identity.sh. -->

## Status

Tested on S5507QAD, BIOS `S5507QAD.367`, Fedora 45, kernel `7.3.0` with the
patches from [`kernel/patches/`](kernel/patches/).

| Feature | State | Needs | Notes |
|---|---|---|---|
| Battery and charging | works | firmware ([docs/firmware.md](docs/firmware.md)) | ADSP firmware signed for QAD |
| Speakers, headphones | works | overlay `10-audio`, UCM | see [Known issues](#known-issues) for 7.3 |
| Internal and headset microphones | works | overlay `10-audio`, UCM | |
| Keyboard Fn keys, backlight, Fn-lock | works | kernel patch `hid-asus-ec` (or HID-BPF) | |
| Front camera (OV02C10) | works | patched kernel (CCI fix), overlay `20-camera-rgb`, libcamera, WirePlumber rule | image rotated 180° in DT |
| IR camera (HM1092) + IR LED, Howdy | works | kernel patches, overlay `30-camera-ir`, Howdy patch | face unlock for sudo and GDM |
| Fan control via EC (`qcom-hamoa-ec`) | experimental, off by default | kernel patches, `EXPERIMENTAL_EC=yes` | **read [docs/ec-fan-control.md](docs/ec-fan-control.md)** |
| Suspend (s2idle) | in testing | kernel 7.3 | blocked while the EC driver feeds Tj |
| Wi-Fi (WCN7850, ath12k) | works, with watchdog | `userspace/wifi` | rare data path stall on 7.3, see docs |
| Bluetooth, GPU | works | firmware | |
| Hardware video decode (iris) | works | firmware, patched kernel (video clock controller) | |
| HDMI, DisplayPort over USB-C | not verified | | help wanted |
| microSD reader (GL835) | not verified | | |
| TPM | not available | upstream `tpm_qcom` driver | |

## Supported hardware

| Model | SoC | Status |
|---|---|---|
| S5507QAD | X1E-78-100 | tested |
| S5507QA | X1E-78-100 | probably works, firmware variant unknown, reports welcome |
| Vivobook S 15 with X1P-42-100 (Purwa) | X1P-42-100 | not supported here (different DT in mainline) |

Please report your model and BIOS version with the
[hardware report form](../../issues/new?template=hardware-report.yml). See
[HARDWARE.md](HARDWARE.md) for the full matrix.

## Warnings

- **Embedded controller.** With the EC driver loaded, the EC expects a steady
  stream of SoC temperature (Tj) readings. If the stream stops, the fans go to
  full speed after about 70 s and the EC **hard resets the laptop** after about
  130-210 s. The patched driver never stops feeding it, but do not unload the
  module by hand. Details: [docs/ec-fan-control.md](docs/ec-fan-control.md).
- **Device tree inside the kernel image.** Fedora boots this laptop through a
  UKI with `.dtbauto` sections (stubble). GRUB's `devicetree` command is ignored.
  The kernel-install hook in [`hooks/`](hooks/) merges the overlay into the DTB
  and writes it back into `/boot/vmlinuz-<version>`. Keep a stock kernel entry
  in GRUB as a fallback.
- **Firmware is not included.** ASUS/Qualcomm firmware may not be
  redistributed. Use [`tools/fetch-firmware.sh`](tools/fetch-firmware.sh)
  (downloads the official ASUS package) or `qcom-firmware-extract` (copies it
  from a Windows partition).
- **Secure Boot** must be disabled for the custom kernel (it is not signed).
- Keep a Fedora live USB at hand.

## Installation

Short version (details in [docs/install.md](docs/install.md)):

```bash
# 1. Firmware (no root needed for this step)
tools/fetch-firmware.sh
sudo install -D -m 0644 -t /usr/lib/firmware/updates/qcom/x1e80100/ASUSTeK/vivobook-s15/ firmware-out/*

# 2. Support package: overlay, kernel-install hook, UCM, udev and WirePlumber rules
sudo dnf copr enable BurninChrome/vivobook-s15       # planned
sudo dnf install vivobook-s15-support
#    or from this repository: make && sudo make install && sudo make apply

# 3. Kernel with the patches from kernel/patches/
sudo dnf install kernel-vivobook                # planned, same COPR

# 4. Reboot, then run the self-test
tools/selftest.sh
```

Until the COPR exists, [docs/install.md](docs/install.md) explains the manual
installation from this repository.

## Repository layout

| Path | Content |
|---|---|
| [`overlay/`](overlay/) | device tree overlay, built from `fragments/NN-*.dtsi` (`fragments/experimental/` opt-in) |
| [`hooks/`](hooks/) | kernel-install hook that applies the overlay to the DTB inside the UKI, UCM helper, `/etc/vivobook-s15.conf` |
| [`udev/`](udev/) | LPASS runtime PM workaround for 7.3 kernels |
| [`ucm/`](ucm/) | ALSA UCM profile (to be upstreamed to alsa-ucm-conf) |
| [`kernel/`](kernel/) | patch series, kernel config fragment, upstream status of each patch |
| [`userspace/`](userspace/) | camera, Howdy, keyboard, Wi-Fi watchdog, Plymouth theme, boot time tweaks |
| [`packaging/`](packaging/) | RPM spec files for COPR |
| [`tools/`](tools/) | firmware download, self-test, hardware report, privacy scan, identity setup |
| `Makefile`, `identity.conf` | build/install without packages; the one place for owner and author names |
| [`docs/`](docs/) | installation, firmware, DTB delivery, EC, upstream status, troubleshooting |

## Known issues

See [docs/troubleshooting.md](docs/troubleshooting.md). The list of open
problems is tracked in the issue tracker.

## Upstream

The goal is to make this repository unnecessary. Status of every piece:
[docs/upstream.md](docs/upstream.md).

## Contributing

Bug reports, hardware reports and pull requests are welcome. Please read
[CONTRIBUTING.md](CONTRIBUTING.md), and **never attach unredacted logs**:
run `tools/collect-hwinfo.sh`, which removes serial numbers, MAC addresses,
network names and user names.

## Licenses

Multiple licenses apply, see [LICENSES/](LICENSES/) and the SPDX header in
each file:

- kernel patches and modules: GPL-2.0-only (or the license stated in the patch),
- device tree fragments: BSD-3-Clause (same as the upstream machine DTS),
- scripts, hooks, packaging and documentation: MIT,
- ALSA UCM profile: MIT (based on bingo1991's profile; compatible with alsa-ucm-conf's BSD-3-Clause),
- third-party files keep their original license and authorship.

No firmware, BIOS images, Windows drivers or ACPI tables are distributed.

## Credits

This work builds on, among others:
[bingo1991/qcom-x1e-vivobook-s15](https://github.com/bingo1991/qcom-x1e-vivobook-s15)
(audio bring-up, DTB delivery into the UKI),
[HurlyDesousa/linux-aarch64-vivobook](https://github.com/HurlyDesousa/linux-aarch64-vivobook)
(CCI power-on fix),
Anvesh Jain P (Qualcomm EC driver series),
Ramshouriesh R (HM1092 driver),
Alexandru Marc Serdeliuc (ASUS EC HID driver for the Zenbook A14),
Icecream95 (HID-BPF program for this keyboard),
Jens Glathe (PS883x retimer fixes, Vivobook S15 DT work),
Nicolas Derumigny (Zenbook A14 / Vivobook S15 EC research),
[alexVinarskis/qcom-aeob-dumps](https://github.com/alexVinarskis/qcom-aeob-dumps),
and the `#aarch64-laptops` community.
Full list with commits and links: [docs/credits.md](docs/credits.md).
