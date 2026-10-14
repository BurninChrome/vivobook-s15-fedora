# Credits and sources

Every third-party piece used here, with its origin and license. Keep this
list complete when adding files.

| What | Author(s) | Source | License |
|---|---|---|---|
| Audio bring-up, DTB-in-UKI delivery, UCM base, `patch-vmlinuz-dtb.py` | bingo1991 and contributors | https://github.com/bingo1991/qcom-x1e-vivobook-s15 | MIT (scripts), BSD-3-Clause (DT) |
| CCI GDSC power-on patch | Grokbot (via HurlyDesousa) | https://github.com/HurlyDesousa/linux-aarch64-vivobook PR #22 | GPL-2.0 |
| HM1092 binding and driver | Ramshouriesh R | linux-media, v6 2026-08 (v5: https://lore.kernel.org/all/20260709-hm1092-driver-v5-0-a1f5baa6fe08@gmail.com/) | GPL-2.0, binding GPL-2.0 OR BSD-2-Clause |
| EC driver extensions | Anvesh Jain P (Qualcomm) | https://lore.kernel.org/all/20260728-ec_add_more_commands-v1-0-771abd65ee1a@oss.qualcomm.com/ | GPL-2.0 |
| ASUS EC HID driver (basis of `hid-asus-ec`) | Alexandru Marc Serdeliuc | linux-input, 2025-12-21 | GPL-2.0 |
| HID-BPF keyboard program, protocol details | Icecream95 | https://github.com/icecream95/udev-hid-bpf commit 519dadad5420 | GPL-2.0 |
| PS883x DP pin F | Jens Glathe | https://github.com/jglathe/linux_ms_dev_kit (branch jg/ubuntu-qcom-x1e-7.3rc) | GPL-2.0 |
| EC protocol research (Zenbook A14 / Vivobook S15) | Nicolas Derumigny | https://github.com/NicolasDerumigny/asus-zenbook-a14-ec | see repository |
| Decoded ACPI / AeoB resources | Aleksandrs Vinarskis and contributors | https://github.com/alexVinarskis/qcom-aeob-dumps | see repository |
| Howdy | boltgolt and contributors | https://github.com/boltgolt/howdy | MIT |
| Howdy packages for Fedora aarch64 (used, not redistributed) | starfish | https://copr.fedorainfracloud.org/coprs/starfish/howdy-beta/ | see packages |
| Microphone routing (DMIC on MIC BIAS3) | Elliot Huang | "arm64: dts: qcom: support sound on Asus Vivobook S15", LKML 2025-06-02 | BSD-3-Clause (DT) |
| `dt-bindings` headers in `overlay/include/` | Linux kernel authors | Linux 7.3-rc6 | see each file |
