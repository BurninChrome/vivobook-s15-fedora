#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Howdy (face login) with the HM1092 IR camera of the ASUS Vivobook S 15,
# Fedora 45 aarch64. Run as root.
#
#   install-howdy.sh install          step 1: COPR repository, packages, camss reader,
#                                     udev rule, config.ini, SELinux module. NO PAM changes.
#                                     Fedora Workstation only; on Silverblue step 1 is part
#                                     of the image (WITH_HOWDY=yes, image/README.md).
#   install-howdy.sh image            step 1 inside a container image build (no udevadm,
#                                     udev rule in /usr/lib/udev/rules.d, no backups)
#   install-howdy.sh add USER         record a face model for USER (howdy add)
#   install-howdy.sh test-cam USER    one recognition attempt without PAM (uses compare.py
#                                     like pam_howdy does; "howdy test" needs X)
#   install-howdy.sh pam [gdm] [sudo] [polkit]
#                                     step 2: PAM (default: gdm sudo). The password always
#                                     stays as fallback: Howdy is "sufficient" BEFORE the
#                                     password, any Howdy failure falls through to it.
#   --dry-run                         as first argument: print what would be done
#
# Undo: uninstall-howdy.sh (PAM only) or uninstall-howdy.sh --purge (everything).
# Backups of changed files and state: /var/lib/vivobook-howdy/.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
STATE=/var/lib/vivobook-howdy
REPO=/etc/yum.repos.d/_copr_starfish-howdy-beta.repo
MARK="# vivobook-howdy (vivobook-s15-fedora)"
UDEV=/etc/udev/rules.d/70-howdy-ir.rules
CONF=/etc/howdy/config.ini

DRY=0
if [ "${1:-}" = --dry-run ]; then DRY=1; shift; fi
if [ $DRY -eq 1 ]; then
	echo "dry run: $0 $*"
	sed -n '/^do_install()/,/^}/p;/^pam_gdm()/,/^}/p;/^pam_sudo()/,/^}/p' "$0"
	exit 0
fi
[ "$(id -u)" = 0 ] || { echo "run as root: sudo $0 $*" >&2; exit 1; }
IMAGE=0
[ "${1:-}" = image ] && IMAGE=1 && UDEV=/usr/lib/udev/rules.d/70-howdy-ir.rules
[ $IMAGE -eq 1 ] || mkdir -p "$STATE"

backup() {	# backup FILE: one-time copy of the original to $STATE/orig/
	[ $IMAGE -eq 1 ] && return 0
	local f=$1 b=$STATE/orig$1
	{ [ -e "$b" ] || [ -e "$b.absent" ]; } && return 0
	mkdir -p "$(dirname "$b")"
	if [ -e "$f" ]; then cp -a "$f" "$b"; else touch "$b.absent"; fi
}

site_file() { rpm -ql howdy | grep '/howdy/recorders/video_capture.py$' | head -1; }

