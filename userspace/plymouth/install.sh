#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Plymouth on the ASUS Vivobook S 15 (2880x1620, 212 dpi). Run as root.
#
#   install.sh --scale    kernel parameter plymouth.force-scale=2 (all BLS entries,
#                         /etc/kernel/cmdline). Plymouth picks scale 1 on this panel,
#                         so the spinner and the LUKS dialog are tiny. No initramfs rebuild.
#   install.sh --theme    "vivobook-center" theme (needs ./logo/bgrt-fallback.png from
#                         get-logo.sh), Theme= in /etc/plymouth/plymouthd.conf and an
#                         initramfs rebuild of the running kernel, with a check that no
#                         firmware or module went missing (otherwise the old image is restored)
#   --kver KVER           with --theme: rebuild this kernel's initramfs instead (repeatable)
#   --dry-run             print the commands only
#
# Why: when booting from DT there is no ACPI BGRT and no vendor logo, so the
# stock themes put the spinner at 70% height under a missing logo.
# Backups: /var/lib/vivobook-plymouth/backup-<date>/. Undo: uninstall.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
THEME=vivobook-center
THEME_DST=/usr/share/plymouth/themes/$THEME
CONF=/etc/plymouth/plymouthd.conf
PARAM=plymouth.force-scale=2
WM_SRC=/usr/share/plymouth/themes/spinner/watermark.png
MARK_BEGIN="# >>> vivobook-s15-fedora plymouth"
MARK_END="# <<< vivobook-s15-fedora plymouth"
BK=/var/lib/vivobook-plymouth/backup-$(date +%Y%m%d-%H%M%S)
DO_SCALE=0 DO_THEME=0 DRY=0
KVERS=()

while [ $# -gt 0 ]; do
	case $1 in
		--scale) DO_SCALE=1; shift ;;
		--theme) DO_THEME=1; shift ;;
		--kver) KVERS+=("${2:?}"); shift 2 ;;
		--dry-run) DRY=1; shift ;;
		*) echo "unknown option: $1" >&2; exit 2 ;;
	esac
done
[ $DO_SCALE -eq 1 ] || [ $DO_THEME -eq 1 ] || { sed -n '4,17p' "$0"; exit 2; }
[ $DRY -eq 1 ] || [ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }

run() { if [ $DRY -eq 1 ]; then echo "+ $*"; else "$@"; fi; }
backup() { [ $DRY -eq 1 ] && return 0; mkdir -p "$BK$(dirname "$1")"; [ -e "$1" ] && cp -a "$1" "$BK$1"; return 0; }

# List of firmware files and modules inside an initramfs image.
fw_mod_list() {
	lsinitrd "$1" 2>/dev/null |
		grep -E '^[-dlcbps][rwxsStT-]{9}' |
		sed -E 's/^.*[[:space:]][A-Z][a-z]{2}[[:space:]]+[0-9]{1,2}[[:space:]]+([0-9]{2}:[0-9]{2}|[0-9]{4})[[:space:]]+//; s/ -> .*$//' |
		grep -E '^(usr/)?lib/(firmware|modules)/' | sed -E 's#^usr/##' |
		grep -vE '^lib/modules/[^/]+/(vmlinuz[^/]*|[^/]*\.efi|\.[^/]*\.hmac)$' | LC_ALL=C sort -u
}

