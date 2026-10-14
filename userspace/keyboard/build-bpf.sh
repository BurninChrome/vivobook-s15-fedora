#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Build the HID-BPF program for the Vivobook S 15 keyboard from Icecream95's
# udev-hid-bpf fork. No root needed. Requires git, clang, llvm, bpftool,
# libbpf-devel, python3 (meson and ninja are installed into a local venv).
# vmlinux.h is generated from the BTF of the running kernel.
# Usage: build-bpf.sh [WORKDIR]   (default: ./build-bpf)
set -euo pipefail

REPO=https://github.com/icecream95/udev-hid-bpf.git
COMMIT=519dadad5420
W=${1:-./build-bpf}
mkdir -p "$W"
cd "$W"
[ -d udev-hid-bpf ] || git clone -q "$REPO" udev-hid-bpf
git -C udev-hid-bpf checkout -q "$COMMIT"
[ -x .venv/bin/meson ] || { python3 -m venv .venv && .venv/bin/pip install -q meson ninja; }
export PATH=$PWD/.venv/bin:$PATH
rm -rf build
meson setup build udev-hid-bpf -Dbpf-filter=Vivobook_S15 -Dvmlinux-h=generated \
	-Dprefix=/usr/local -Dudevdir=/etc/udev -Dtests=disabled >/dev/null
ninja -C build src/bpf/0010-ASUS__Vivobook_S15_S5507_kbd.bpf.o
cp build/src/bpf/0010-ASUS__Vivobook_S15_S5507_kbd.bpf.o .
sha256sum 0010-ASUS__Vivobook_S15_S5507_kbd.bpf.o
