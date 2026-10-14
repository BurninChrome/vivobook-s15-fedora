# Installation

Status: the COPR packages are planned; until they exist, install from this
repository (manual way below).

## Requirements

- ASUS Vivobook S 15 S5507QAD (S5507QA: please file a hardware report),
- Fedora 45 aarch64 Workstation installed (the stock kernel boots, without
  audio, cameras and fan control),
- Secure Boot disabled in the BIOS setup,
- a working Internet connection and about 2 GB free in `/boot` and `/`.

Keep a Fedora live USB and the stock kernel entry in GRUB as fallbacks.

## 1. Firmware

See [firmware.md](firmware.md). Reboot and check
`upower -i /org/freedesktop/UPower/devices/battery_qcom_battmgr_bat`.

## 2. Support package: overlay, hook, UCM, rules

With COPR (planned):

```bash
sudo dnf copr enable BurninChrome/vivobook-s15
sudo dnf install vivobook-s15-support
```

Manually from a checkout of this repository:

```bash
sudo dnf install dtc cpp make python3
make                    # builds overlay/build/*.dtbo
make check              # syntax checks and a test merge with your stock DTB
sudo make install       # PREFIX=/usr/local; hook in /etc/kernel/install.d
sudo make apply         # merge the overlay into every installed kernel, restore UCM
```

`make apply` rewrites the `.dtbauto` section of `/boot/vmlinuz-<version>`
(see [dtb-delivery.md](dtb-delivery.md)); a backup of each image goes to
`/var/backups/x1e/`. Future kernels are handled by the kernel-install hook.

## 3. Kernel

The stock Fedora kernel gives battery, speakers, headphones, microphones,
Wi-Fi and GPU (with the overlay). Both cameras (CCI power-on fix, HM1092
driver), hardware video decoding (video clock controller), keyboard backlight
and Fn keys, and fan control need the patched kernel:

```bash
sudo dnf install kernel-vivobook        # planned, same COPR
```

Until then: `packaging/kernel/prepare-srpm.sh` builds the source RPM, and
`rpmbuild --rebuild` on the laptop builds it (several hours).

## 4. Experimental: EC fan control

Read [ec-fan-control.md](ec-fan-control.md) first. Then:

```bash
sudo sed -i 's/^EXPERIMENTAL_EC=.*/EXPERIMENTAL_EC=yes/' /etc/vivobook-s15.conf
sudo /usr/libexec/vivobook-s15/apply-dtb "$(uname -r)"   # /usr/local/libexec for make install
```

and reboot into a kernel-vivobook kernel.

## 5. Optional

Howdy face unlock ([../userspace/howdy/](../userspace/howdy/)), Wi-Fi
watchdog ([../userspace/wifi/](../userspace/wifi/)), Plymouth theme
([../userspace/plymouth/](../userspace/plymouth/)), boot time fixes
([../userspace/boot/](../userspace/boot/)).

## 6. Check

Reboot, then run `tools/selftest.sh` (no root). It prints PASS/WARN/FAIL for
firmware, battery, overlay nodes, audio, cameras, keyboard, EC, cpufreq, GPU
and the hook.

## Migrating from an earlier manual setup ("vivobook-audio")

Early setups installed `/etc/kernel/install.d/30-vivobook-audio.install`,
`/usr/local/libexec/vivobook-audio/`, `vivobook-audio-ucm.{path,service}`
and `/etc/udev/rules.d/90-vivobook-lpass-rpm.rules`. Remove them before
installing this package, otherwise two hooks write the DTB:

```bash
sudo systemctl disable --now vivobook-audio-ucm.path
sudo rm -f /etc/kernel/install.d/30-vivobook-audio.install \
    /etc/systemd/system/vivobook-audio-ucm.path /etc/systemd/system/vivobook-audio-ucm.service \
    /etc/udev/rules.d/90-vivobook-lpass-rpm.rules
sudo rm -rf /usr/local/libexec/vivobook-audio
```

If the old overlay included the EC node, set `EXPERIMENTAL_EC=yes` before
`make apply`, otherwise the next DTB comes without it.

## Removal

`sudo dnf remove vivobook-s15-support kernel-vivobook` (or `sudo make
uninstall`), then reinstall the stock kernel
(`sudo dnf reinstall kernel-core kernel-uki-dtbloader`) to get unmodified
`/boot/vmlinuz-<version>` images.
