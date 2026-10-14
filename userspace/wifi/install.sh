#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Wi-Fi (WCN7850, ath12k) workarounds for the ASUS Vivobook S 15. Run as root.
# No step disconnects Wi-Fi.
#
#   install.sh                  A: Wi-Fi power save off
#   install.sh --watchdog       A + B: stall watchdog (checks every 30 s, reloads
#                               ath12k only when the stall signature is seen)
#   install.sh --band-24 NAME   C: limit the NetworkManager connection NAME to
#                               2.4 GHz (against routers that push clients between
#                               bands every few minutes); better: disable band
#                               steering / "Smart Connect" in the router
#   --dry-run                   print the steps, change nothing
#
# A: /etc/NetworkManager/conf.d/90-vivobook-wifi-powersave.conf (wifi.powersave=2)
#    and "iw set power_save off" for the running connection.
# Backups: /var/lib/vivobook-wifi/backup-<date>/. Undo: uninstall.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
BK=/var/lib/vivobook-wifi/backup-$(date +%Y%m%d-%H%M%S)
NMCONF=/etc/NetworkManager/conf.d/90-vivobook-wifi-powersave.conf
DO_WD=0
BAND_CONN=""
DRY=0

while [ $# -gt 0 ]; do
	case "$1" in
	--watchdog) DO_WD=1; shift ;;
	--band-24) BAND_CONN=${2:?connection name required}; shift 2 ;;
	--dry-run) DRY=1; shift ;;
	*) echo "unknown option: $1" >&2; exit 2 ;;
	esac
done

if [ $DRY -eq 1 ]; then
	echo "A: write $NMCONF, nmcli general reload conf, iw set power_save off"
	[ $DO_WD -eq 1 ] && echo "B: install /usr/local/sbin/vivobook-wifi-{recover,watchdog}, enable vivobook-wifi-watchdog.timer"
	[ -n "$BAND_CONN" ] && echo "C: nmcli connection modify '$BAND_CONN' 802-11-wireless.band bg"
	exit 0
fi
[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }
mkdir -p "$BK"
echo "backup: $BK"

wl=""
for d in /sys/class/net/*; do [ -d "$d/wireless" ] && wl=$(basename "$d") && break; done

# --- A: power save off ---
[ -e "$NMCONF" ] && cp -a "$NMCONF" "$BK/"
cat > "$NMCONF" <<'CONF'
# vivobook-s15-fedora: Wi-Fi power save off for WCN7850 (ath12k).
# Reason: data path stalls on 7.3 kernels with power save enabled.
# Undo: delete this file.
[connection.90-vivobook-wifi-powersave]
match-device=type:wifi
wifi.powersave=2
CONF
chmod 0644 "$NMCONF"
restorecon "$NMCONF" 2>/dev/null || true
/usr/bin/nmcli general reload conf
if [ -n "$wl" ]; then
	/usr/sbin/iw dev "$wl" set power_save off
	echo "A: $wl: $(/usr/sbin/iw dev "$wl" get power_save)"
fi

# --- B: watchdog ---
if [ "$DO_WD" -eq 1 ]; then
	install -m 0755 "$HERE/recover-wifi.sh" /usr/local/sbin/vivobook-wifi-recover
	install -m 0755 "$HERE/wifi-watchdog.sh" /usr/local/sbin/vivobook-wifi-watchdog
	install -m 0644 "$HERE/vivobook-wifi-watchdog.service" "$HERE/vivobook-wifi-watchdog.timer" /etc/systemd/system/
	restorecon -R /usr/local/sbin /etc/systemd/system 2>/dev/null || true
	systemctl daemon-reload
	systemctl enable --now vivobook-wifi-watchdog.timer
	echo "B: watchdog: $(systemctl is-active vivobook-wifi-watchdog.timer)"
	DRY_RUN=1 /usr/local/sbin/vivobook-wifi-watchdog || true
fi

# --- C: one connection on 2.4 GHz only ---
if [ -n "$BAND_CONN" ]; then
	/usr/bin/nmcli -g connection.id connection show "$BAND_CONN" >/dev/null
	printf '%s\n%s\n' "$BAND_CONN" "$(/usr/bin/nmcli -g 802-11-wireless.band connection show "$BAND_CONN")" > "$BK/band.before"
	/usr/bin/nmcli connection modify "$BAND_CONN" 802-11-wireless.band bg
	echo "C: band=$(/usr/bin/nmcli -g 802-11-wireless.band connection show "$BAND_CONN")"
fi

echo "done. Undo: $HERE/uninstall.sh"