do_install() {
	if [ $IMAGE -eq 0 ] && [ -e /run/ostree-booted ]; then
		echo "Silverblue: /usr is read-only. Build the image with WITH_HOWDY=yes (image/README.md)," >&2
		echo "boot it, then continue with: sudo $0 add USER" >&2
		exit 1
	fi
	# 1. COPR starfish/howdy-beta: the only repository with fedora-45-aarch64 builds
	#    (howdy 3.0.0, dlib 20.0). Read its spec before trusting it.
	backup "$REPO"
	cat > "$REPO" <<'R'
[copr:copr.fedorainfracloud.org:starfish:howdy-beta]
name=Copr repo for howdy-beta owned by starfish
baseurl=https://download.copr.fedorainfracloud.org/results/starfish/howdy-beta/fedora-$releasever-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/starfish/howdy-beta/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
R
	dnf -y install howdy python3-numpy v4l-utils python3-pillow checkpolicy policycoreutils patch
	# The image keeps the repository file but not the dnf cache.

	# 2. camss reader + the 5-line reader selection in video_capture.py
	local vc rec
	vc=$(site_file); [ -n "$vc" ] || { echo "video_capture.py of the howdy package not found"; exit 1; }
	rec=$(dirname "$vc")
	backup "$vc"
	install -m 0644 "$HERE/camss_reader.py" "$rec/camss_reader.py"
	[ $IMAGE -eq 1 ] || echo "$rec/camss_reader.py" > "$STATE/camss_reader.path"
	if ! grep -q 'recording_plugin == "camss"' "$vc"; then
		patch --no-backup-if-mismatch -p2 -d "$rec" < "$HERE/video_capture-camss.patch"
	fi
	python3 -m py_compile "$vc" "$rec/camss_reader.py"

	# 3. udev: /dev/howdy-ir -> msm_vfe1_video0
	install -m 0644 "$HERE/70-howdy-ir.rules" "$UDEV"
	if [ $IMAGE -eq 0 ]; then
		udevadm control --reload
		udevadm trigger --subsystem-match=video4linux || true
	fi

	# 4. config.ini (comments kept; only keys of [video] and [core] are changed)
	backup "$CONF"
	python3 - "$CONF" <<'P'
import re, sys
p = sys.argv[1]
lines = open(p).read().splitlines()
want = {
    "video": {"device_path": "/dev/howdy-ir", "recording_plugin": "camss",
              "max_height": "360", "timeout": "5", "dark_threshold": "60",
              "camss_csid": "msm_csid1", "camss_vfe": "msm_vfe1_rdi0",
              "camss_rotate": "180", "camss_mirror": "false",
              "camss_exposure": "", "camss_analogue_gain": "", "camss_digital_gain": ""},
    "core": {"detection_notice": "true", "abort_if_ssh": "true", "abort_if_lid_closed": "true"},
}
sec, seen, out = None, set(), []
def flush(s):
    for k, v in want.get(s, {}).items():
        if (s, k) not in seen:
            out.append("%s = %s" % (k, v))
for ln in lines:
    m = re.match(r"\s*\[(\w+)\]", ln)
    if m:
        flush(sec); sec = m.group(1)
    else:
        k = re.match(r"\s*([A-Za-z_]+)\s*=", ln)
        if k and sec in want and k.group(1) in want[sec]:
            ln = "%s = %s" % (k.group(1), want[sec][k.group(1)]); seen.add((sec, k.group(1)))
    out.append(ln)
flush(sec)
open(p, "w").write("\n".join(out) + "\n")
P
	grep -nE '^(device_path|recording_plugin|camss_|timeout|max_height|dark_threshold|detection_notice|abort_if)' "$CONF"

	# 5. SELinux (GDM runs in xdm_t), module built from source
	local t
	t=$(mktemp -d)
	checkmodule -M -m -o "$t/howdy_camss.mod" "$HERE/howdy_camss.te"
	semodule_package -o "$t/howdy_camss.pp" -m "$t/howdy_camss.mod"
	semodule -i "$t/howdy_camss.pp"
	rm -rf "$t"
	semodule -l | grep -w howdy_camss

	[ $IMAGE -eq 1 ] && return 0
	echo "STEP 1 DONE. Next:"
	echo "  sudo $0 add USER        (look at the camera for about 5 s)"
	echo "  sudo $0 test-cam USER   (one recognition attempt)"
	echo "  sudo $0 pam             (only when test-cam recognises you)"
}

do_add() {
	local u=${1:?user name required}
	id "$u" >/dev/null
	[ -e /dev/howdy-ir ] || { echo "/dev/howdy-ir missing: IR camera not available"; exit 1; }
	howdy -U "$u" add -y
	howdy -U "$u" list
}

