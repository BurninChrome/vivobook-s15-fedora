#!/bin/bash
# SPDX-License-Identifier: MIT
#
# selftest.sh: check an installed ASUS Vivobook S 15 after a reboot.
# No root needed, read only. Prints PASS / WARN / FAIL per item.
# Exit code: number of FAIL items (0 = all good).
set -u
export LC_ALL=C

fails=0
pass() { printf 'PASS  %s\n' "$*"; }
warn() { printf 'WARN  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; fails=$((fails + 1)); }
have() { command -v "$1" >/dev/null 2>&1; }
DT=/sys/firmware/devicetree/base

# --- machine ---
model=$(tr -d '\0' < "$DT/model" 2>/dev/null)
case "$model" in
	*"Vivobook S 15"*) pass "machine: $model, BIOS $(cat /sys/class/dmi/id/bios_version 2>/dev/null)" ;;
	*) fail "not an ASUS Vivobook S 15 device tree (model: ${model:-none})" ;;
esac
pass "kernel: $(uname -r)"

# --- firmware and DSPs ---
fwdir=""
for d in /usr/lib/firmware/updates/qcom/x1e80100/ASUSTeK/vivobook-s15 /usr/lib/firmware/qcom/x1e80100/ASUSTeK/vivobook-s15; do
	[ -f "$d/qcadsp8380.mbn" ] || [ -f "$d/qcadsp8380.mbn.xz" ] && { fwdir=$d; break; }
done
if [ -n "$fwdir" ]; then pass "ADSP firmware in $fwdir"; else fail "ADSP firmware missing (docs/firmware.md)"; fi
for r in /sys/class/remoteproc/remoteproc*; do
	[ -e "$r/name" ] || continue
	n=$(cat "$r/name"); s=$(cat "$r/state" 2>/dev/null)
	if [ "$s" = running ]; then pass "remoteproc $n: running"; else fail "remoteproc $n: $s"; fi
done

# --- battery ---
bat=/org/freedesktop/UPower/devices/battery_qcom_battmgr_bat
if have upower && upower -i "$bat" 2>/dev/null | grep -q percentage; then
	pass "battery: $(upower -i "$bat" | awk '/percentage/ {print $2}'), $(upower -i "$bat" | awk '/state/ {print $2}')"
else
	fail "no battery device (ADSP firmware or battmgr)"
fi

