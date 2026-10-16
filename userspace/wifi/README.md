# Wi-Fi (WCN7850, ath12k)

> **Silverblue:** steps A and B are part of the image (`image/build.sh
> --wifi yes`, the default): `/usr/lib/NetworkManager/conf.d/90-vivobook-wifi-powersave.conf`,
> `/usr/libexec/vivobook-wifi-{watchdog,recover}` and the enabled
> `vivobook-wifi-watchdog.timer`. Step C (`install.sh --band-24`) works as
> below; `uninstall.sh` does not remove the built-in parts (rebuild with
> `--wifi no`).

On 7.3 kernels the card occasionally stalls: it associates with the access
point but the 4-way handshake never completes, followed by beacon loss, in a
loop until the driver is reloaded. Contributing factors seen in the logs:
power save together with the DTIM policy new in 7.3, and routers that push
clients between 2.4 and 5 GHz every few minutes. The latest firmware
(`c7-00108`, in linux-firmware) does not fix it; the same symptom is reported
on the ath12k mailing list.

| Step | Command | Effect |
|---|---|---|
| A | `sudo ./install.sh` | power save off (NetworkManager config + immediately with `iw`) |
| B | `sudo ./install.sh --watchdog` | A + a timer that checks every 30 s and reloads ath12k (then removes and rescans the PCI device) only when the stall signature is present |
| C | `sudo ./install.sh --band-24 "<connection name>"` | keep one connection on 2.4 GHz; disabling band steering in the router is better |

`DRY_RUN=1 ./wifi-watchdog.sh` (no root) prints what the watchdog would decide
now. Against the journal of 28 boots it caught 4 of 4 stalls with no false
alarm. `sudo ./recover-wifi.sh --diag-only` logs the current state.

The recovery log `/var/log/vivobook-wifi-recover.log` hides network names and
MAC addresses, but read it before attaching it to a report.

Undo: `sudo ./uninstall.sh`.
