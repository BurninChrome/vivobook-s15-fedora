#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Build the Vivobook S 15 device tree overlays from fragments/NN-*.dtsi
# (in name order) and check that the merged DTB still fits into the
# .dtbauto section of the Fedora UKI.
#
#   vivobook-s15.dtbo               fragments/NN-*.dtsi
#   vivobook-s15-experimental.dtbo  the same plus fragments/experimental/NN-*.dtsi
#
# Usage: overlay/build-overlay.sh [--dtbo-only] [--out DIR]
#   --dtbo-only  only compile, skip the test merge (no stock DTB needed)
#   --out DIR    output directory (default: overlay/build)
# Environment:
#   STOCK_DTB    stock x1e80100-asus-vivobook-s15.dtb to test against
#                (default: the one of the running kernel)
#   LIMIT        size of the .dtbauto section in bytes (default 206336)
#
# No root needed. Requires cpp, dtc, fdtoverlay, fdtput.
set -euo pipefail

O="$(cd "$(dirname "$0")" && pwd)"
OUT="$O/build"
DTBO_ONLY=0
while [ $# -gt 0 ]; do
	case $1 in
		--dtbo-only) DTBO_ONLY=1; shift ;;
		--out) OUT=$2; shift 2 ;;
		*) echo "unknown option: $1" >&2; exit 2 ;;
	esac
done
LIMIT=${LIMIT:-206336}
KVER=$(uname -r)
if [ -z "${STOCK_DTB:-}" ]; then
	STOCK_DTB=/boot/dtb-$KVER/qcom/x1e80100-asus-vivobook-s15.dtb
	[ -f "$STOCK_DTB" ] || STOCK_DTB=/usr/lib/modules/$KVER/dtb/qcom/x1e80100-asus-vivobook-s15.dtb
fi

mkdir -p "$OUT"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

# build NAME FRAGMENT...
build() {
	local name=$1; shift
	{
		echo '/dts-v1/;'
		echo '/plugin/;'
		echo '#include <dt-bindings/sound/qcom,q6dsp-lpass-ports.h>'
		echo '#include <dt-bindings/sound/qcom,q6afe.h>'
		for f in "$@"; do
			echo "/* ===== ${f#"$O"/} ===== */"
			cat "$f"
		done
	} > "$OUT/$name.dts"

	cpp -nostdinc -I "$O/include" -undef -D__DTS__ -x assembler-with-cpp \
		-P -o "$T/$name.pp.dts" "$OUT/$name.dts"
	dtc -q -@ -I dts -O dtb -o "$OUT/$name.dtbo" "$T/$name.pp.dts"
	printf '%-28s %6d bytes  (%s)\n' "$name.dtbo" "$(stat -c %s "$OUT/$name.dtbo")" \
		"$(for f in "$@"; do basename "$f"; done | tr '\n' ' ')"

	[ $DTBO_ONLY -eq 1 ] && return 0

	fdtoverlay -i "$STOCK_DTB" -o "$T/$name.merged.dtb" "$OUT/$name.dtbo"
	# Symbols are only needed to apply the overlay; without them the DTB fits.
	for n in /__symbols__ /__fixups__ /__local_fixups__; do
		fdtput -r "$T/$name.merged.dtb" "$n" 2>/dev/null || true
	done
	dtc -q -I dtb -O dtb -o "$OUT/$name.merged.dtb" "$T/$name.merged.dtb"
	local sz
	sz=$(stat -c %s "$OUT/$name.merged.dtb")
	printf '%-28s %6d bytes  (limit %d, margin %d)\n' "  merged DTB" "$sz" "$LIMIT" $((LIMIT - sz))
	[ "$sz" -le "$LIMIT" ] || { echo "ERROR: merged DTB does not fit into .dtbauto" >&2; return 1; }
}

if [ $DTBO_ONLY -eq 0 ] && [ ! -f "$STOCK_DTB" ]; then
	echo "stock DTB not found: $STOCK_DTB (set STOCK_DTB or use --dtbo-only)" >&2
	exit 1
fi
[ $DTBO_ONLY -eq 1 ] || echo "stock DTB: $STOCK_DTB"

shopt -s nullglob
stable=("$O"/fragments/[0-9][0-9]-*.dtsi)
experimental=("$O"/fragments/experimental/[0-9][0-9]-*.dtsi)

build vivobook-s15 "${stable[@]}"
build vivobook-s15-experimental "${stable[@]}" "${experimental[@]}"
