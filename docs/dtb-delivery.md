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

Before the first change of an image, `patch-vmlinuz-dtb.py` keeps a copy in
`/var/backups/x1e/`; `patch-vmlinuz-dtb.py --restore --vmlinuz <image>`
puts the stock image back.

Original analysis: [bingo1991/qcom-x1e-vivobook-s15, docs/dtb-delivery.md](https://github.com/bingo1991/qcom-x1e-vivobook-s15/blob/main/docs/dtb-delivery.md).
