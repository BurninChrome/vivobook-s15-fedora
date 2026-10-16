# How the device tree reaches the kernel

Fedora 45 boots this laptop with `kernel-uki-dtbloader`: `/boot/vmlinuz-<kver>`
is a unified kernel image whose stub ([stubble](https://github.com/ubuntu/stubble))
contains every Snapdragon laptop DTB in `.dtbauto` PE sections and picks one
by matching SMBIOS IDs. Consequences:

- GRUB's `devicetree` command and files in `/boot/dtb-<kver>/` are ignored;
- the overlay must be merged into the DTB **inside** the image.

`hooks/30-vivobook-s15.install` (run by `kernel-install` for every new kernel)
calls `apply-dtb <kver>`, which:

1. takes the stock `/boot/dtb-<kver>/qcom/x1e80100-asus-vivobook-s15.dtb`,
2. applies `vivobook-s15.dtbo` (or `vivobook-s15-experimental.dtbo` when
   `EXPERIMENTAL_EC=yes` in `/etc/vivobook-s15.conf`) with `fdtoverlay`,
3. removes `__symbols__` to save space,
4. writes the result into the matching `.dtbauto` section of
   `/boot/vmlinuz-<kver>` (`hooks/patch-vmlinuz-dtb.py`),
5. compares the content and does nothing if it is already up to date.

The section is 206336 bytes on Fedora 45 kernels. The merged DTB must fit;
`overlay/build-overlay.sh` prints the remaining margin. With the 7.3 stock DTB
the merged result is about 175 kB (margin about 31 kB).

## Silverblue (ostree, bootc)

On Silverblue the boot loader entry points at a copy of
`/usr/lib/modules/<kver>/vmlinuz` in `/boot/ostree/`, and kernel-install
plugins do not run on the booted system. The image build
([`image/build-root.sh`](../image/build-root.sh)) therefore:

1. takes `/usr/lib/modules/<kver>/vmlinuz-dtbloader.efi` (the stubble UKI)
   out of the `kernel-uki-dtbloader` RPM and copies it over
   `/usr/lib/modules/<kver>/vmlinuz`; the plain `vmlinuz` of `kernel-core`
   has no `.dtbauto` sections. The package itself is not installed: it
   conflicts with `kernel-core`, which provides the rest of the kernel,
2. runs `apply-dtb <kver>`, which finds no `/boot/vmlinuz-<kver>` and patches
   `/usr/lib/modules/<kver>/vmlinuz` instead (without a backup: the stock
   kernel stays in the base image),
3. also writes the merged DTB to `/usr/lib/modules/<kver>/devicetree`, which
   ostree copies next to the kernel and names in the boot entry; stubble
   uses its own section, the copy only keeps both identical.

`EXPERIMENTAL_EC` is therefore a build option (`image/build.sh --ec yes|no`),
and changing it means building and booting a new image.

## Backups (Workstation)

Before the first change of an image, `patch-vmlinuz-dtb.py` keeps a copy in
`/var/backups/x1e/`; `patch-vmlinuz-dtb.py --restore --vmlinuz <image>`
puts the stock image back.

Original analysis: [bingo1991/qcom-x1e-vivobook-s15, docs/dtb-delivery.md](https://github.com/bingo1991/qcom-x1e-vivobook-s15/blob/main/docs/dtb-delivery.md).
