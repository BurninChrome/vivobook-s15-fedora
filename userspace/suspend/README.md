# Suspend (s2idle) with the EC driver

Only for systems that run the experimental EC driver (`EXPERIMENTAL_EC=yes`,
kernel patches 0401-0411). Without the EC driver the EC is never armed and
suspend needs nothing from this directory except the s2idle setting.

While `qcom-hamoa-ec` feeds SoC temperatures to the EC, the EC resets the
laptop about two minutes after the reports stop. By default the driver
therefore refuses to suspend. With `allow_suspend=1` it sends the EC
"modern standby enter" before sleeping and "modern standby exit" after
waking, which disarms the watchdog for the time of the sleep.

## Install

```
sudo install -m 0644 vivobook-s15-ec.conf /etc/modprobe.d/
sudo install -D -m 0644 50-vivobook-s15-s2idle.conf /etc/systemd/sleep.conf.d/50-vivobook-s15-s2idle.conf
echo Y | sudo tee /sys/module/qcom_hamoa_ec/parameters/allow_suspend   # now, without reboot
```

Remove both files (and `echo N` to the parameter) to go back.

## Tested (S5507QAD, BIOS 367, kernel 7.3.0-rc6 with 0401-0411)

| Test | Result |
|---|---|
| s2idle 24 s, 61 s, 110 s, 242 s | no reset, fans silent during sleep |
| Wake sources | keyboard, touchpad, power button, lid (GPIO 92) |
| Time to picture after wake | about 2 s |
| After wake | Wi-Fi reconnects, audio, keyboard, cameras work |
| 12 consecutive suspends | 12 ok, 0 failed |

Not measured yet: battery drain during sleep. After waking the EC may keep
the fans stopped at idle temperatures (around 45 C); they spin up normally
under load.

## If something goes wrong

- Fans at full speed while the laptop sleeps: wake it at once (any key) and
  report it. The EC did not accept "modern standby enter".
- Reboot during sleep or about two minutes after waking: report
  `journalctl -b -1 -k | grep -i -E 'hamoa|PM:'`.
