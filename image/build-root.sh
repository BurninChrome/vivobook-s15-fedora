#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Runs inside the image build (image/Containerfile), as root, after the support
# files from stage 1 were copied to /. Usage: build-root.sh SRC
#   SRC   read-only checkout of this repository, including image/local/
#
# Settings (environment, from the Containerfile build arguments):
#   EXPERIMENTAL_EC=no|yes    EC node in the DTB, allow_suspend for qcom-hamoa-ec
#   WITH_HOWDY=yes|no         Howdy with the IR camera (COPR starfish/howdy-beta)
#   WITH_WIFI=yes|no          Wi-Fi power save off and the ath12k stall watchdog
#   EXTRA_PACKAGES="..."      more packages to install
#   ALLOW_NO_FIRMWARE=no|yes  build without the ASUS firmware (CI only: no battery,
#                             audio or GPU on the laptop)
set -euo pipefail

SRC=${1:?usage: build-root.sh SRC}
LOCAL=$SRC/image/local
LIB=/usr/libexec/vivobook-s15
FWDIR=/usr/lib/firmware/updates/qcom/x1e80100/ASUSTeK/vivobook-s15
EXPERIMENTAL_EC=${EXPERIMENTAL_EC:-no}
WITH_HOWDY=${WITH_HOWDY:-yes}
WITH_WIFI=${WITH_WIFI:-yes}
EXTRA_PACKAGES=${EXTRA_PACKAGES:-}
ALLOW_NO_FIRMWARE=${ALLOW_NO_FIRMWARE:-no}
KPKGS=(kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra)

step() { printf '\n=== vivobook-s15: %s\n' "$*"; }

# dnf for this build: keep downloaded packages in the cache mount
# (image/Containerfile) and never wait forever on a stalled mirror.
mkdir -p /etc/dnf/libdnf5.conf.d /run/vivobook-bin
printf '[main]\nkeepcache=1\nretries=10\n' > /etc/dnf/libdnf5.conf.d/90-vivobook-build.conf
install -m 0755 "$SRC"/image/dnf-retry /run/vivobook-bin/dnf
export PATH=/run/vivobook-bin:$PATH

# --- 1. kernel ---
shopt -s nullglob
rpms=()
uki_rpm=""
for f in "$LOCAL"/rpms/*.rpm; do
	case $(basename "$f") in
	kernel-uki-dtbloader-*) uki_rpm=$f ;;
	*) rpms+=("$f") ;;
	esac
done
shopt -u nullglob
if [ ${#rpms[@]} -gt 0 ]; then
	step "kernel from image/local/rpms (${#rpms[@]} packages)"
	old=$(rpm -q --qf '%{VERSION}-%{RELEASE}\n' kernel-core)
	dnf -y install "${rpms[@]}"
	for v in $old; do
		case $v in *.vivobook*) continue ;; esac
		rm_list=()
		for n in "${KPKGS[@]}"; do rpm -q "$n-$v" >/dev/null 2>&1 && rm_list+=("$n-$v"); done
		[ ${#rm_list[@]} -eq 0 ] || dnf -y remove "${rm_list[@]}"
	done
else
	step "no image/local/rpms: keeping the stock kernel (no cameras, no Fn keys, no EC)"
fi
mapfile -t kvers < <(ls /usr/lib/modules)
[ ${#kvers[@]} -eq 1 ] || { echo "expected one kernel in /usr/lib/modules, found: ${kvers[*]}" >&2; exit 1; }
KVER=${kvers[0]}
echo "kernel: $KVER"

# --- 2. packages ---
step "packages"
# dtc: fdtoverlay for apply-dtb below; cpio: unpack kernel-uki-dtbloader;
# libcamera-tools and v4l-utils: camera checks in tools/selftest.sh and
# userspace/camera/set-digital-gain.sh.
# shellcheck disable=SC2086
dnf -y install --setopt=install_weak_deps=False dtc cpio libcamera-tools v4l-utils $EXTRA_PACKAGES

# --- 2a. UKI ---
# Fedora boots X1E laptops from a UKI whose stub (stubble) picks the DTB from
# its .dtbauto sections (docs/dtb-delivery.md). kernel-uki-dtbloader ships it as
# vmlinuz-dtbloader.efi, but the package replaces kernel-core (they conflict),
# and ostree boots /usr/lib/modules/KVER/vmlinuz. So kernel-core stays
# installed and only the UKI is taken from the package, over its vmlinuz.
step "UKI: vmlinuz-dtbloader.efi -> /usr/lib/modules/$KVER/vmlinuz"
kv=$(rpm -q --qf '%{VERSION}-%{RELEASE}' kernel-core)
U=$(mktemp -d)
if [ -z "$uki_rpm" ]; then
	case $kv in
	*.vivobook*) echo "kernel-uki-dtbloader-$kv.aarch64.rpm missing in image/local/rpms" >&2; exit 1 ;;
	esac
	dnf -y download --destdir "$U" "kernel-uki-dtbloader-$kv.aarch64"
	uki_rpm=$(ls "$U"/kernel-uki-dtbloader-*.rpm)
fi
case $(basename "$uki_rpm") in
	"kernel-uki-dtbloader-$kv".*) ;;
	*) echo "$(basename "$uki_rpm") does not match kernel-core-$kv" >&2; exit 1 ;;
esac
(cd "$U" && rpm2cpio "$uki_rpm" | cpio -idm --quiet "*/vmlinuz-dtbloader.efi")
install -m 0755 "$U/lib/modules/$KVER/vmlinuz-dtbloader.efi" "/usr/lib/modules/$KVER/vmlinuz"
rm -rf "$U"
# The FIPS HMAC belongs to the plain kernel image; it no longer matches.
rm -f "/usr/lib/modules/$KVER/.vmlinuz.hmac"

