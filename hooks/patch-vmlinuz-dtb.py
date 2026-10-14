#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 The x1e-vivobook-s15-linux-audio contributors
# From https://github.com/bingo1991/qcom-x1e-vivobook-s15 (scripts/), unmodified
# apart from this header. See LICENSES/MIT.txt.
"""
Replace the .dtbauto section for this machine inside a stubble-built vmlinuz.

Ubuntu's linux-*-qcom-x1e kernel images are built with "stubble": the kernel
payload lives in the .linux PE section and every candidate device tree is a
.dtbauto section.  At boot the EFI stub picks one by matching the machine
against the .hwids table.  GRUB's "devicetree" command plays no part in this,
which is why replacing /usr/lib/firmware/<kver>/device-tree/... or adding a
grub entry has no effect.

So, to change the device tree, the .dtbauto section itself has to be replaced.
The section size is fixed, therefore the replacement DTB must fit into it
(build it without =__symbols__ = .../, i.e. without dtc -@ ; that shrinks it
from ~225 kB to ~172 kB).

Usage:
  ./patch-vmlinuz-dtb.py --check
  ./patch-vmlinuz-dtb.py --verify          # exit 0 if already patched
  ./patch-vmlinuz-dtb.py --dtb out/x1e80100-asus-vivobook-s15-wsa-only.dtb [--yes]
  ./patch-vmlinuz-dtb.py --restore
"""

import argparse
import datetime
import os
import shutil
import struct
import subprocess
import sys

PE_SIG = b"PE\0\0"
FDT_MAGIC = 0xD00DFEED


def die(msg):
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(1)


def pe_sections(data):
    if data[:2] != b"MZ":
        die("not a PE image (missing MZ)")
    e_lfanew = struct.unpack_from("<I", data, 0x3C)[0]
    if data[e_lfanew:e_lfanew + 4] != PE_SIG:
        die("not a PE image (missing PE signature)")
    coff = e_lfanew + 4
    nsec, = struct.unpack_from("<H", data, coff + 2)
    opt_size, = struct.unpack_from("<H", data, coff + 16)
    sec = coff + 20 + opt_size
    out = []
    for i in range(nsec):
        o = sec + i * 40
        name = data[o:o + 8].rstrip(b"\0").decode("latin1")
        vsize, vaddr, rawsize, rawptr = struct.unpack_from("<IIII", data, o + 8)
        if rawsize:
            out.append(dict(idx=i, name=name, rawptr=rawptr, rawsize=rawsize))
    return out


def fdt_root_props(blob):
    """Return {prop_name: bytes} for the root node of a flattened DT."""
    if len(blob) < 40:
        return None
    magic, totalsize = struct.unpack_from(">II", blob, 0)
    if magic != FDT_MAGIC or totalsize > len(blob):
        return None
    off_struct, off_strings, off_rsvmap = struct.unpack_from(">III", blob, 8)
    size_strings, size_struct = struct.unpack_from(">II", blob, 32)
    p = off_struct
    end = min(len(blob), off_struct + size_struct, off_struct + totalsize)

    def u32(x):
        return struct.unpack_from(">I", blob, x)[0]

    def align4(x):
        return (x + 3) & ~3

    if u32(p) != 1:  # FDT_BEGIN_NODE
        return None
    p += 4
    nul = blob.find(b"\0", p, end)          # root node name (usually "")
    if nul < 0:
        return None
    p = align4(nul + 1)
    props = {}
    while p + 4 <= end:
        tok = u32(p)
        p += 4
        if tok == 3:  # FDT_PROP
            plen, noff = u32(p), u32(p + 4)
            p += 8
            name = blob[off_strings + noff:off_strings + size_strings].split(b"\0")[0]
            props[name] = blob[p:p + plen]
            p = align4(p + plen)
        elif tok in (2, 9):  # FDT_END_NODE / FDT_END
            break
        elif tok == 4:
            continue
        else:
            break
    return props


def find_targets(data, compat="asus,vivobook-s15"):
    want = compat.encode()
    hits = []
    for s in pe_sections(data):
        if s["name"] != ".dtbauto":
            continue
        blob = data[s["rawptr"]:s["rawptr"] + s["rawsize"]]
        props = fdt_root_props(blob)
        if not props:
            continue
        comp = props.get(b"compatible", b"")
        if want in comp.split(b"\0"):
            hits.append((s, props, struct.unpack_from(">I", blob, 4)[0]))
    return hits


def cmd_check(args):
    data = open(args.vmlinuz, "rb").read()
    print(f"image      : {args.vmlinuz} ({len(data)} bytes)")
    all_sections = pe_sections(data)
    dtbs = [s for s in all_sections if s["name"] == ".dtbauto"]
    print(f"PE sections: {len(all_sections)} total, {len(dtbs)} .dtbauto")
    print(f"\n.dtbauto sections matching {args.compat!r}:")
    for s, props, total in find_targets(data, args.compat):
        print(f"  idx={s['idx']:3d} off=0x{s['rawptr']:08x} rawsize={s['rawsize']:7d} "
              f"dtb totalsize={total:7d}")
        print(f"      compatible={props.get(b'compatible', b'').replace(b'\0', b', ')}")
        print(f"      model={props.get(b'model', b'')}")
    return 0


def cmd_restore(args):
    if not args.yes:
        die("refusing to overwrite without --yes")
    backups = list_backups(args.vmlinuz)
    if not backups:
        die(f"no backup found for {args.vmlinuz} (looked in /var/backups/x1e and "
            f"{os.path.dirname(args.vmlinuz)})")
    print("available backups (oldest first):")
    for b in backups:
        state = has_custom_dtb(b)
        mark = {True: "patched", False: "pristine", None: "unreadable"}[state]
        print(f"  [{mark:10s}] {b}")
    # prefer the pristine original so --restore is a full rollback
    pristine = [b for b in backups if has_custom_dtb(b) is False]
    src = pristine[0] if pristine else backups[0]
    print(f"restoring {src} -> {args.vmlinuz}")
    shutil.copy2(src, args.vmlinuz)
    return 0


