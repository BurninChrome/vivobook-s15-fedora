# Installation (Fedora Silverblue 45)

The supported setup is a locally built Silverblue image
([../image/README.md](../image/README.md)). The mutable Fedora Workstation
setup is still described in [install-workstation.md](install-workstation.md).

## Requirements

- ASUS Vivobook S 15 S5507QAD (S5507QA: please file a hardware report),
- Secure Boot disabled in the BIOS setup (the kernel is not signed),
- about 15 GB free in `/var` for the build (60 GB more to build the kernel),
- a Fedora live USB as a fallback.

## 1. Install stock Fedora Silverblue 45 aarch64

Install from the official Fedora Silverblue 45 aarch64 ISO. The stock kernel
boots (no audio, cameras, battery status or fan control yet). Do not layer
packages with `rpm-ostree install`: `bootc switch` refuses deployments with
local changes (`rpm-ostree reset` removes them).

## 2. Get this repository and the local inputs

```bash
git clone https://github.com/BurninChrome/vivobook-s15-fedora
cd vivobook-s15-fedora
image/fetch-local.sh        # no root: firmware + logo into image/local/ (docs/firmware.md)
```

Without Internet access to the ASUS server, copy the six firmware files from
a Windows installation (`qcom-firmware-extract` in a toolbox) into
`image/local/firmware/` instead.

## 3. Kernel

```bash
image/build-kernel.sh       # no root, several hours; RPMs into image/local/rpms/
```

Once the COPR kernel exists, put its six RPMs (`kernel`, `kernel-core`,
`kernel-modules`, `kernel-modules-core`, `kernel-modules-extra`,
`kernel-uki-dtbloader`) into
`image/local/rpms/` instead (`image/fetch-local.sh --rpms DIR`). Skip this step
to build with the stock kernel first.

## 4. Build the image and switch to it

```bash
sudo image/build.sh --switch
systemctl reboot
```

The previous deployment (stock Silverblue) stays in the GRUB menu as the
fallback. If `bootc switch` is not available or refuses, the same works with
rpm-ostree:

```bash
sudo rpm-ostree rebase ostree-unverified-image:containers-storage:localhost/vivobook-s15-silverblue:45
sudo rpm-ostree kargs --append-if-missing=systemd.tpm2_wait=0 --append-if-missing=plymouth.force-scale=2
```

## 5. Check

After the reboot: `tools/selftest.sh` (no root) and `bootc status`.

## 6. Optional

- **EC fan control** (experimental): read [ec-fan-control.md](ec-fan-control.md),
  then `sudo image/build.sh --ec yes --switch`. Suspend support comes with it
  ([../userspace/suspend/](../userspace/suspend/)).
- **Howdy face login**: built in by default. Record a face and enable PAM:
  `sudo userspace/howdy/install-howdy.sh add "$USER"`, then `test-cam`, then
  `pam` ([../userspace/howdy/README.md](../userspace/howdy/README.md)).
- **Wi-Fi**: power save off and the watchdog are built in;
  `sudo userspace/wifi/install.sh --band-24 "<connection>"` still works.
- **Applications**: Flatpak, or `toolbox` for development tools; rebuild the
  image with `--packages` only for system components.

## Updates

```bash
git pull && sudo image/build.sh --switch && systemctl reboot
```

See [../image/README.md](../image/README.md#updates).

## Fresh installation directly from the image

An installer USB stick with the image and a kickstart:
[../image/README.md](../image/README.md#fresh-installation-from-a-usb-stick).

## Removal

`sudo bootc switch quay.io/fedora/fedora-silverblue:45` (or
`sudo rpm-ostree rebase fedora:fedora/45/aarch64/silverblue`) and reboot.
Remove `plymouth.force-scale=2` and `systemd.tpm2_wait=0` with
`sudo rpm-ostree kargs --delete-if-present=...` if you do not want them.
