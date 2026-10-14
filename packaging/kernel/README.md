# kernel-vivobook

The kernel package is Fedora's own kernel spec with this repository's patches
and config fragment added through the hooks the spec already has
(`linux-kernel-test.patch` and `kernel-local`). Nothing else is changed, so
`kernel-uki-dtbloader` and the stubble UKI work as in stock Fedora.

| File | Purpose |
|---|---|
| `BASE` | Fedora kernel NVR and dist-git commit the series is built on |
| `prepare-srpm.sh` | fetches the Fedora SRPM, adds `kernel/patches/series` as `linux-kernel-test.patch`, `kernel/config/kernel-local`, sets `buildid .vivobookN`, writes a new SRPM |
| `.copr/Makefile` | `make srpm` entry point for COPR SCM builds |

Build in COPR: `copr-cli build BurninChrome/vivobook-s15 kernel-*.vivobookN.src.rpm`
(aarch64 builders, the build takes several hours; set the project build
timeout to the maximum).

Package names keep Fedora's names (`kernel`, `kernel-core`, ...) with the
`.vivobookN` build ID in the release, so `dnf` treats them as newer kernels and
the stock kernel can be installed side by side. Users who do not want the
COPR kernel to replace Fedora kernels on update can use
`dnf versionlock` or `excludepkgs=` in the COPR repo file.

Secure Boot: COPR does not sign kernels; Secure Boot must stay disabled.
