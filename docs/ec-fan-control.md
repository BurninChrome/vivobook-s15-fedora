# Embedded controller and fans

The S5507QAD uses the same I2C embedded controller protocol as Qualcomm's
reference designs, driven by `drivers/platform/arm64/qcom-hamoa-ec.c`
(mainline since 7.2). With the extra patches in `kernel/patches/`
(04xx) **and** `EXPERIMENTAL_EC=yes` in `/etc/vivobook-s15.conf` (which adds
the EC node to the device tree; default: off) the driver:

- reports both fan speeds in RPM (`hwmon`),
- switches the fan profile with the power source,
- sends the SoC junction temperature (Tj) to the EC every second, read from
  the `tsens` thermal zones.

## Why this matters, and the danger

Without Tj the EC runs the fans on a fixed curve (about 2300-2600 RPM even when
idle). Once the EC has received Tj, it **expects it continuously**:

| Time without a Tj update | EC reaction |
|---|---|
| about 70 s | fans to maximum (about 8000 RPM) |
| about 130-210 s | **hard reset of the laptop**, no shutdown |

The patched driver therefore uses a dedicated high-priority workqueue,
repeats the last value if a thermal zone cannot be read, defers probe until
the `tsens` zones exist, and pins itself (it cannot be unloaded with `rmmod`).

## Rules

- Do not blacklist or unload `qcom_hamoa_ec` while the system runs.
- The overlay node `40-ec.dtsi` alone is harmless: without the 04xx patches
  nothing binds to it and the EC keeps its default curve.
- **Suspend is blocked** while the EC driver feeds Tj: it is not yet known
  whether modern standby stops the EC watchdog, and a laptop that resets in
  a bag is worse than one that does not sleep. The module parameter
  `qcom_hamoa_ec.allow_suspend=1` lifts the block for testing; report the
  result.
- If you see unexplained reboots, report them with the output of
  `journalctl -b -1 -k | grep -i -E 'hamoa|tsens|thermal'`.

Protocol notes: [ec-protocol.md](ec-protocol.md).
