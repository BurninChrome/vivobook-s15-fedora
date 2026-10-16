# Silverblue image

Fedora Silverblue 45 with everything from this repository built in: the
patched kernel with the overlay merged into its DTB, firmware, UCM profile,
udev and WirePlumber rules, suspend, Wi-Fi, Plymouth theme and Howdy. The
laptop boots the image through `bootc`/`rpm-ostree` like any other Silverblue
deployment, with rollback to the previous image from the boot menu.

The image is **built locally** and never published: it contains the ASUS
firmware (and the ASUS logo), which may not be redistributed. Keep it in your
own container storage or as a file on your own USB stick.

## Files

| File | Purpose |
|---|---|
| `Containerfile` | stage 1 (`fedora:45`): `make install` of the support files; stage 2 (`fedora-silverblue:45`): `build-root.sh`, `bootc container lint` |
| `build-root.sh` | runs inside the build: kernel swap, firmware, UCM, DTB into `/usr/lib/modules/<kver>/vmlinuz`, suspend, Wi-Fi, Plymouth, Howdy, initramfs |
| `build.sh` | `podman build` with the options below, `--switch`, `--oci-archive` |
| `fetch-local.sh` | fills `local/firmware` and `local/logo` (runs the tools in a Fedora container, no root) |
| `build-kernel.sh` | builds `kernel-vivobook` in a Fedora container into `local/rpms` (hours) |
| `kargs.d/10-vivobook-s15.toml` | kernel arguments applied by `bootc switch` / `bootc upgrade` |
| `vivobook-s15.ks` | kickstart for a fresh installation from a USB stick (finds the OCI archive on the stick in `%pre`) |
| `local/` | **git-ignored** inputs: `firmware/`, `logo/`, `rpms/`, `packages` (extra RPMs) |

## Build options

`sudo image/build.sh [options]`:

| Option | Default | Effect |
|---|---|---|
| `--ec yes\|no` | value in the running `/etc/vivobook-s15.conf`, else `no` | EC node in the DTB (fan control) and `allow_suspend=1`; **read [../docs/ec-fan-control.md](../docs/ec-fan-control.md)** |
| `--howdy yes\|no` | `yes` | Howdy from COPR starfish/howdy-beta, camss reader, SELinux module; PAM stays your choice |
| `--wifi yes\|no` | `yes` | Wi-Fi power save off, ath12k stall watchdog timer |
| `--packages "A B"` | contents of `local/packages` | extra RPMs (prefer Flatpak or toolbox for applications); put them in `local/packages` so every rebuild keeps them |
| `--switch` | | `bootc switch` to the image, or `bootc upgrade` if it is already booted |
| `--oci-archive FILE` | | write the image to a file (installer USB stick) |
| `--tag`, `--base` | `localhost/vivobook-s15-silverblue:45`, `quay.io/fedora/fedora-silverblue:45` | |

Without `local/rpms` the image keeps Fedora's stock kernel: audio, battery,
Wi-Fi and GPU work, cameras, Fn keys, hardware video decoding and fan
control do not (see the table in [../README.md](../README.md)).

## What changes compared to Fedora Workstation

| Workstation (`make install`, `dnf`) | Silverblue image |
|---|---|
| `30-vivobook-s15.install` merges the overlay into `/boot/vmlinuz-<kver>` on every kernel update | `apply-dtb` merges it into `/usr/lib/modules/<kver>/vmlinuz` at build time; ostree copies the kernel to `/boot/ostree/` |
| `vivobook-s15-ucm.path` restores the UCM profile after `alsa-ucm` updates | `apply-ucm` runs at build time; the path unit is not installed |
| `EXPERIMENTAL_EC` in `/etc/vivobook-s15.conf` + `apply-dtb` | `--ec yes\|no` and a rebuild |
| firmware in `/usr/lib/firmware/updates/...` by hand | copied from `local/firmware` at build time (same path) |
| `grubby` / `/etc/kernel/cmdline` | `kargs.d/10-vivobook-s15.toml` |
| `userspace/*/install.sh` write to `/usr` and `/etc` | the image contains the result; the scripts refuse to change `/usr` on a booted image |
| `dnf upgrade` | rebuild the image, `--switch`, reboot |

Things that stay per machine and live in `/etc` or `/var` (kept across
images): Howdy face models and PAM lines (`install-howdy.sh add` / `pam`),
NetworkManager connections, `--band-24` of the Wi-Fi script, users.

## Updates

```bash
cd vivobook-s15-fedora && git pull
sudo image/build.sh --switch      # pulls a newer fedora-silverblue:45, rebuilds, stages it
systemctl reboot
```

Rollback: choose the previous entry in GRUB, or `sudo bootc rollback` and
reboot. A new `kernel-vivobook` means `image/build-kernel.sh` (or the COPR
build, once it exists) before the image build.

`rpm-ostree upgrade` and GNOME Software do not see local images; use
`build.sh --switch`. Automatic updates (`rpm-ostreed-automatic.timer`,
`bootc-fetch-apply-updates.timer`) should stay disabled.

## Fresh installation from a USB stick

Usually simpler: install stock Fedora Silverblue 45 and switch
([../docs/install.md](../docs/install.md)). To install the image directly:

1. Write the official Fedora Silverblue 45 aarch64 ISO to a USB stick with a
   writable file system (e.g. Fedora Media Writer), so that its label stays
   `Fedora-45-Silverblue-aarch64`.
2. Build the archive and copy it with the kickstart into `vivobook/` on the stick:

   ```bash
   sudo image/build.sh --oci-archive /var/tmp/vivobook-s15-silverblue-45.oci.tar
   mkdir -p /run/media/$USER/Fedora-45-Silverblue-aarch64/vivobook
   cp /var/tmp/vivobook-s15-silverblue-45.oci.tar image/vivobook-s15.ks \
      /run/media/$USER/Fedora-45-Silverblue-aarch64/vivobook/
   ```

3. Boot the stick, press `e` on the install entry in GRUB and append
   `inst.ks=hd:LABEL=Fedora-45-Silverblue-aarch64:/vivobook/vivobook-s15.ks`
   to the `linux` line. The `%pre` section finds the archive wherever the
   installer mounted the stick. Set language, disk and user in Anaconda as usual.
4. After the first boot, build the image once with `--switch`, so that later
   updates come from `containers-storage` and not from the archive on the stick.

## Checks

```bash
podman run --rm localhost/vivobook-s15-silverblue:45 sh -c 'ls /usr/lib/modules; cat /etc/vivobook-s15.conf'
bootc status                      # booted image, staged image, rollback
tools/selftest.sh                 # after the reboot
```
