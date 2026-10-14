# EC protocol notes

Findings about the embedded controller of the ASUS Vivobook S 15 (S5507QAD,
EC firmware 3.1.1). Derived from the ACPI tables of BIOS S5507QAD.367 and from
tests on the laptop. No ACPI code is reproduced here; decoded AeoB/ACPI
resources of this model are published in
[alexVinarskis/qcom-aeob-dumps](https://github.com/alexVinarskis/qcom-aeob-dumps).

## Summary

The EC speaks Qualcomm's reference EC protocol, the one implemented by
`drivers/platform/arm64/qcom-hamoa-ec.c` for the Hamoa CRD and IOT EVK:

- I2C address 0x76 on QUP_0_SE_5 (`&i2c5` in `hamoa.dtsi`), 400 kHz,
- interrupt on TLMM GPIO 66, falling edge, pull-up (the EC drives the line),
- same command numbers, byte layout and event codes 0x30-0x3D.

ASUS added its own commands to the same EC (0x50-0x62 on 0x76 and a mailbox
at address 0x5B); the driver does not need them.

## Commands

| Cmd | Meaning | Driver (with patches 0401-0410) | Notes on this laptop |
|---|---|---|---|
| 0x05 | read pending event | read in the IRQ handler | |
| 0x0E | firmware version, 4 bytes | read at probe | reports 3.1.1 |
| 0x20 | SoC temperature: `[0x20, source=1 (Tj), 2, lo, hi]`, 0.1 °C | sent periodically | confirmed in 0.1 °C units |
| 0x22 | fan speed: write `[0x22, id]`, read `[2, lo, hi]` | hwmon `fanN_input` | real RPM (multiples of 60) |
| 0x23 | modern standby: 1 = enter, 0 = exit | sent around suspend | Windows sends it from `PEP0._DSM` functions 7 and 8 |
| 0x24 | fan profile | **not used** on ASUS | |
| 0x28 | fan look-up table (64 bytes) | **not used** on ASUS | would overwrite the ASUS fan curve |
| 0x30 | fan debug mode (forced PWM/RPM) | **not used** on ASUS | used by the CRD calibration |
| 0x35 | enable/disable EC events | enabled at probe | |
| 0x42 | thermal capabilities | read, falls back to 2 fans | not in the ASUS tables, returns zeros |
| 0x29-0x2F | EC thermistors | hidden on ASUS | answer zeros or stale data |

ASUS-specific events 0xDA, 0xDB, 0xE0, 0x18, 0x1A and 0x1C are logged at
debug level only.

## Why the CRD path must not run on this EC

The CRD configuration calibrates the fans (forces 100% PWM through debug
mode), then writes a linear 16-point table (25-105 °C) and switches profiles.
On the ASUS EC that would replace the ASUS fan curve until the EC resets.
The S15 therefore has its own compatible, `asus,vivobook-s15-ec`, with no
`qcom,hamoa-crd-ec` fallback, and its configuration disables calibration,
table writes, profile switching and cooling devices.

## Behaviour with and without Tj

| State | Fans |
|---|---|
| no Tj ever sent (stock Fedora) | EC default, about 2300-2600 RPM, does not react to CPU load |
| Tj sent | ASUS curve: 0 RPM at about 31 °C, about 5300-5600 RPM at 78-80 °C under full load (the cores reached 90-95 °C without the driver) |
| Tj stops after it has been sent | full speed (about 8000 RPM) after about 70 s, **hard reset of the laptop after about 130-210 s** |

This is why patch 0408 keeps the Tj feed alive under all circumstances and
patch 0409 defers probe until the `tsens` thermal zones exist.

## Open questions

- Does modern standby enter (`0x23 0x01`) stop the EC's Tj watchdog? Until
  this is known, the driver refuses system suspend unless the module
  parameter `allow_suspend` is set.
- Windows sends an ASUS mailbox write (page 0x02, keyboard related) on first
  use of the bus. The EC accepts Tj without it.
