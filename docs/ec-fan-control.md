# Embedded controller and fans

The S5507QAD uses the same I2C embedded controller protocol as Qualcomm's
reference designs, driven by `drivers/platform/arm64/qcom-hamoa-ec.c`
(mainline since 7.2). With the extra patches in `kernel/patches/`
(04xx) **and** `EXPERIMENTAL_EC=yes` (which adds the EC node to the device
tree; default: off) the driver works. On Silverblue the setting is a build
option of the image, `sudo image/build.sh --ec yes --switch`; on Workstation it
lives in `/etc/vivobook-s15.conf`. The driver:

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
- To turn it off on Silverblue, build with `--ec no` and reboot into that
  image; the previous image (with the EC node) stays as the rollback entry.
- The overlay node `40-ec.dtsi` alone is harmless: without the 04xx patches
  nothing binds to it and the EC keeps its default curve.
- **Suspend is refused by default** while the EC driver feeds Tj. With
  `qcom_hamoa_ec.allow_suspend=1` the driver sends "modern standby enter"
  (23 01) before sleeping and "modern standby exit" (23 00) after waking;
  this disarms the EC watchdog (tested up to 4 minutes of s2idle, no reset).
  Needs patch 0411. Setup: [userspace/suspend](../userspace/suspend/).
- If you see unexplained reboots, report them with the output of
  `journalctl -b -1 -k | grep -i -E 'hamoa|tsens|thermal'`.

Protocol notes: [ec-protocol.md](ec-protocol.md).
