# Userspace pieces

| Directory | What | Silverblue image | Workstation | Optional |
|---|---|---|---|---|
| [`camera/`](camera/) | WirePlumber rule that hides the raw CAMSS nodes; OV02C10 digital gain helper | rule built in; gain helper per user | support package (rule); by hand (gain) | gain only |
| [`howdy/`](howdy/) | face login with the IR camera: CAMSS reader for Howdy, udev rule, SELinux module, PAM setup | built in (`--howdy no` to leave out); faces and PAM: `install-howdy.sh add`/`pam` | `install-howdy.sh` / `uninstall-howdy.sh` | yes |
| [`keyboard/`](keyboard/) | HID-BPF alternative to the `hid-asus-ec` kernel driver, for stock kernels | `--packages udev-hid-bpf`, rest as in the README | by hand (README) | yes |
| [`wifi/`](wifi/) | ath12k: power save off, stall watchdog | built in (`--wifi no`); `install.sh --band-24` still works | `install.sh` / `uninstall.sh` | yes |
| [`plymouth/`](plymouth/) | centred boot splash with scale 2; the ASUS logo is extracted locally, never stored here | built in when `image/local/logo/` has the logo; scale via `image/kargs.d` | `install.sh` / `uninstall.sh` | yes |
| [`suspend/`](suspend/) | s2idle with the EC driver: `allow_suspend=1`, s2idle as default sleep mode | built in (`allow_suspend` with `--ec yes`) | by hand (README) | only with the EC driver |
| [`boot/`](boot/) | boot time fixes: `systemd.tpm2_wait=0`, NetworkManager iSCSI dispatcher mask | built in (`image/kargs.d`) | by hand (README) | yes |

On Silverblue `/usr` is read-only: the scripts that would change it refuse to
run on a booted image and point to [`../image/`](../image/). Files in `/etc`
and `/var` (face models, PAM lines, NetworkManager connections) stay per
machine and are kept across image updates.

The install scripts accept `--dry-run` where they change system files.
No script contains network names, user names or paths of the maintainer's
machine.
