# Upstream status

Goal: everything here should end up in the upstream projects, so that a stock
Fedora works on this laptop. Before sending anything, search
[lore.kernel.org](https://lore.kernel.org/) so that nothing is posted twice.
Last checked: 2026-10-14.

## Linux kernel

| Item | Our file | Upstream state | Next step | Who |
|---|---|---|---|---|
| Machine DT `x1e80100-asus-vivobook-s15.dts`, `x1-asus-vivobook-s15.dtsi` | | mainline (common dtsi and Purwa variant by Jens Glathe, applied by Bjorn Andersson 2026-02-27) | | |
| Audio nodes (WSA8845, WCD9385, DMIC) | `overlay/fragments/10-audio.dtsi` | posted by Elliot Huang ("arm64: dts: qcom: support sound on Asus Vivobook S15", LKML 2025-06-02), not merged; our microphone routing follows it | reply in that thread with test results, or coordinate a new version, after the 7.3 LPASS regression is understood | maintainer with the author |
| Front camera OV02C10 | `overlay/fragments/20-camera-rgb.dtsi` | not posted; depends on "arm64: dts: qcom: Add x1e/Hamoa camera DTSI" (Bryan O'Donoghue, v4, 2026-07) | send as a follow-up once that series is merged | maintainer |
| IR camera HM1092 + IR LED | `overlay/fragments/30-camera-ir.dtsi` | depends on the HM1092 driver | after the driver is merged | maintainer |
| HM1092 driver | `kernel/patches/0200-0201` | v6 on linux-media (Ramshouriesh R, 2026-08) | none, wait | author |
| HM1092 IR LED strobe | `kernel/patches/0202` | not posted | offer to the HM1092 author for v7 | maintainer |
| CCI: power on GDSC before init | `kernel/patches/0010` | not posted (HurlyDesousa PR #22) | ask the author to post it, or post with permission | author |
| ASUS EC HID (keyboard backlight, Fn keys) for 0B05:4543 | `kernel/patches/0300` | Zenbook A14 v1 (A. M. Serdeliuc) not merged, maintainer asked for integration into `hid-asus` | contribute the Vivobook S15 ID and fixes to the v2 effort | maintainer with the v2 author |
| EC driver extensions (Tj, profiles, RPM, retries) | `kernel/patches/0401-0406` | posted by Anvesh Jain P (Qualcomm), 2026-07-28, not merged | test and reply with `Tested-by:` | maintainer |
| EC: Vivobook S15 support, uninterrupted Tj, deferred probe | `kernel/patches/0407-0409` | not posted | post as a follow-up to the series above | maintainer |
| PS883x: DP pin assignment F | `kernel/patches/0500` | in jglathe/linux_ms_dev_kit | ask Jens Glathe about the upstream plan | author |
| PDC / deep idle (CxPC) for suspend | | mainline 7.3 | | |
| LPASS macros: no sound after runtime suspend on 7.3 | `udev/90-vivobook-s15-lpass-rpm.rules` (workaround) | not reported | bug report to alsa-devel / linux-arm-msm with the analysis (SoundWire resume without re-init) | maintainer |

## Other projects

| Project | Item | State | Next step |
|---|---|---|---|
| alsa-ucm-conf | Vivobook S15 profile (separate speaker and headphone verbs, internal and headset mics) | not submitted; 1.2.16 sends the S15 to the generic T14s profile (DMI regex in `x1e80100.conf`) | pull request on GitHub (alsa-project/alsa-ucm-conf) with `ucm/` and `ucm/x1e80100.conf.patch` |
| linux-firmware | ASUS-signed ADSP/CDSP/GPU firmware | only the audio topology is upstream | ASUS has to submit it; ask ASUS support |
| qcom-firmware-extract | Vivobook S15 entry | present | none |
| udev-hid-bpf | HID-BPF program for the keyboard | in the Icecream95 fork | optional, the kernel driver supersedes it |
| libcamera | OV02C10 on X1E (softISP) | works with upstream libcamera | tuning file if we make one |
| Howdy | reading the IR camera through libcamera / camss | local patch | pull request to boltgolt/howdy |
| Fedora | kernel config options (e.g. `CONFIG_VIDEO_HM1092`) | | request in Fedora kernel when drivers are mainline |

## How to send kernel patches

```bash
b4 prep -n vivobook-s15-camera          # start a series
# commit with: git commit -s  (your own Signed-off-by, never added by a tool)
./scripts/checkpatch.pl --strict -g HEAD
./scripts/get_maintainer.pl -f arch/arm64/boot/dts/qcom/x1-asus-vivobook-s15.dtsi
b4 prep --auto-to-cc
b4 send --reflect                        # send to yourself first
b4 send
```

AI-assisted patches follow `Documentation/process/coding-assistants.rst`:
an `Assisted-by:` tag, and only a human adds `Signed-off-by:`.
