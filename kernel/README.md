# Kernel patches

Applied in the order given by `series`. Base: see `../packaging/kernel/BASE`.
Config options: `config/kernel-local`.

| Patch | Subject | Author | Upstream |
|---|---|---|---|
| 0010 | i2c: qcom-cci: power on GDSC via pm_runtime before hw init | Grokbot (via HurlyDesousa) | not posted |
| 0200 | media: dt-bindings: Add Himax HM1092 NIR sensor | Ramshouriesh R | linux-media v6 |
| 0201 | media: i2c: hm1092: add Himax HM1092 mono NIR sensor driver | Ramshouriesh R | linux-media v6 |
| 0202 | media: i2c: hm1092: strobe the IR illuminator while streaming | maintainer | not posted |
| 0300 | HID: asus-ec: add ASUS EC hotkeys and keyboard backlight driver | maintainer, based on A. M. Serdeliuc v1 | not posted (A14 v1 pending rework) |
| 0401-0406 | qcom-hamoa-ec: binding, Tj, fan profile, RPM/LUT, adapter check, retries | Anvesh Jain P | posted 2026-07-28 |
| 0407 | qcom-hamoa-ec: Add ASUS Vivobook S 15 | maintainer | not posted |
| 0408 | qcom-hamoa-ec: Never starve the ASUS EC of SoC Tj | maintainer | not posted |
| 0409 | qcom-hamoa-ec: Defer probe until the tsens sensors are bound | maintainer | not posted |
| 0410 | qcom-hamoa-ec: Optionally report the hottest zone as SoC Tj | maintainer | not posted |
| 0500 | usb: typec: mux: ps883x: handle DP pin F and wait after config writes | Jens Glathe | jglathe tree |
| 0601-0604 | ASoC: codecs: lpass-{wsa,rx,tx,va}-macro: revert PM clock framework conversion | maintainer | not posted (downstream workaround) |

Rules: original authorship and `Signed-off-by:` chain are kept unchanged;
our changes to someone else's patch go into a separate patch, or are noted
in the commit message (`[maintainer: rebased onto 7.3]`).
