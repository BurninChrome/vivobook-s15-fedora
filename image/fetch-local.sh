#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Prepare image/local/ for image/build.sh. No root needed; runs the download
# and extraction tools in a throw-away Fedora container, so nothing has to be
# layered on the Silverblue host.
#
#   fetch-local.sh                firmware (tools/fetch-firmware.sh) and the ASUS
#                                 logo for the Plymouth theme (userspace/plymouth/get-logo.sh)
#   fetch-local.sh --no-logo      firmware only
#   fetch-local.sh --exe FILE     use an already downloaded ASUS package
#   fetch-local.sh --rpms DIR     also copy the kernel-vivobook RPMs from DIR
#                                 (kernel, -core, -modules, -modules-core, -modules-extra,
#                                 -uki-dtbloader)
#
# Result (git-ignored, never commit or redistribute):
#   image/local/firmware/  ASUS/Qualcomm firmware
#   image/local/logo/      bgrt-fallback.png (ASUS trademark)
#   image/local/rpms/      kernel RPMs
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL=$ROOT/image/local
FEDORA=${FEDORA_IMAGE:-registry.fedoraproject.org/fedora:45}
LOGO=1
EXE=""
RPMS=""
while [ $# -gt 0 ]; do
	case $1 in
		--no-logo) LOGO=0; shift ;;
		--exe) EXE=$(readlink -f "$2"); shift 2 ;;
		--rpms) RPMS=$2; shift 2 ;;
		-h|--help) sed -n '3,20p' "$0"; exit 0 ;;
		*) echo "unknown option: $1" >&2; exit 2 ;;
	esac
done
[ "$(id -u)" -ne 0 ] || echo "note: no root needed; files in image/local/ will belong to root" >&2

mkdir -p "$LOCAL"/firmware "$LOCAL"/logo "$LOCAL"/rpms

if [ -n "$RPMS" ]; then
	shopt -s nullglob
	new=()
	for n in kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra kernel-uki-dtbloader; do
		for f in "$RPMS"/"$n"-[0-9]*.vivobook*.aarch64.rpm; do new+=("$f"); done
	done
	shopt -u nullglob
	[ ${#new[@]} -ge 6 ] || { echo "expected 6 kernel RPMs with .vivobookN in $RPMS, found ${#new[@]}" >&2; exit 1; }
	rm -f "$LOCAL"/rpms/*.rpm
	cp -v "${new[@]}" "$LOCAL"/rpms/
fi

mounts=(-v "$ROOT:/src:ro,Z" -v "$LOCAL:/local:Z")
exe_arg=""
if [ -n "$EXE" ]; then
	mounts+=(-v "$EXE:/pkg.exe:ro,Z")
	exe_arg="--exe /pkg.exe"
fi
# The ASUS package is cached in image/local/ for later runs.
podman run --rm "${mounts[@]}" -w /local -e LOGO="$LOGO" -e EXE_ARG="$exe_arg" "$FEDORA" bash -euc '
	dnf -y -q install --setopt=install_weak_deps=False p7zip-plugins curl python3-pillow >/dev/null
	# shellcheck disable=SC2086
	/src/tools/fetch-firmware.sh $EXE_ARG --out /local/firmware
	if [ "$LOGO" = 1 ]; then
		exe=${EXE_ARG#--exe }
		[ -n "$exe" ] || exe=$(ls /local/SOCPackage_*.exe | head -1)
		/src/userspace/plymouth/get-logo.sh --exe "$exe" --out /local/logo
	fi
	chown -R "$(stat -c %u:%g /local)" /local
'
echo
echo "image/local/ is ready:"
ls -l "$LOCAL"/firmware "$LOCAL"/logo "$LOCAL"/rpms
echo "Next: sudo image/build.sh"
