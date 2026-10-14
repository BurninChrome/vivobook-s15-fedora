# Userspace pieces

| Directory | What | Installed by | Optional |
|---|---|---|---|
| [`camera/`](camera/) | WirePlumber rule that hides the raw CAMSS nodes; OV02C10 digital gain helper | support package (rule); by hand (gain) | gain only |
| [`howdy/`](howdy/) | face login with the IR camera: CAMSS reader for Howdy, udev rule, SELinux module, PAM setup | `install-howdy.sh` / `uninstall-howdy.sh` | yes |
| [`keyboard/`](keyboard/) | HID-BPF alternative to the `hid-asus-ec` kernel driver, for stock kernels | by hand (README) | yes |
| [`wifi/`](wifi/) | ath12k: power save off, stall watchdog | `install.sh` / `uninstall.sh` | yes |
| [`plymouth/`](plymouth/) | centred boot splash with scale 2; the ASUS logo is extracted locally, never stored here | `install.sh` / `uninstall.sh` | yes |
| [`boot/`](boot/) | boot time fixes: `systemd.tpm2_wait=0`, NetworkManager iSCSI dispatcher mask | by hand (README) | yes |

The install scripts accept `--dry-run` where they change system files.
No script contains network names, user names or paths of the maintainer's
machine.
