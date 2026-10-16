# kernel-install hook and helpers

Installed by `make install` or the `vivobook-s15-support` package. `@LIBEXECDIR@`
and `@DATADIR@` are replaced at install time.

| File | Installed as | Purpose |
|---|---|---|
| `30-vivobook-s15.install` | `/usr/lib/kernel/install.d/` (package) or `/etc/kernel/install.d/` (`make install`) | runs `apply-dtb` for every installed kernel |
| `apply-dtb` | `<libexecdir>/vivobook-s15/` | merges the overlay into the DTB inside `/boot/vmlinuz-<kver>`, or `/usr/lib/modules/<kver>/vmlinuz` in an image build; skips if already identical |
| `patch-vmlinuz-dtb.py` | `<libexecdir>/vivobook-s15/` | rewrites the `.dtbauto` PE section (from bingo1991, MIT) |
| `apply-ucm` | `<libexecdir>/vivobook-s15/` | adds the Vivobook branch to `x1e80100.conf` after `alsa-ucm` updates |
| `vivobook-s15-ucm.path`, `.service` | systemd units | run `apply-ucm` when the UCM package changes |
| `lpass-rpm-on` | `<libexecdir>/vivobook-s15/` | called by `udev/90-vivobook-s15-lpass-rpm.rules` |
| `vivobook-s15.conf` | `/etc/vivobook-s15.conf` | `EXPERIMENTAL_EC=no|yes` |

How it works: [../docs/dtb-delivery.md](../docs/dtb-delivery.md).

In the Silverblue image (`image/Containerfile`) `apply-dtb` and `apply-ucm` run
once at build time; the kernel-install hook and the `vivobook-s15-ucm` units
are not installed, because kernels and `alsa-ucm` only change with a new
image. On a booted image `apply-dtb` refuses to run (read-only `/usr`).
`apply-ucm` and its units go away once alsa-ucm-conf ships the profile.