def list_backups(vmlinuz):
    base = os.path.basename(vmlinuz) + ".orig-"
    found = []
    for d in (os.path.dirname(vmlinuz) or ".", "/var/backups/x1e"):
        try:
            found += [os.path.join(d, f) for f in os.listdir(d) if f.startswith(base)]
        except OSError:
            pass
    return sorted(found)


def has_custom_dtb(path):
    """True/False: does this image already carry our DTB?  None: unreadable."""
    try:
        data = open(path, "rb").read()
    except OSError:
        return None
    targets = find_targets(data)
    if not targets:
        return False
    s, _, _ = targets[0]
    blob = data[s["rawptr"]:s["rawptr"] + s["rawsize"]]
    return b"qcom,x1e80100-sndcard" in blob


def cmd_verify(args):
    """Exit 0 when every matching .dtbauto section already carries our DTB."""
    data = open(args.vmlinuz, "rb").read()
    targets = find_targets(data, args.compat)
    if not targets:
        print(f"no .dtbauto section with compatible {args.compat!r} in {args.vmlinuz}")
        return 2
    ok = 0
    for s, _, _ in targets:
        blob = data[s["rawptr"]:s["rawptr"] + s["rawsize"]]
        if b"qcom,x1e80100-sndcard" in blob and b"sdw20217020400" in blob:
            ok += 1
    print(f"{ok}/{len(targets)} matching .dtbauto section(s) carry the custom DTB")
    return 0 if ok == len(targets) else 1


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--vmlinuz", default=f"/boot/vmlinuz-{os.uname().release}")
    p.add_argument("--dtb")
    p.add_argument("--compat", default="asus,vivobook-s15")
    p.add_argument("--check", action="store_true")
    p.add_argument("--verify", action="store_true")
    p.add_argument("--restore", action="store_true")
    p.add_argument("--yes", action="store_true")
    args = p.parse_args()

    if args.check:
        return cmd_check(args)
    if args.verify:
        return cmd_verify(args)
    if args.restore:
        return cmd_restore(args)
    if not args.dtb:
        die("either --check, --restore or --dtb is required")

    img = open(args.vmlinuz, "rb").read()
    dtb = open(args.dtb, "rb").read()

    props = fdt_root_props(dtb)
    if not props:
        die(f"{args.dtb} is not a valid flattened device tree")
    if args.compat.encode() not in props.get(b"compatible", b"").split(b"\0"):
        die(f"{args.dtb} does not declare compatible {args.compat!r}")
    dtb_size = struct.unpack_from(">I", dtb, 4)[0]
    print(f"new dtb    : {args.dtb} ({len(dtb)} bytes, totalsize {dtb_size})")
    print(f"             model={props.get(b'model', b'').decode(errors='replace')}")

    targets = find_targets(img, args.compat)
    if not targets:
        die(f"no .dtbauto section with compatible {args.compat!r} in {args.vmlinuz}")
    if len(targets) > 1:
        print(f"note: {len(targets)} matching sections will all be replaced")

    for s, _, _ in targets:
        if len(dtb) > s["rawsize"]:
            die(f"new dtb ({len(dtb)} B) does not fit into the section "
                f"(idx {s['idx']}, {s['rawsize']} B); rebuild it without dtc -@")

    if not args.yes:
        print("\nThis will modify the kernel image.  Continue? [y/N] ", end="", flush=True)
        if input().strip().lower() not in ("y", "yes"):
            print("aborted")
            return 1

    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    # Keep backups OUT of /boot: GRUB's 10_linux enumerates kernels with
    # /boot/vmlinuz-*, so a file named vmlinuz-<kver>.orig-<stamp> looks like
    # another kernel to it.  It then generates a menu entry for it whose
    # matching initrd.img-<kver>.orig-<stamp> does not exist - booting that
    # entry panics with "VFS: Unable to mount root fs on unknown-block(0,0)".
    store = "/var/backups/x1e"
    if os.path.isdir(os.path.dirname(store)) and os.access(os.path.dirname(store), os.W_OK):
        os.makedirs(store, exist_ok=True)
        backup = os.path.join(store, os.path.basename(args.vmlinuz) + f".orig-{stamp}")
    else:
        backup = f"{args.vmlinuz}.orig-{stamp}"
    shutil.copy2(args.vmlinuz, backup)
    print(f"backup     : {backup}")

    out = bytearray(img)
    for s, _, _ in targets:
        off, size = s["rawptr"], s["rawsize"]
        out[off:off + size] = dtb + b"\0" * (size - len(dtb))
        print(f"patched    : .dtbauto idx={s['idx']} off=0x{off:x} ({size} B)")

    tmp = f"{args.vmlinuz}.new"
    with open(tmp, "wb") as f:
        f.write(out)
    os.chmod(tmp, os.stat(args.vmlinuz).st_mode & 0o7777)
    shutil.move(tmp, args.vmlinuz)
    print(f"installed  : {args.vmlinuz}")

    # verify
    data = open(args.vmlinuz, "rb").read()
    ok = 0
    for s, _, _ in find_targets(data, args.compat):
        blob = data[s["rawptr"]:s["rawptr"] + s["rawsize"]]
        if b"qcom,x1e80100-sndcard" in blob and b"sdw20217020400" in blob:
            ok += 1
    print(f"verify     : {ok} section(s) now contain the custom DTB "
          f"({'OK' if ok else 'FAILED'})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
