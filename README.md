# Fedora on the ASUS Vivobook S 15 (S5507QAD, Snapdragon X Elite)

Device tree additions, kernel patches, a bootable container image and tools
that make **Fedora Silverblue 45 aarch64** usable as a daily system on the
**ASUS Vivobook S 15 S5507QAD** (Snapdragon X Elite X1E-78-100, "Hamoa", `x1e80100`).

> **Unofficial community project.** Not affiliated with or endorsed by ASUS,
> Qualcomm or the Fedora Project. Everything here changes how your laptop boots
> and talks to its embedded controller. Read [Warnings](#warnings) first.

<!-- Owner and author names come from identity.conf (tools/set-identity.sh). -->

## Status

Tested on S5507QAD, BIOS `S5507QAD.367`, Fedora Silverblue 45 (image built
with [`image/`](image/)), kernel `7.3.0` with the patches from
[`kernel/patches/`](kernel/patches/). The same pieces also work on a mutable
Fedora Workstation 45 ([docs/install-workstation.md](docs/install-workstation.md)).

| Feature | State | Needs | Notes |
|---|---|---|---|
| Battery and charging | works | firmware ([docs/firmware.md](docs/firmware.md)) | ADSP firmware signed for QAD |
| Speakers, headphones | works | overlay `10-audio`, UCM | see [Known issues](#known-issues) for 7.3 |
| Internal and headset microphones | works | overlay `10-audio`, UCM | |
| Keyboard Fn keys, backlight, Fn-lock | works | kernel patch `hid-asus-ec` (or HID-BPF) | |
| Front camera (OV02C10) | works | patched kernel (CCI fix), overlay `20-camera-rgb`, libcamera, WirePlumber rule | image rotated 180° in DT |
| IR camera (HM1092) + IR LED, Howdy | works | kernel patches, overlay `30-camera-ir`, Howdy patch | face unlock for sudo and GDM |
| Fan control via EC (`qcom-hamoa-ec`) | experimental, off by default | kernel patches, `EXPERIMENTAL_EC=yes` | **read [docs/ec-fan-control.md](docs/ec-fan-control.md)** |
| Suspend (s2idle) | works | kernel 7.3; with the EC driver patches 0401-0411 and [`userspace/suspend`](userspace/suspend/) | lid, keyboard, touchpad, power button wake; battery drain not measured yet |
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
  The image build merges the overlay into the DTB inside
  `/usr/lib/modules/<version>/vmlinuz` ([docs/dtb-delivery.md](docs/dtb-delivery.md)).
  The previous deployment stays in GRUB as a fallback (`bootc rollback`).
- **Firmware is not included.** ASUS/Qualcomm firmware may not be
  redistributed. [`image/fetch-local.sh`](image/fetch-local.sh) downloads the
  official ASUS package and extracts it locally; the image built from it is for
  your laptop only and must not be pushed to a public registry.
- **Secure Boot** must be disabled for the custom kernel (it is not signed).
- Keep a Fedora live USB at hand.

## Installation

Short version, starting from a stock Fedora Silverblue 45 aarch64 installation
(details in [docs/install.md](docs/install.md), image internals in
[image/README.md](image/README.md)):

```bash
git clone https://github.com/BurninChrome/vivobook-s15-fedora && cd vivobook-s15-fedora

# 1. Firmware and boot logo into image/local/ (no root, runs in a Fedora container)
image/fetch-local.sh

# 2. Kernel with the patches from kernel/patches/ (no root, several hours;
#    later: the RPMs from COPR, planned)
image/build-kernel.sh

# 3. Build the image and switch to it
sudo image/build.sh --switch
systemctl reboot

# 4. Self-test
tools/selftest.sh
```

Updates: `git pull && sudo image/build.sh --switch`, then reboot.

## Repository layout

| Path | Content |
|---|---|
| [`overlay/`](overlay/) | device tree overlay, built from `fragments/NN-*.dtsi` (`fragments/experimental/` opt-in) |
| [`image/`](image/) | Silverblue image: `Containerfile`, build and switch scripts, kernel arguments, kickstart |
| [`hooks/`](hooks/) | `apply-dtb` (overlay into the DTB inside the UKI), UCM helper, kernel-install hook (Workstation), `/etc/vivobook-s15.conf` |
| [`udev/`](udev/) | LPASS runtime PM workaround for 7.3 kernels |
| [`ucm/`](ucm/) | ALSA UCM profile (to be upstreamed to alsa-ucm-conf) |
| [`kernel/`](kernel/) | patch series, kernel config fragment, upstream status of each patch |
| [`userspace/`](userspace/) | camera, Howdy, keyboard, Wi-Fi watchdog, Plymouth theme, boot time tweaks |
| [`packaging/`](packaging/) | RPM spec files for COPR (kernel RPMs also feed the image) |
| [`tools/`](tools/) | firmware download, self-test, hardware report, privacy scan, identity setup |
| `Makefile`, `identity.conf` | build/install without packages (also used by the image build); the one place for owner and author names |
| [`docs/`](docs/) | installation (Silverblue, Workstation), firmware, DTB delivery, EC, upstream status, troubleshooting |

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