# --- 3. firmware ---
shopt -s nullglob
fw=("$LOCAL"/firmware/*.mbn "$LOCAL"/firmware/*.elf)
shopt -u nullglob
if [ ${#fw[@]} -gt 0 ]; then
	step "firmware (${#fw[@]} files) -> $FWDIR"
	install -D -m 0644 -t "$FWDIR" "${fw[@]}"
elif [ "$ALLOW_NO_FIRMWARE" = yes ]; then
	step "WARNING: no firmware in image/local/firmware (ALLOW_NO_FIRMWARE=yes)"
else
	echo "no firmware in image/local/firmware: run image/fetch-local.sh first (docs/firmware.md)" >&2
	exit 1
fi

# --- 4. configuration of the support files ---
step "/etc/vivobook-s15.conf: EXPERIMENTAL_EC=$EXPERIMENTAL_EC"
cat > /etc/vivobook-s15.conf <<EOF
# /etc/vivobook-s15.conf: read by $LIB/apply-dtb.
# Silverblue: the DTB is merged when the image is built, so this value is fixed
# in the image. To change it, rebuild: sudo image/build.sh --ec yes|no
# EXPERIMENTAL: read /usr/share/doc/vivobook-s15-support/ec-fan-control.md first.
EXPERIMENTAL_EC=$EXPERIMENTAL_EC
EOF

# --- 5. UCM profile ---
step "UCM profile"
"$LIB"/apply-ucm
grep -q ASUS-Vivobook-S15.conf /usr/share/alsa/ucm2/Qualcomm/x1e80100/x1e80100.conf

# --- 6. device tree into the kernel image ---
step "DTB overlay -> /usr/lib/modules/$KVER/vmlinuz"
"$LIB"/apply-dtb "$KVER"
python3 "$LIB"/patch-vmlinuz-dtb.py --verify --vmlinuz "/usr/lib/modules/$KVER/vmlinuz"

# --- 7. suspend ---
step "suspend: s2idle"
install -D -m 0644 "$SRC"/userspace/suspend/50-vivobook-s15-s2idle.conf \
	/usr/lib/systemd/sleep.conf.d/50-vivobook-s15-s2idle.conf
if [ "$EXPERIMENTAL_EC" = yes ]; then
	install -D -m 0644 "$SRC"/userspace/suspend/vivobook-s15-ec.conf /usr/lib/modprobe.d/vivobook-s15-ec.conf
fi

# --- 8. boot: kernel arguments, iSCSI dispatcher ---
step "boot: kargs.d, NetworkManager 04-iscsi"
install -D -m 0644 -t /usr/lib/bootc/kargs.d "$SRC"/image/kargs.d/*.toml
if [ -e /usr/lib/NetworkManager/dispatcher.d/04-iscsi ]; then
	ln -sf /dev/null /etc/NetworkManager/dispatcher.d/04-iscsi
fi

# --- 9. Wi-Fi ---
if [ "$WITH_WIFI" = yes ]; then
	step "Wi-Fi: power save off, stall watchdog"
	cat > /usr/lib/NetworkManager/conf.d/90-vivobook-wifi-powersave.conf <<'EOF'
# vivobook-s15-fedora: Wi-Fi power save off for WCN7850 (ath12k).
# Reason: data path stalls on 7.3 kernels with power save enabled.
# Override: a file with the same name in /etc/NetworkManager/conf.d/.
[connection.90-vivobook-wifi-powersave]
match-device=type:wifi
wifi.powersave=2
EOF
	install -m 0755 "$SRC"/userspace/wifi/recover-wifi.sh /usr/libexec/vivobook-wifi-recover
	sed 's|/usr/local/sbin/vivobook-wifi-recover|/usr/libexec/vivobook-wifi-recover|' \
		"$SRC"/userspace/wifi/wifi-watchdog.sh > /usr/libexec/vivobook-wifi-watchdog
	chmod 0755 /usr/libexec/vivobook-wifi-watchdog
	sed 's|/usr/local/sbin/|/usr/libexec/|' "$SRC"/userspace/wifi/vivobook-wifi-watchdog.service \
		> /usr/lib/systemd/system/vivobook-wifi-watchdog.service
	install -m 0644 "$SRC"/userspace/wifi/vivobook-wifi-watchdog.timer /usr/lib/systemd/system/
	systemctl enable vivobook-wifi-watchdog.timer
fi

# --- 10. Plymouth ---
if [ -f "$LOCAL"/logo/bgrt-fallback.png ]; then
	step "Plymouth theme vivobook-center"
	W=$(mktemp -d)
	cp -a "$SRC"/userspace/plymouth/. "$W"/
	mkdir -p "$W"/logo && cp "$LOCAL"/logo/bgrt-fallback.png "$W"/logo/
	"$W"/install.sh --theme --image
	rm -rf "$W"
else
	step "no image/local/logo/bgrt-fallback.png: default Plymouth theme"
fi

# --- 11. Howdy ---
if [ "$WITH_HOWDY" = yes ]; then
	step "Howdy (IR camera)"
	"$SRC"/userspace/howdy/install-howdy.sh image
fi

# --- 12. initramfs (firmware, theme, modules of the new kernel) ---
step "initramfs for $KVER"
DRACUT_NO_XATTR=1 dracut --no-hostonly --kver "$KVER" --reproducible --zstd --add ostree \
	-f "/usr/lib/modules/$KVER/initramfs.img"
chmod 0600 "/usr/lib/modules/$KVER/initramfs.img"

# --- 13. clean up ---
step "clean up"
rm -f /etc/dnf/libdnf5.conf.d/90-vivobook-build.conf
rm -rf /run/vivobook-bin
# /var/cache/libdnf5 is the cache mount: keep it, it is not part of the image.
find /var/cache -mindepth 1 -maxdepth 1 ! -name libdnf5 -exec rm -rf {} +
# /boot and /var/lib/rpm-state: left behind by the kernel RPM scriptlets
# (ostree ignores /boot in an image; bootc lint warns about both).
rm -rf /var/lib/dnf /var/lib/rpm-state /var/log/* /var/tmp/* /tmp/* /var/backups/x1e /run/dnf
rm -rf /boot/*
echo "done: $KVER, EXPERIMENTAL_EC=$EXPERIMENTAL_EC, HOWDY=$WITH_HOWDY, WIFI=$WITH_WIFI"
