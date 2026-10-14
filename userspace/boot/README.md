# Boot time after the LUKS password

Measured on Fedora 45: about 95 s from the LUKS password to the GDM screen,
7.9 s after the two fixes below. Both are safe to undo.

## 1. `systemd.tpm2_wait=0` (saves about 74 s)

The firmware reports a TPM (fTPM), but Linux has no driver for it yet, so
`/dev/tpm*` never appears. systemd waits for it twice (in the initrd and in the
system) until the timeout. `systemd-tpm2-generator(8)`: with
`systemd.tpm2_wait=0` the wait target is not inserted.

```bash
sudo grubby --update-kernel=ALL --args=systemd.tpm2_wait=0
echo "$(cat /etc/kernel/cmdline) systemd.tpm2_wait=0" | sudo tee /etc/kernel/cmdline   # future kernels
```

Undo: `sudo grubby --update-kernel=ALL --remove-args=systemd.tpm2_wait=0` and
remove the parameter from `/etc/kernel/cmdline`. Remove it as well once a TPM
driver exists and you want to use the TPM (e.g. for LUKS unlocking).

## 2. Mask the NetworkManager `04-iscsi` dispatcher script (saves about 17 s)

The script runs `systemctl reload iscsi.service` on every connection change.
That job waits for `network-online.target`, and `remote-fs.target` (needed by
`systemd-user-sessions` and GDM) is ordered after `iscsi.service`, so GDM waits
for Wi-Fi. A laptop without iSCSI targets does not need it.

```bash
sudo ln -s /dev/null /etc/NetworkManager/dispatcher.d/04-iscsi
```

Files in `/etc/NetworkManager/dispatcher.d/` override those in `/usr/lib`;
a symlink to `/dev/null` is the standard way to mask one. Undo: remove the
symlink. Removing the `iscsi-initiator-utils` package instead would also
remove libvirt and udisks2-iscsi.
