#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Undo install.sh: remove plymouth.force-scale=2, the theme and our block in
# plymouthd.conf, then rebuild the initramfs of the running kernel
# (or of --kver KVER). Run as root.
set -euo pipefail

THEME=vivobook-center
CONF=/etc/plymouth/plymouthd.conf
PARAM=plymouth.force-scale=2
KVER=$(uname -r)
[ "${1:-}" = --kver ] && KVER=${2:?}
[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }

grubby --update-kernel=ALL --remove-args="$PARAM"
[ -f /etc/kernel/cmdline ] && sed -i -E "s/[[:space:]]*$PARAM//" /etc/kernel/cmdline
if grep -qF "# >>> vivobook-s15-fedora plymouth" "$CONF" 2>/dev/null; then
	sed -i '/# >>> vivobook-s15-fedora plymouth/,/# <<< vivobook-s15-fedora plymouth/d' "$CONF"
fi
rm -rf "/usr/share/plymouth/themes/$THEME"
echo "theme now: $(plymouth-set-default-theme)"
dracut -f --kver "$KVER"
echo "undone; backups of the previous state are in /var/lib/vivobook-plymouth/"
