# COPR project (planned)

Project: `BurninChrome/vivobook-s15` on https://copr.fedorainfracloud.org

| Package | Source | Chroots | Build trigger |
|---|---|---|---|
| `vivobook-s15-support` | SCM: this repository, `make srpm` (`.copr/Makefile`) | fedora-45-aarch64, fedora-rawhide-aarch64 | GitHub webhook on tag |
| `kernel` (build ID `.vivobookN`) | SRPM from `packaging/kernel/prepare-srpm.sh` | fedora-45-aarch64 | manual upload |

Project settings: build timeout at the maximum (kernel), "follow Fedora
branching" on, instructions linking to `README.md` and the firmware warning.
