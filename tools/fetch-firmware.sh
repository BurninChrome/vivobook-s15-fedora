#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# fetch-firmware.sh: download the official ASUS "Qualcomm Board Support
# Package" for the S5507QAD and extract the DSP/GPU firmware Linux needs,
# locally. This repository does not contain or redistribute these files.
#
# Usage:
#   fetch-firmware.sh [--exe PATH] [--out DIR]
#     --exe   use an already downloaded package instead of downloading it
#     --out   output directory (default: ./firmware-out)
#
# Needs no root and installs nothing. To install (as root):
#   install -D -m 0644 -t /usr/lib/firmware/updates/qcom/x1e80100/ASUSTeK/vivobook-s15/ firmware-out/*
#
# Alternative if Windows is still on the disk: the Fedora package
# qcom-firmware-extract copies the same files from the Windows partition.
#
# Requires: curl, 7z (p7zip-plugins), sha256sum.

set -euo pipefail

# Package V1.367.7800.0 (2025/09/05), as listed by the ASUS support API for S5507QAD.
BSP_URL="https://dlcdnets.asus.com/pub/ASUS/nb/Image/Driver/DriverPackage/44984/SOCPackage_forWebSite_Qualcomm_Z_V1.367.7800.0_44984.exe"
BSP_SHA256="90bb38a0e60085ce5cd43ab8583d84843c36cc7763d457241f022c8b032867bc"

# Paths inside the archive. The ADSP files are signed for the QAD variant.
FILES=(
    "Driver/QualcommBSP/Subsystem/qcsubsys_ext_adsp8380_QAD_Signed/qcadsp8380.mbn"
    "Driver/QualcommBSP/Subsystem/qcsubsys_ext_adsp8380_QAD_Signed/adsp_dtbs.elf"
    "Driver/QualcommBSP/NPU/qcnspmcdm_ext_cdsp8380/qccdsp8380.mbn"
    "Driver/QualcommBSP/NPU/qcnspmcdm_ext_cdsp8380/cdsp_dtbs.elf"
    "Driver/QualcommBSP/GFX/qcdx8380/qcdxkmsuc8380.mbn"
    "Driver/QualcommBSP/GFX/qcdx8380/qcvss8380.mbn"
)

EXE=""
OUT="./firmware-out"
while [ $# -gt 0 ]; do
    case $1 in
        --exe) EXE=$2; shift 2 ;;
        --out) OUT=$2; shift 2 ;;
        -h|--help) sed -n '3,20p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

for t in 7z sha256sum; do
    command -v $t >/dev/null || { echo "Missing tool: $t (dnf install p7zip-plugins coreutils)" >&2; exit 1; }
done

if [ -z "$EXE" ]; then
    command -v curl >/dev/null || { echo "Missing tool: curl" >&2; exit 1; }
    EXE="./$(basename "$BSP_URL")"
    if [ ! -f "$EXE" ]; then
        echo "Downloading the ASUS package (about 170 MB): $BSP_URL"
        curl -fL --retry 3 -o "$EXE.part" "$BSP_URL"
        mv "$EXE.part" "$EXE"
    fi
fi

echo "Verifying SHA-256..."
echo "$BSP_SHA256  $EXE" | sha256sum -c - || {
    echo "Checksum mismatch: different package version or corrupted download." >&2
    exit 1
}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
# The package is a PE installer with an appended 7z archive.
7z x -t7z -y -o"$WORK" "$EXE" "${FILES[@]}" >/dev/null

mkdir -p "$OUT"
for f in "${FILES[@]}"; do
    install -m 0644 "$WORK/$f" "$OUT/"
done

echo "Done. Files in $OUT:"
( cd "$OUT" && sha256sum * )
echo
echo "To install (as root):"
echo "  install -D -m 0644 -t /usr/lib/firmware/updates/qcom/x1e80100/ASUSTeK/vivobook-s15/ $OUT/*"
echo "These files are ASUS/Qualcomm property under their license. Do not redistribute them."