do_test() {
	local u=${1:?user name required} cmp rc
	cmp=$(rpm -ql howdy | grep '/howdy/compare.py$' | head -1)
	echo "compare.py for $u (0 = recognised, 10 = no model, 11 = timeout, 12 = aborted, 13 = frames too dark, 14 = camera error):"
	set +e; python3 "$cmp" "$u"; rc=$?; set -e
	echo "exit code: $rc"
}

pam_line="-auth      sufficient   pam_howdy.so $MARK"

pam_gdm() {
	# Fedora 45 keeps the vendor file in /usr/lib/pam.d; a file in /etc/pam.d
	# takes precedence. Removing the override restores the vendor state exactly.
	local f=/etc/pam.d/gdm-password-auth-substack src=/usr/lib/pam.d/gdm-password-auth-substack
	if [ -e "$f" ] && ! grep -q "vivobook-howdy" "$f"; then
		echo "$f exists and is not ours, skipping GDM"; return
	fi
	{ echo "$pam_line"; grep -v "vivobook-howdy" "$src"; } > "$f.new"
	chmod 0644 "$f.new"; mv "$f.new" "$f"
	restorecon "$f" || true
	echo "gdm" >> "$STATE/pam.list"
	echo "--- $f:"; cat "$f"
}

pam_polkit() {
	local f=/etc/pam.d/polkit-1 src=/usr/lib/pam.d/polkit-1
	if [ -e "$f" ] && ! grep -q "vivobook-howdy" "$f"; then
		echo "$f exists and is not ours, skipping polkit"; return
	fi
	{ head -1 "$src"; echo "$pam_line"; tail -n +2 "$src" | grep -v "vivobook-howdy"; } > "$f.new"
	chmod 0644 "$f.new"; mv "$f.new" "$f"
	restorecon "$f" || true
	echo "polkit" >> "$STATE/pam.list"
	echo "--- $f:"; cat "$f"
}

pam_sudo() {
	# /etc/pam.d/sudo belongs to the sudo package: backup + one marked line after #%PAM-1.0
	local f=/etc/pam.d/sudo
	backup "$f"
	grep -q "vivobook-howdy" "$f" && { echo "sudo: already configured"; return; }
	awk -v l="$pam_line" 'NR==1 && /^#%PAM/ {print; print l; next} NR==1 {print l} {print}' "$f" > "$f.new"
	chmod --reference="$f" "$f.new"; chown --reference="$f" "$f.new"; mv "$f.new" "$f"
	restorecon "$f" || true
	echo "sudo" >> "$STATE/pam.list"
	echo "--- $f:"; cat "$f"
}

do_pam() {
	local lib
	lib=$(rpm -ql howdy | grep '/security/pam_howdy.so$' | head -1)
	{ [ -n "$lib" ] && [ -e "$lib" ]; } || { echo "pam_howdy.so missing: run 'install' first"; exit 1; }
	[ -e /dev/howdy-ir ] || { echo "/dev/howdy-ir missing: IR camera not working, PAM unchanged"; exit 1; }
	ls /etc/howdy/models/*.dat >/dev/null 2>&1 || { echo "no face models (run 'add' first), PAM unchanged"; exit 1; }
	[ $# -gt 0 ] || set -- gdm sudo
	for t in "$@"; do
		case $t in
			gdm) pam_gdm ;;
			sudo) pam_sudo ;;
			polkit) pam_polkit ;;
			*) echo "unknown PAM target: $t"; exit 2 ;;
		esac
	done
	sort -u -o "$STATE/pam.list" "$STATE/pam.list"
	echo "PAM changed: $(tr '\n' ' ' < "$STATE/pam.list")"
	echo "TEST NOW in a new terminal: sudo -k; sudo true (face or password)."
	echo "Keep this root shell open until it works. Undo: $HERE/uninstall-howdy.sh"
}

cmd=${1:-}
shift || true
case $cmd in
	install|image) do_install ;;
	add) do_add "$@" ;;
	test-cam) do_test "$@" ;;
	pam) do_pam "$@" ;;
	*) sed -n '4,24p' "$0"; exit 2 ;;
esac