rebuild_initramfs() { # KVER
	local kver=$1 img="/boot/initramfs-$1.img" kimg missing
	[ -f "$img" ] || { echo "skipping $kver: no $img"; return 0; }
	# Repeat the --kernel-image argument of the old image (as 50-dracut.install does).
	kimg=$(lsinitrd "$img" 2>/dev/null | sed -n "s/^Arguments:.*--kernel-image '\([^']*\)'.*/\1/p" | head -1)
	local kargs=()
	[ -n "$kimg" ] && [ -f "$kimg" ] && kargs=(--kernel-image "$kimg")
	if [ $DRY -eq 1 ]; then echo "+ dracut -f ${kargs[*]} --kver $kver $img (with firmware/module check)"; return 0; fi
	mkdir -p "$BK"
	fw_mod_list "$img" > "$BK/initramfs-$kver.before.lst"
	cp -a "$img" "$BK/initramfs-$kver.img"
	if ! dracut -f "${kargs[@]}" --kver "$kver" "$img"; then
		echo "ERROR: dracut failed, restoring the old image"; cp -a "$BK/initramfs-$kver.img" "$img"; return 1
	fi
	fw_mod_list "$img" > "$BK/initramfs-$kver.after.lst"
	missing=$(comm -23 "$BK/initramfs-$kver.before.lst" "$BK/initramfs-$kver.after.lst")
	if [ -n "$missing" ]; then
		echo "ERROR: files missing in the new initramfs, restoring the old image:"; printf '%s\n' "$missing"
		cp -a "$BK/initramfs-$kver.img" "$img"; return 1
	fi
	if ! lsinitrd "$img" | grep -q "usr/share/plymouth/themes/$THEME/$THEME.plymouth"; then
		echo "ERROR: theme not in the new initramfs, restoring the old image"; cp -a "$BK/initramfs-$kver.img" "$img"; return 1
	fi
	echo "initramfs $kver: rebuilt, no firmware or module missing"
}

if [ $DO_SCALE -eq 1 ]; then
	backup /etc/kernel/cmdline
	run grubby --update-kernel=ALL --args="$PARAM"
	if [ -f /etc/kernel/cmdline ] && ! grep -qw "$PARAM" /etc/kernel/cmdline; then
		run sed -i -E "s/[[:space:]]*\$/ $PARAM/" /etc/kernel/cmdline
	fi
	echo "scale: active from the next boot"
fi

rc=0
if [ $DO_THEME -eq 1 ]; then
	[ -f "$HERE/logo/bgrt-fallback.png" ] || { echo "missing $HERE/logo/bgrt-fallback.png: run get-logo.sh first"; exit 1; }
	[ -d /usr/share/plymouth/themes/spinner ] || { echo "plymouth-theme-spinner is not installed"; exit 1; }
	if grep -qF "$MARK_BEGIN" "$CONF" 2>/dev/null; then
		echo "$CONF already has our block"
	elif grep -qE '^[[:space:]]*(\[Daemon\]|Theme[[:space:]]*=)' "$CONF" 2>/dev/null; then
		echo "$CONF already has an active [Daemon] or Theme=, not editing it:"; cat "$CONF"; exit 1
	fi
	backup "$CONF"
	run mkdir -p "$THEME_DST"
	# spinner images (throbber, lock, entry) and the Fedora watermark, as in the bgrt theme
	[ -f "$WM_SRC" ] || echo "note: $WM_SRC missing (fedora-logos), no Fedora logo at the bottom"
	for f in /usr/share/plymouth/themes/spinner/*.png; do
		[ "$(basename "$f")" = bgrt-fallback.png ] && continue
		run install -m 0644 "$f" "$THEME_DST/"
	done
	run install -m 0644 "$HERE/logo/bgrt-fallback.png" "$HERE/$THEME.plymouth" "$THEME_DST/"
	run restorecon -R "$THEME_DST" || true
	if ! grep -qF "$MARK_BEGIN" "$CONF" 2>/dev/null; then
		if [ $DRY -eq 1 ]; then echo "+ append [Daemon] Theme=$THEME to $CONF"
		else printf '%s\n[Daemon]\nTheme=%s\n%s\n' "$MARK_BEGIN" "$THEME" "$MARK_END" >> "$CONF"; fi
	fi
	[ ${#KVERS[@]} -gt 0 ] || KVERS=("$(uname -r)")
	for k in "${KVERS[@]}"; do rebuild_initramfs "$k" || rc=1; done
fi
[ $DRY -eq 1 ] || echo "backups: $BK"
exit $rc
