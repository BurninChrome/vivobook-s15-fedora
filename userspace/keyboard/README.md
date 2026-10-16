# Keyboard: Fn keys, backlight, Fn-lock

> **Silverblue:** the image normally has the kernel driver (kernel-vivobook).
> For the HID-BPF alternative build the image with
> `image/build.sh --packages udev-hid-bpf`, run `build-bpf.sh` in a `toolbox`,
> and install as below: `/usr/local` and `/etc` are writable.

The keyboard of the S5507 is an I2C HID device (0B05:4543) that also carries
vendor report 0x5A to and from the embedded controller: Fn hotkeys, keyboard
backlight (3 levels) and Fn-lock.

## Recommended: kernel driver (kernel-vivobook)

Patch `kernel/patches/0300` adds the `hid-asus-ec` driver
(`CONFIG_HID_ASUS_EC=m`): `asus::kbd_backlight` LED with the GNOME slider and
OSD, Fn+Esc toggles Fn-lock (also `/sys/.../fn_lock`), Fn hotkeys, backlight
off on suspend and state restore on resume. Nothing to install here.

## Alternative for stock Fedora kernels: HID-BPF

Icecream95's HID-BPF program fixes the keys on a stock kernel. Do **not**
use it together with the kernel driver (Fn-lock and the backlight key would be
handled twice).

```bash
./build-bpf.sh                                   # no root, builds the .bpf.o
sudo dnf install udev-hid-bpf
sudo install -D -m 0644 build-bpf/0010-ASUS__Vivobook_S15_S5507_kbd.bpf.o \
     /usr/local/lib/firmware/hid/bpf/0010-ASUS__Vivobook_S15_S5507_kbd.bpf.o
sudo install -m 0644 81-hid-bpf-vivobook-s15.hwdb /etc/udev/hwdb.d/
sudo install -m 0644 70-vivobook-s15-kbd-hidraw.rules /etc/udev/rules.d/
sudo systemd-hwdb update && sudo udevadm control --reload
sudo udevadm trigger --subsystem-match=hid --attr-match=modalias='hid:b0018g0001v00000B05p00004543'
```

The backlight is then controlled with Icecream95's `kb-bl.py` (in the same
repository, needs `python3-hidapi`), which uses the hidraw access granted by
`70-vivobook-s15-kbd-hidraw.rules`.

If the program does not load from udev (SELinux denial in the journal), load
it by hand with `udev-hid-bpf add` and report the denial.

Removal: delete the three installed files and run `systemd-hwdb update`.
