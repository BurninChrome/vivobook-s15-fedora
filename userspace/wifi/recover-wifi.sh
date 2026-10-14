#!/bin/bash
# SPDX-License-Identifier: MIT
#
# recover-wifi.sh: recover a stalled WCN7850 (ath12k) card without a reboot.
#
# Meant for this symptom: the card associates with the AP, but the 4-way
# handshake never completes, CTRL-EVENT-BEACON-LOSS after a few seconds,
# reason=4, again and again; NetworkManager reports "link timed out",
# "supplicant-timeout" or "ssid-not-found". Neither NetworkManager nor
# reconnecting fixes it.
#
# Run as root (sudo, or from the watchdog service).
#
# Usage:
#   recover-wifi.sh              level 1 (reload the modules), level 2 if that fails
#   recover-wifi.sh --level 2    level 2 right away (remove the PCI device and rescan)
#   recover-wifi.sh --diag-only  only log the state, change nothing
#
# Log: /var/log/vivobook-wifi-recover.log (appended). Network names and BSSIDs
# are not logged, but read the log before attaching it to a bug report.
set -u

# PCI address of the card and its root port; found from the network interface,
# remembered in /run in case the interface is gone. Default: S5507QAD layout.
PCI_DEV=0004:01:00.0
PCI_ROOT=0004:00:00.0
PCI_CACHE=/run/vivobook-wifi.pci
LOG=/var/log/vivobook-wifi-recover.log
LEVEL=1
DIAG_ONLY=0

while [ $# -gt 0 ]; do
	case "$1" in
	--level) LEVEL="$2"; shift 2 ;;
	--diag-only) DIAG_ONLY=1; shift ;;
	*) echo "unknown option: $1" >&2; exit 2 ;;
	esac
done

[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }

exec > >(tee -a "$LOG") 2>&1
log() { echo "[$(date '+%F %T')] $*"; }

wifi_dev() {
	for d in /sys/class/net/*; do
		[ -d "$d/wireless" ] && { basename "$d"; return; }
	done
}

find_pci() {
	local wl dev
	wl=$(wifi_dev)
	if [ -n "$wl" ] && dev=$(readlink -f "/sys/class/net/$wl/device") && [ -e "$dev/vendor" ]; then
		PCI_DEV=$(basename "$dev")
		PCI_ROOT=$(basename "$(dirname "$dev")")
		echo "$PCI_DEV $PCI_ROOT" > "$PCI_CACHE"
	elif [ -s "$PCI_CACHE" ]; then
		read -r PCI_DEV PCI_ROOT < "$PCI_CACHE"
	fi
}

snapshot() {
	local wl
	wl=$(wifi_dev)
	log "--- state: $1 ---"
	log "interface: ${wl:-NONE}"
	/usr/bin/nmcli -t -f DEVICE,TYPE,STATE device 2>&1 | sed 's/^/    nmcli: /'
	if [ -n "$wl" ]; then
		/usr/sbin/iw dev "$wl" link 2>&1 | grep -vE '^\s*SSID:' |
			sed -E 's/([0-9a-f]{2}:){5}[0-9a-f]{2}/<mac>/g; s/^/    iw: /'
		/usr/sbin/iw dev "$wl" get power_save 2>&1 | sed 's/^/    iw: /'
		/usr/sbin/wpa_cli -i "$wl" status 2>/dev/null | grep -E '^(wpa_state|freq|key_mgmt)=' | sed 's/^/    wpa: /'
	fi
	/usr/bin/journalctl -k -b --no-pager -o short-monotonic 2>/dev/null |
		grep -iE 'ath12k|mhi|wlP|wlan' | tail -n 15 |
		sed -E 's/([0-9a-f]{2}:){5}[0-9a-f]{2}/<mac>/g; s/^/    dmesg: /'
	/usr/bin/journalctl -b --no-pager -o short-monotonic -t wpa_supplicant --since=-10min 2>/dev/null |
		grep -E 'BEACON-LOSS|DISCONNECTED|CONNECTED|SSID-TEMP' | tail -n 10 |
		sed -E 's/(bssid|ssid)=[^ ]*/\1=<hidden>/g; s/([0-9a-f]{2}:){5}[0-9a-f]{2}/<mac>/g; s/^/    wpa: /'
}

wait_connected() {
	# wait up to $1 seconds for NetworkManager to report a connected Wi-Fi device
	local i
	for ((i = 0; i < $1; i++)); do
		if /usr/bin/nmcli -t -f TYPE,STATE device 2>/dev/null | grep -q '^wifi:connected$'; then
			return 0
		fi
		sleep 1
	done
	return 1
}

wait_iface() {
	local i
	for ((i = 0; i < $1; i++)); do
		[ -n "$(wifi_dev)" ] && return 0
		sleep 1
	done
	return 1
}

level1() {
	log "LEVEL 1: rmmod ath12k_wifi7 ath12k, modprobe ath12k_wifi7"
	/usr/sbin/modprobe -r ath12k_wifi7 ath12k || log "modprobe -r failed: $?"
	sleep 2
	/usr/sbin/modprobe ath12k_wifi7 || log "modprobe failed: $?"
	wait_iface 30 || { log "no interface after 30 s"; return 1; }
	wait_connected 60
}

level2() {
	log "LEVEL 2: remove $PCI_DEV from the PCI bus and rescan port $PCI_ROOT"
	/usr/sbin/modprobe -r ath12k_wifi7 ath12k 2>/dev/null
	if [ -e /sys/bus/pci/devices/$PCI_DEV/remove ]; then
		echo 1 > /sys/bus/pci/devices/$PCI_DEV/remove
	fi
	sleep 3
	if [ -e /sys/bus/pci/devices/$PCI_ROOT/rescan ]; then
		echo 1 > /sys/bus/pci/devices/$PCI_ROOT/rescan
	else
		echo 1 > /sys/bus/pci/rescan
	fi
	sleep 2
	/usr/sbin/modprobe ath12k_wifi7 2>/dev/null
	wait_iface 30 || { log "no interface after 30 s"; return 1; }
	wait_connected 60
}

log "=== recover-wifi.sh start (level=$LEVEL diag_only=$DIAG_ONLY, kernel $(uname -r)) ==="
find_pci
snapshot "before"
[ "$DIAG_ONLY" -eq 1 ] && { log "diagnostics only, done"; exit 0; }

rc=1
if [ "$LEVEL" -le 1 ]; then
	if level1; then
		rc=0
	else
		log "level 1 did not restore the connection"
	fi
fi
if [ $rc -ne 0 ]; then
	if level2; then
		rc=0
	else
		log "level 2 did not restore the connection; only a reboot is left"
	fi
fi

snapshot "after"
log "=== done, result: $([ $rc -eq 0 ] && echo CONNECTED || echo FAILED) ==="
exit $rc
