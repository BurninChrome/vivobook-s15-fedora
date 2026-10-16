# Troubleshooting

| Symptom | Likely cause | What to do |
|---|---|---|
| No sound, `aplay -l` shows no `X1E80100-ASUS-Vivobook-S15` card | overlay not applied to the running kernel | Silverblue: check `bootc status` (booted the vivobook image?), rebuild with `image/build.sh --switch`; Workstation: `sudo /usr/libexec/vivobook-s15/apply-dtb $(uname -r)`, reboot |
| New image does not boot | kernel, initramfs or DTB problem | pick the previous entry in GRUB, then `sudo bootc rollback`; attach the build log of `image/build.sh` to the report |
| `bootc switch` refuses: local modifications | packages layered with `rpm-ostree install` | `sudo rpm-ostree reset`, reboot, switch again (or add the packages with `image/build.sh --packages`) |
| No sound on 7.3 only | known regression in `lpass-wsa-macro` clock handling | see the issue tracker; use the 7.2 kernel meanwhile |
| Battery shows 0 % or is missing | ADSP firmware missing or for the wrong variant | [firmware.md](firmware.md) |
| Fans at full speed, then reboot | EC lost the Tj stream | [ec-fan-control.md](ec-fan-control.md) |
| Camera app shows nothing | PipeWire uses raw V4L2 nodes instead of libcamera | WirePlumber rule in `userspace/camera/` |
| Wi-Fi connected but no traffic, only a reboot helps | ath12k data path stall (7.3) | `userspace/wifi/` watchdog |
| Long pause after the LUKS password | `systemd` waits for a TPM that has no driver yet | `systemd.tpm2_wait=0` (in `image/kargs.d`; check `cat /proc/cmdline`), see `userspace/boot/` |
