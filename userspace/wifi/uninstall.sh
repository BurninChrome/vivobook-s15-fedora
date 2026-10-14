#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Undo install.sh (Wi-Fi workarounds). Run as root. Does not disconnect Wi-Fi.
set -uo pipefail

[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }

# B: watchdog
systemctl disable --now vivobook-wifi-watchdog.timer 2>/dev/null
rm -f /etc/systemd/system/vivobook-wifi-watchdog.timer /etc/systemd/system/vivobook-wifi-watchdog.service
rm -f /usr/local/sbin/vivobook-wifi-watchdog /usr/local/sbin/vivobook-wifi-recover /run/vivobook-wifi-watchdog.last
systemctl daemon-reload

# C: restore the band of the connection changed last (empty = both bands)
for f in $(ls -1d /var/lib/vivobook-wifi/backup-*/band.before 2>/dev/null | sort -r); do
	{ read -r conn; read -r band; } < "$f"
	if [ -n "$conn" ] && /usr/bin/nmcli -g connection.id connection show "$conn" >/dev/null 2>&1; then
		/usr/bin/nmcli connection modify "$conn" 802-11-wireless.band "$band"
		echo "C: band restored"
	fi
	break
done

# A: power save back to the NetworkManager/driver default (on)
rm -f /etc/NetworkManager/conf.d/90-vivobook-wifi-powersave.conf
/usr/bin/nmcli general reload conf
for d in /sys/class/net/*; do
	[ -d "$d/wireless" ] && /usr/sbin/iw dev "$(basename "$d")" set power_save on && break
done

echo "undone. The recovery log stays in /var/log/vivobook-wifi-recover.log, backups in /var/lib/vivobook-wifi/"
