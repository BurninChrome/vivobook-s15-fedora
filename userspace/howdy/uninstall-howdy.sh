#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Undo install-howdy.sh. Run as root.
#
#   uninstall-howdy.sh           remove the PAM integration (GDM, sudo, polkit);
#                                Howdy stays installed, login with password only
#   uninstall-howdy.sh --purge   also restore config.ini and video_capture.py, remove
#                                the camss reader, udev rule, SELinux module, the howdy
#                                packages and the COPR repository. Face models
#                                (/etc/howdy/models) are copied to
#                                /var/lib/vivobook-howdy/models-<date>/ first.
#
# Emergency without this script (text console Ctrl+Alt+F3 or rescue mode):
# delete /etc/pam.d/gdm-password-auth-substack and /etc/pam.d/polkit-1 (only if
# they contain "vivobook-howdy") and remove the "vivobook-howdy" line from
# /etc/pam.d/sudo. The password works all the time: Howdy is only "sufficient".
set -euo pipefail

STATE=/var/lib/vivobook-howdy
# Matches the marker of this project and of earlier local installations.
MARK="vivobook-howdy"
PURGE=0
[ "${1:-}" = --purge ] && PURGE=1
[ "$(id -u)" = 0 ] || { echo "run as root: sudo $0" >&2; exit 1; }

# 1. PAM: our overrides in /etc/pam.d are removed completely
for f in /etc/pam.d/gdm-password-auth-substack /etc/pam.d/polkit-1; do
	if [ -e "$f" ] && grep -q "$MARK" "$f"; then
		rm -f "$f"; echo "removed $f (the vendor file in /usr/lib/pam.d applies again)"
	fi
done
# sudo: only our line is removed
f=/etc/pam.d/sudo
if grep -q "$MARK" "$f"; then
	grep -v "$MARK" "$f" > "$f.new"
	chmod --reference="$f" "$f.new"; chown --reference="$f" "$f.new"; mv "$f.new" "$f"
	restorecon "$f" || true
	echo "removed the Howdy line from $f"
fi
rm -f "$STATE/pam.list"
if grep -rl "pam_howdy" /etc/pam.d/ 2>/dev/null; then
	echo "WARNING: the files above still mention pam_howdy (not ours), check them by hand"
else
	echo "PAM: no pam_howdy left in /etc/pam.d"
fi
cmp -s /etc/pam.d/sudo "$STATE/orig/etc/pam.d/sudo" 2>/dev/null && echo "sudo: identical to the original backup"
[ "$PURGE" = 1 ] || { echo "DONE (PAM). Full removal: $0 --purge"; exit 0; }

# 2. face models: keep a copy
if ls /etc/howdy/models/*.dat >/dev/null 2>&1; then
	d=$STATE/models-$(date +%Y%m%d-%H%M%S); mkdir -p "$d"; cp -a /etc/howdy/models/. "$d/"
	chmod 700 "$d"; echo "face models copied to $d"
fi
# 3. camss reader and the change in video_capture.py
if [ -s "$STATE/camss_reader.path" ]; then rm -f "$(cat "$STATE/camss_reader.path")"; fi
vc=$(rpm -ql howdy 2>/dev/null | grep '/howdy/recorders/video_capture.py$' | head -1 || true)
if [ -n "$vc" ] && [ -e "$STATE/orig$vc" ]; then cp -a "$STATE/orig$vc" "$vc"; echo "restored $vc"; fi
# 4. udev, SELinux
rm -f /etc/udev/rules.d/70-howdy-ir.rules && udevadm control --reload || true
if semodule -l | grep -qw howdy_camss; then semodule -r howdy_camss || true; fi
# 5. packages and repository (config.ini, %config(noreplace), stays as .rpmsave)
dnf -y remove howdy howdy-data python3-dlib python3-keyboard python3-pyv4l2 2>&1 | tail -5 || true
REPO=/etc/yum.repos.d/_copr_starfish-howdy-beta.repo
if [ -e "$STATE/orig$REPO.absent" ]; then rm -f "$REPO"; elif [ -e "$STATE/orig$REPO" ]; then cp -a "$STATE/orig$REPO" "$REPO"; fi
echo "DONE (--purge). Backups of the originals stay in $STATE/orig/."
