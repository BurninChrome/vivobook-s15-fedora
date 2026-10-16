#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Build the Vivobook S 15 Silverblue image from image/Containerfile and,
# optionally, switch the running system to it. Run as root (sudo): bootc and
# rpm-ostree read images from root's container storage.
#
#   build.sh                     build localhost/vivobook-s15-silverblue:45
#   build.sh --switch            build, then "bootc switch" to it (first time) or
#                                "bootc upgrade" (later builds); reboot afterwards
#   build.sh --oci-archive FILE  also write the image as an OCI archive (installer USB)
#
# Options (defaults in brackets):
#   --tag REF          image reference [localhost/vivobook-s15-silverblue:45]
#   --base IMAGE       base image [quay.io/fedora/fedora-silverblue:45]
#   --ec yes|no        experimental EC fan control [value in /etc/vivobook-s15.conf, else no]
#   --howdy yes|no     Howdy face login [yes]
#   --wifi yes|no      Wi-Fi power save off + watchdog [yes]
#   --packages "A B"   additional packages [image/local/packages, if present:
#                      one or more per line, # comments; kept across rebuilds]
#   --no-firmware      build without image/local/firmware (CI only)
#   --no-pull          do not check for a newer base image
#
# Inputs in image/local/ (image/fetch-local.sh, image/build-kernel.sh):
# firmware/ (required), logo/ (optional), rpms/ (optional, else stock kernel).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG=localhost/vivobook-s15-silverblue:45
BASE=quay.io/fedora/fedora-silverblue:45
EC=""
HOWDY=yes
WIFI=yes
PACKAGES=""
[ -f "$ROOT"/image/local/packages ] && PACKAGES=$(sed 's/#.*//' "$ROOT"/image/local/packages | xargs)
NOFW=no
PULL=--pull=newer
SWITCH=0
ARCHIVE=""

while [ $# -gt 0 ]; do
	case $1 in
		--tag) TAG=$2; shift 2 ;;
		--base) BASE=$2; shift 2 ;;
		--ec) EC=$2; shift 2 ;;
		--howdy) HOWDY=$2; shift 2 ;;
		--wifi) WIFI=$2; shift 2 ;;
		--packages) PACKAGES=$2; shift 2 ;;
		--no-firmware) NOFW=yes; shift ;;
		--no-pull) PULL=""; shift ;;
		--switch) SWITCH=1; shift ;;
		--oci-archive) ARCHIVE=$2; shift 2 ;;
		-h|--help) sed -n '3,25p' "$0"; exit 0 ;;
		*) echo "unknown option: $1" >&2; exit 2 ;;
	esac
done
for v in "$HOWDY" "$WIFI" "${EC:-no}"; do
	case $v in yes|no) ;; *) echo "expected yes or no, got: $v" >&2; exit 2 ;; esac
done

# Keep the EC setting of the running system unless --ec is given: the DTB of
# the next image would otherwise silently lose (or gain) the EC node.
if [ -z "$EC" ]; then
	EC=no
	# shellcheck source=/dev/null
	[ -f /etc/vivobook-s15.conf ] && EC=$(. /etc/vivobook-s15.conf; echo "${EXPERIMENTAL_EC:-no}")
fi

if [ "$NOFW" = no ] && ! ls "$ROOT"/image/local/firmware/*.mbn >/dev/null 2>&1; then
	echo "image/local/firmware/ is empty: run image/fetch-local.sh first (as your user)" >&2
	exit 1
fi
[ "$(id -u)" -eq 0 ] || [ "$SWITCH" -eq 0 ] || { echo "--switch needs root: sudo $0 $*" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || echo "note: building as a user; bootc/rpm-ostree only see root's images (sudo)" >&2

if ls "$ROOT"/image/local/rpms/kernel-core-*.rpm >/dev/null 2>&1; then
	echo "kernel: $(basename "$(ls "$ROOT"/image/local/rpms/kernel-core-*.rpm | head -1)")"
else
	echo "kernel: stock Fedora (no image/local/rpms; cameras, Fn keys and EC need kernel-vivobook)"
fi
[ "$EC" = yes ] && echo "EXPERIMENTAL_EC=yes: read docs/ec-fan-control.md"
[ -z "$PACKAGES" ] || echo "extra packages: $PACKAGES"

version=$(date +%Y%m%d.%H%M)-$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo local)
# shellcheck disable=SC2086
podman build $PULL -f "$ROOT"/image/Containerfile -t "$TAG" \
	--build-arg BASE_IMAGE="$BASE" \
	--build-arg EXPERIMENTAL_EC="$EC" \
	--build-arg WITH_HOWDY="$HOWDY" \
	--build-arg WITH_WIFI="$WIFI" \
	--build-arg EXTRA_PACKAGES="$PACKAGES" \
	--build-arg ALLOW_NO_FIRMWARE="$NOFW" \
	--build-arg IMAGE_VERSION="$version" \
	"$ROOT"
echo "built $TAG ($version)"

if [ -n "$ARCHIVE" ]; then
	rm -f "$ARCHIVE"
	podman save --format oci-archive -o "$ARCHIVE" "$TAG"
	echo "OCI archive: $ARCHIVE (contains vendor firmware: do not share it)"
fi

if [ "$SWITCH" -eq 1 ]; then
	# spec.image: the image the system follows (booted or already staged by an
	# earlier switch). Same image -> upgrade, which fetches the new build;
	# "bootc switch" would only say "Image specification is unchanged".
	current=$(bootc status --format json 2>/dev/null |
		python3 -c 'import json,sys; s=json.load(sys.stdin)["spec"]["image"]; print(s["transport"]+":"+s["image"])' 2>/dev/null || true)
	if [ "$current" = "containers-storage:$TAG" ]; then
		bootc upgrade
	else
		bootc switch --transport containers-storage "$TAG"
	fi
	echo "Reboot to start the new image. The previous one stays in the boot menu (rollback: sudo bootc rollback)."
fi