# --- device tree overlay ---
for n in sound:audio camera@36:front\ camera camera@24:IR\ camera; do
	node=${n%%:*}; what=${n#*:}
	if find "$DT" -maxdepth 5 -name "$node" 2>/dev/null | grep -q .; then pass "DT node for $what ($node)"
	else fail "DT node for $what ($node) missing: overlay not applied to this kernel"; fi
done
if find "$DT" -maxdepth 5 -name 'embedded-controller@76' 2>/dev/null | grep -q .; then
	pass "DT node for the EC present (EXPERIMENTAL_EC=yes)"
else
	pass "DT node for the EC absent (EXPERIMENTAL_EC=no, EC keeps its default fan curve)"
fi

# --- audio ---
if have aplay && aplay -l 2>/dev/null | grep -q 'X1E80100-ASUS-Vivobook-S15'; then
	pass "sound card X1E80100-ASUS-Vivobook-S15"
else
	fail "sound card missing"
fi
if [ -f /usr/share/alsa/ucm2/Qualcomm/x1e80100/ASUS-Vivobook-S15.conf ] &&
	grep -q ASUS-Vivobook-S15.conf /usr/share/alsa/ucm2/Qualcomm/x1e80100/x1e80100.conf 2>/dev/null; then
	pass "UCM profile installed and selected"
else
	fail "UCM profile not installed or not selected in x1e80100.conf"
fi
if have arecord && [ "$(arecord -l 2>/dev/null | grep -c '^card')" -ge 2 ]; then
	pass "capture devices: $(arecord -l | grep -c '^card')"
else
	warn "fewer than 2 capture devices (microphones)"
fi

# --- cameras ---
if have cam; then
	if cam -l 2>/dev/null | grep -q 'camera@36'; then pass "libcamera sees the front camera"
	else fail "libcamera does not list the front camera"; fi
else
	warn "libcamera-tools not installed, front camera not checked"
fi
if lsmod | grep -q '^hm1092'; then pass "IR camera driver hm1092 loaded"; else warn "hm1092 not loaded (kernel without patches 0200-0202?)"; fi
[ -e /dev/howdy-ir ] && pass "/dev/howdy-ir present (Howdy setup)"

# --- keyboard ---
kbd_led=no
for l in /sys/class/leds/*kbd_backlight*; do [ -e "$l" ] && kbd_led=yes; done
if [ "$kbd_led" = yes ]; then pass "keyboard backlight LED"
else warn "no keyboard backlight LED (hid-asus-ec not loaded; HID-BPF setups have none)"; fi

# --- EC and fans ---
if lsmod | grep -q '^qcom_hamoa_ec'; then
	rpm=""
	for h in /sys/class/hwmon/hwmon*; do
		ls "$h"/fan*_input >/dev/null 2>&1 && rpm="$rpm $(cat "$h"/fan*_input | tr '\n' ' ')"
	done
	if [ -n "$rpm" ]; then pass "EC driver loaded, fans (RPM): $(echo $rpm)"; else warn "EC driver loaded but no fan readings"; fi
	journalctl -k -b -q --no-pager 2>/dev/null | grep -q 'Reporting SoC Tj' &&
		pass "EC receives SoC Tj" || warn "no 'Reporting SoC Tj' in the kernel log (or no journal access)"
fi

# --- CPU frequency, GPU, video decoder ---
pol=$(ls -d /sys/devices/system/cpu/cpufreq/policy* 2>/dev/null | wc -l)
if [ "$pol" -ge 3 ]; then pass "cpufreq: $pol policies"; else fail "cpufreq: $pol policies (expected 3; scmi-cpufreq not loaded? modules-load/)"; fi
if ls /dev/dri/renderD* >/dev/null 2>&1; then pass "GPU render node"; else fail "no GPU render node"; fi
if grep -qs 'iris' /sys/class/video4linux/*/name; then pass "video decoder (iris)"; else warn "iris video decoder not found"; fi

# --- image (Silverblue) or hook (Workstation) ---
if [ -e /run/ostree-booted ]; then
	ref=""
	have rpm-ostree && ref=$(rpm-ostree status --booted 2>/dev/null | sed -n 's/^[●*] *//p' | head -1)
	case "$ref" in
		*vivobook-s15*) pass "Silverblue image: $ref" ;;
		*) warn "booted deployment is not a vivobook-s15 image: ${ref:-unknown} (image/README.md)" ;;
	esac
	if [ -f "/usr/lib/modules/$(uname -r)/devicetree" ]; then
		pass "image carries the merged DTB (/usr/lib/modules/$(uname -r)/devicetree)"
	else
		warn "no merged DTB next to the kernel: image not built with image/build-root.sh?"
	fi
	for a in systemd.tpm2_wait=0 plymouth.force-scale=2; do
		grep -qw "$a" /proc/cmdline && pass "kernel argument $a" || warn "kernel argument $a missing (image/kargs.d, bootc switch)"
	done
elif [ -x /usr/lib/kernel/install.d/30-vivobook-s15.install ] || [ -x /etc/kernel/install.d/30-vivobook-s15.install ]; then
	pass "kernel-install hook installed"
else
	fail "kernel-install hook missing: future kernels will boot without the overlay"
fi
if [ -e /etc/kernel/install.d/30-vivobook-audio.install ]; then
	warn "old hook 30-vivobook-audio.install still present: remove it (two hooks would fight)"
fi

echo
if [ $fails -eq 0 ]; then echo "all checks passed"; else echo "$fails check(s) failed"; fi
exit $fails
