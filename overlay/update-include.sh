#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Refresh overlay/include/ from a kernel source tree: copies every
# dt-bindings header that the fragments include, plus their own includes.
# Usage: overlay/update-include.sh /path/to/linux
set -euo pipefail

KSRC=${1:?usage: $0 /path/to/linux}
O="$(cd "$(dirname "$0")" && pwd)"
[ -d "$KSRC/include/dt-bindings" ] || { echo "not a kernel tree: $KSRC" >&2; exit 1; }

todo=$(grep -h -o '<dt-bindings/[^>]*>' "$O"/build-overlay.sh "$O"/fragments/*.dtsi "$O"/fragments/experimental/*.dtsi |
	tr -d '<>' | sort -u)
seen=" "
rm -rf "$O/include/dt-bindings"
while [ -n "$todo" ]; do
	next=""
	for h in $todo; do
		case "$seen" in *" $h "*) continue ;; esac
		seen="$seen$h "
		install -D -m 0644 "$KSRC/include/$h" "$O/include/$h"
		next="$next $(sed -n 's/^#include <\(dt-bindings\/[^>]*\)>.*/\1/p' "$KSRC/include/$h")"
	done
	todo=$(printf '%s\n' $next | sort -u)
done
echo "copied: $(find "$O/include/dt-bindings" -type f | wc -l) headers; update include/VERSION by hand"
