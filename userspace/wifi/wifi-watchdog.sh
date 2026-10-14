#!/bin/bash
# SPDX-License-Identifier: MIT
#
# wifi-watchdog.sh: detect the ath12k data path stall and start the recovery.
# Called every 30 s by vivobook-wifi-watchdog.timer (installed by install.sh).
#
# Signature of the stall (seen on 7.3 kernels): the card associates with the
# AP ("Associated with"), but the 4-way handshake never completes, followed by
# BEACON-LOSS or "Authentication with ... timed out.". Condition within WINDOW:
#   - NetworkManager has no connected Wi-Fi device,
#   - no CTRL-EVENT-CONNECTED,
#   - BEACON-LOSS >= 2 or "Associated with" >= 2 or an authentication timeout,
#   - no sign of a wrong password (WRONG_KEY / "pre-shared key may be incorrect").
# A plain loss of signal gives no associations without handshake, so it is
# not caught. Rate limit: at most one recovery per COOLDOWN seconds.
#
# DRY_RUN=1 in the environment: only print the decision.
set -u

WINDOW=-2min
COOLDOWN=900
STAMP=/run/vivobook-wifi-watchdog.last
RECOVER=${RECOVER:-/usr/local/sbin/vivobook-wifi-recover}
DRY_RUN=${DRY_RUN:-0}

if ! /usr/bin/nmcli -t -f WIFI general 2>/dev/null | grep -q enabled; then
	[ "$DRY_RUN" = 1 ] && echo "OK: Wi-Fi radio is off"
	exit 0
fi
if /usr/bin/nmcli -t -f TYPE,STATE device 2>/dev/null | grep -q '^wifi:connected$'; then
	[ "$DRY_RUN" = 1 ] && echo "OK: Wi-Fi connected"
	exit 0
fi

wpa=$(/usr/bin/journalctl -b --no-pager -o cat -t wpa_supplicant --since="$WINDOW" 2>/dev/null)
loss=$(grep -c 'CTRL-EVENT-BEACON-LOSS' <<<"$wpa")
assoc=$(grep -c ': Associated with ' <<<"$wpa")
authto=$(grep -c 'Authentication with .* timed out' <<<"$wpa")
conn=$(grep -c 'CTRL-EVENT-CONNECTED' <<<"$wpa")
badkey=$(grep -cE 'WRONG_KEY|pre-shared key may be incorrect' <<<"$wpa")

msg="beacon-loss=$loss assoc=$assoc auth-timeout=$authto connected=$conn wrong-key=$badkey (window $WINDOW)"

if [ "$conn" -ne 0 ] || [ "$badkey" -ne 0 ]; then
	[ "$DRY_RUN" = 1 ] && echo "OK: $msg"
	exit 0
fi
if ! { [ "$loss" -ge 2 ] || [ "$assoc" -ge 2 ] || [ "$authto" -ge 1 ]; }; then
	[ "$DRY_RUN" = 1 ] && echo "OK: $msg"
	exit 0
fi

if [ "$DRY_RUN" = 1 ]; then
	echo "STALL DETECTED: $msg (DRY_RUN, doing nothing)"
	exit 0
fi

now=$(date +%s)
if [ -f "$STAMP" ] && [ $((now - $(cat "$STAMP"))) -lt "$COOLDOWN" ]; then
	echo "stall detected ($msg), but the cooldown is active; skipping"
	exit 0
fi
echo "$now" > "$STAMP"
echo "ath12k stall detected ($msg); running $RECOVER"
exec "$RECOVER"
