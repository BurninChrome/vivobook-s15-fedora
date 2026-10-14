#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Minimal UEFI firmware volume (FV/FFS) extractor for the ASUS S5507QAD BIOS image.

Looks for _FVH headers, walks the FFS files and sections, unpacks
GUID-defined LZMA sections and nested volumes recursively. Writes every raw
section (RAW/PE32/etc.) and everything that looks like an ACPI table (4-letter
signature + length) to the output directory.

Usage: fvextract.py IMAGE OUTPUT_DIR
The input file is only read.
"""
import lzma, os, struct, sys, uuid

LZMA_GUID = uuid.UUID('ee4e5898-3914-4259-9d6e-dc7bd79403cf')
SECT_NAMES = {0x01: 'COMP', 0x02: 'GUID', 0x10: 'PE32', 0x11: 'PIC', 0x12: 'TE',
              0x13: 'DXEDEP', 0x14: 'VER', 0x15: 'UI', 0x17: 'FV', 0x18: 'FREEFORM',
              0x19: 'RAW', 0x1b: 'PEIDEP'}
ACPI_SIGS = {b'DSDT', b'SSDT', b'FACP', b'APIC', b'DBG2', b'GTDT', b'IORT', b'MCFG',
             b'PPTT', b'SPCR', b'CSRT', b'BGRT', b'FPDT', b'TPM2', b'WSMT', b'SDEV'}

out = sys.argv[2]
os.makedirs(out, exist_ok=True)
seen = set()
counter = [0]


def save(name, data):
    counter[0] += 1
    path = os.path.join(out, '%04d_%s' % (counter[0], name))
    with open(path, 'wb') as f:
        f.write(data)
    return path


def lzma_dec(data):
    # LZMA "alone" (EDK2): 5 bytes of properties + 8 bytes of size
    props = data[:5]
    size = struct.unpack('<Q', data[5:13])[0]
    hdr = props + struct.pack('<Q', size)
    return lzma.LZMADecompressor(lzma.FORMAT_ALONE).decompress(hdr + data[13:])


def scan_acpi(data, tag):
    for sig in ACPI_SIGS:
        i = 0
        while True:
            i = data.find(sig, i)
            if i < 0:
                break
            if i + 36 <= len(data):
                ln = struct.unpack('<I', data[i + 4:i + 8])[0]
                if 36 <= ln <= len(data) - i and ln < 4 * 1024 * 1024:
                    blob = data[i:i + ln]
                    if sum(blob) & 0xff == 0 and blob not in seen:
                        seen.add(blob)
                        oem = blob[16:24].decode('latin1').strip('\0 ')
                        p = save('%s_%s_%s.aml' % (sig.decode(), oem, tag), blob)
                        print('ACPI', sig.decode(), oem, ln, '->', p)
            i += 4


def parse_sections(data, tag, depth):
    off = 0
    while off + 4 <= len(data):
        size = int.from_bytes(data[off:off + 3], 'little')
        typ = data[off + 3]
        hdr = 4
        if size == 0xffffff:
            size = struct.unpack('<I', data[off + 4:off + 8])[0]
            hdr = 8
        if size < hdr or off + size > len(data):
            break
        body = data[off + hdr:off + size]
        name = SECT_NAMES.get(typ, 'T%02x' % typ)
        if typ == 0x02:
            g = uuid.UUID(bytes_le=bytes(body[:16]))
            doff, attr = struct.unpack('<HH', body[16:20])
            payload = data[off + doff:off + size]
            if g == LZMA_GUID:
                try:
                    parse_sections(lzma_dec(payload), tag, depth + 1)
                except Exception as e:
                    print('  ' * depth + 'LZMA error', tag, e)
            else:
                parse_sections(payload, tag, depth + 1)
        elif typ == 0x17:
            walk_fv(body, depth + 1)
        elif typ == 0x15:
            pass
        else:
            if typ in (0x19, 0x10, 0x12, 0x18):
                save('%s_%s.bin' % (tag, name), body)
            scan_acpi(body, tag)
        off += size
        off = (off + 3) & ~3


def walk_fv(data, depth=0):
    if data[40:44] != b'_FVH':
        return
    fvlen = struct.unpack('<Q', data[32:40])[0]
    hlen = struct.unpack('<H', data[48:50])[0]
    ext = struct.unpack('<H', data[52:54])[0]
    off = hlen
    if ext:
        extsize = struct.unpack('<I', data[ext + 16:ext + 20])[0]
        off = (ext + extsize + 7) & ~7
    end = min(fvlen, len(data))
    while off + 24 <= end:
        if data[off:off + 24] == b'\xff' * 24:
            break
        fg = uuid.UUID(bytes_le=bytes(data[off:off + 16]))
        ftype = data[off + 18]
        attr = data[off + 19]
        size = int.from_bytes(data[off + 20:off + 23], 'little')
        hdr = 24
        if attr & 0x01:  # FFS_ATTRIB_LARGE_FILE
            size = struct.unpack('<Q', data[off + 24:off + 32])[0]
            hdr = 32
        if size < hdr:
            break
        body = data[off + hdr:off + size]
        tag = str(fg)
        print('  ' * depth + 'FILE %s type=%02x size=%d' % (fg, ftype, size))
        if ftype in (0x01,):  # RAW
            save(tag + '_RAWFILE.bin', body)
            scan_acpi(body, tag)
        elif ftype not in (0xf0,):  # pad
            parse_sections(body, tag, depth + 1)
        off = (off + size + 7) & ~7


img = open(sys.argv[1], 'rb').read()
i = 0
while True:
    i = img.find(b'_FVH', i)
    if i < 0:
        break
    base = i - 40
    print('FV @0x%x' % base)
    walk_fv(img[base:], 0)
    i += 4
scan_acpi(img, 'top')
