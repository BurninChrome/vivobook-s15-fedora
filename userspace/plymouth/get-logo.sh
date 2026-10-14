#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Extract the ASUS boot logo from the official BIOS image, locally, for the
# Plymouth theme. The logo is an ASUS trademark: it is never stored in this
# repository and must not be redistributed.
#
# Source: the ASUS "Qualcomm Board Support Package" (same download as
# tools/fetch-firmware.sh), file BIOS/Cabfile/S5507QAD.367. The POST logo is the
# FFS file 2f868a91-2a1d-4d08-9d54-d66b0a68e92a (RAW, BMP 654x204, 24 bpp),
# used by OemBadgingSupportDxe.
#
# Usage: get-logo.sh [--exe PATH] [--out DIR]   (default out: ./logo)
# No root needed. Requires 7z, python3-pillow, sha256sum (curl to download).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
BSP_URL="https://dlcdnets.asus.com/pub/ASUS/nb/Image/Driver/DriverPackage/44984/SOCPackage_forWebSite_Qualcomm_Z_V1.367.7800.0_44984.exe"
BSP_SHA256="90bb38a0e60085ce5cd43ab8583d84843c36cc7763d457241f022c8b032867bc"
BIOS_SHA256="4f6c8f09e631e84afcb8c447fa0ee75bcb1cd85027cba4375040333818cc2bfb"
BMP_SHA256="10ad8f1a7eb1c86ee39f7f4b7683b5fe48a963278158714ee0248e10ce91cad2"
EXE=""
OUT=./logo
while [ $# -gt 0 ]; do
	case $1 in
		--exe) EXE=$2; shift 2 ;;
		--out) OUT=$2; shift 2 ;;
		*) echo "unknown option: $1" >&2; exit 2 ;;
	esac
done

if [ -z "$EXE" ]; then
	EXE="./$(basename "$BSP_URL")"
	[ -f "$EXE" ] || { curl -fL --retry 3 -o "$EXE.part" "$BSP_URL" && mv "$EXE.part" "$EXE"; }
fi
echo "$BSP_SHA256  $EXE" | sha256sum -c -

W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
7z x -t7z -y -o"$W" "$EXE" BIOS/Cabfile/S5507QAD.367 >/dev/null
echo "$BIOS_SHA256  $W/BIOS/Cabfile/S5507QAD.367" | sha256sum -c -
python3 "$HERE/fvextract.py" "$W/BIOS/Cabfile/S5507QAD.367" "$W/fv" >/dev/null
BMP=$(ls "$W"/fv/*_2f868a91-2a1d-4d08-9d54-d66b0a68e92a_RAW.bin | head -1)
echo "$BMP_SHA256  $BMP" | sha256sum -c -

mkdir -p "$OUT"
python3 - "$BMP" "$OUT" <<'PY'
import sys
from PIL import Image
src = Image.open(sys.argv[1]).convert('RGB')
assert src.size == (654, 204), src.size
# At Plymouth scale 2 a 1x image is drawn twice as large; half size gives
# exactly 654x204 physical pixels on screen, as during POST.
src.resize((327, 102), Image.BOX).save(sys.argv[2] + '/bgrt-fallback.png', optimize=True)
PY
echo "logo written to $OUT/bgrt-fallback.png (ASUS trademark, do not redistribute)"
