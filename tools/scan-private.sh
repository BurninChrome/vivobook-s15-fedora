#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# scan-private.sh: find private data in a project tree before publishing it.
#
# Read only, no root, no network. Changes and deletes nothing.
# Identifiers of this machine (hostname, user, e-mail, machine-id, boot IDs,
# Wi-Fi SSIDs, MAC addresses, DMI serials) are collected at run time and are
# NEVER printed: the report lists only category, file and number of hits.
#
# Usage:
#   scan-private.sh [-a] [-o REPORT] [DIR]
#     DIR       tree to scan (default: current directory)
#     -a        do not skip large trees (kernel sources, build dirs, RPMs, ext/)
#     -o FILE   also write the report to FILE
#
# Exit code: 0 no hits, 1 hits found, 2 usage error.

set -u
LC_ALL=C
export LC_ALL

ALL=0
OUT=""
while getopts "ao:h" opt; do
    case $opt in
        a) ALL=1 ;;
        o) OUT=$OPTARG ;;
        h) sed -n '4,18p' "$0"; exit 0 ;;
        *) exit 2 ;;
    esac
done
shift $((OPTIND - 1))
ROOT=${1:-.}
[ -d "$ROOT" ] || { echo "No such directory: $ROOT" >&2; exit 2; }
ROOT=$(cd "$ROOT" && pwd)

TMP=$(mktemp -d "${TMPDIR:-/tmp}/scan-private.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

# Skipped by default: third-party sources and build output. They are never
# published as a whole and scanning them takes very long.
PRUNE_NAMES=(.git .venv asus-bsp rpmbuild rpmbuild-7.3 ubuntu-kernel build-tmp BUILD BUILD-vivobook1
    BUILD-vivobook2 BUILD-vivobook3 RPMS SRPMS tree ext rpm-rawhide __pycache__
    meson-private venv node_modules target)
FIND_PRUNE=()
if [ $ALL -eq 0 ]; then
    FIND_PRUNE=( \( )
    first=1
    for n in "${PRUNE_NAMES[@]}"; do
        [ $first -eq 1 ] || FIND_PRUNE+=( -o )
        FIND_PRUNE+=( -name "$n" )
        first=0
    done
    FIND_PRUNE+=( \) -prune -o )
fi

# List of all files. This script (and copies of it) contains the patterns,
# so skip it.
find "$ROOT" "${FIND_PRUNE[@]}" -type f -print0 2>/dev/null |
    grep -z -v -E '/scan-private\.sh$' > "$TMP/all.lst"

# ---------------------------------------------------------------------------
# 1. Identifiers of this machine, collected locally (values are never printed).
# ---------------------------------------------------------------------------
# Values that are too generic (default hostname, common words) would only give
# false hits, so they are skipped and the report says so.
STOP=' fedora localhost localhost.localdomain test home root admin user wifi guest '
add_lit() { # category value
    local v=$2
    [ ${#v} -ge 5 ] || { [ -n "$v" ] && echo "$1" >> "$TMP/skipped"; return 0; }
    case "$STOP" in *" ${v,,} "*) echo "$1" >> "$TMP/skipped"; return 0 ;; esac
    printf '%s\n' "$v" >> "$TMP/lit-$1"
}

add_lit hostname "$(hostname 2>/dev/null)"
add_lit hostname "$(cat /etc/hostname 2>/dev/null)"
add_lit user "/home/$(id -un)"
add_lit user "$(getent passwd "$(id -un)" | cut -d: -f5 | cut -d, -f1)"
add_lit email "$(git config --global user.email 2>/dev/null)"
add_lit machine-id "$(cat /etc/machine-id 2>/dev/null)"
# Boot IDs from the journal (without root only readable journals are seen).
journalctl --list-boots --no-pager -q 2>/dev/null | awk '{print $2}' | head -50 |
    while read -r b; do add_lit boot-id "$b"; add_lit boot-id "${b//-/}"; done
# Wi-Fi networks stored in NetworkManager (connection names and SSIDs).
if command -v nmcli >/dev/null; then
    nmcli -t -f NAME,TYPE connection show 2>/dev/null | grep -i wireless | cut -d: -f1 |
        while read -r n; do
            add_lit ssid "$n"
            add_lit ssid "$(nmcli -g 802-11-wireless.ssid connection show "$n" 2>/dev/null)"
        done
fi
# MAC addresses of network and Bluetooth interfaces (including permanent ones).
for a in /sys/class/net/*/address; do
    m=$(cat "$a" 2>/dev/null)
    [ "$m" = "00:00:00:00:00:00" ] && continue
    add_lit mac "$m"; add_lit mac "${m^^}"
done
if command -v ethtool >/dev/null; then
    for i in /sys/class/net/*; do
        m=$(ethtool -P "${i##*/}" 2>/dev/null | awk '{print $NF}')
        [ -n "$m" ] && [ "$m" != "00:00:00:00:00:00" ] && { add_lit mac "$m"; add_lit mac "${m^^}"; }
    done
fi
command -v bluetoothctl >/dev/null &&
    timeout 5 bluetoothctl list 2>/dev/null | awk '{print $2}' |
        while read -r m; do add_lit mac "$m"; add_lit mac "${m,,}"; done
# DMI serial numbers (usually root only; used when readable).
for f in product_serial board_serial chassis_serial product_uuid; do
    v=$(cat /sys/class/dmi/id/$f 2>/dev/null)
    case "$v" in ""|"Default string"|"To be filled by O.E.M.") ;; *) add_lit serial "$v" ;; esac
done

# ---------------------------------------------------------------------------
# 2. Generic patterns (extended regular expressions).
# ---------------------------------------------------------------------------
cat > "$TMP/re-mac" <<'EOF'
([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}
EOF
cat > "$TMP/re-email" <<'EOF'
[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}
EOF
cat > "$TMP/re-privkey" <<'EOF'
-----BEGIN ([A-Z]+ )?PRIVATE KEY-----
-----BEGIN OPENSSH PRIVATE KEY-----
-----BEGIN PGP PRIVATE KEY BLOCK-----
(api[_-]?key|token|passw(or)?d|secret)[[:space:]]*[:=][[:space:]]*[^[:space:]]{6,}
EOF
cat > "$TMP/re-serial" <<'EOF'
(Serial Number|SerialNumber|serial_number|product_serial|board_serial)[^A-Za-z]*[:=][[:space:]]*[A-Za-z0-9]{6,}
iSerial[[:space:]]+[0-9]+[[:space:]]+[A-Za-z0-9]{6,}
EOF
cat > "$TMP/re-wifi" <<'EOF'
(SSID|ssid)[[:space:]]*[:=][[:space:]]*[^[:space:]]
wpa_supplicant.*(CTRL-EVENT-CONNECTED|Trying to associate)
EOF
cat > "$TMP/re-ip" <<'EOF'
\b(192\.168|10\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01]))\.[0-9]{1,3}\.[0-9]{1,3}\b
EOF

# Mailing lists and corporate kernel addresses are expected in patch headers
# (attribution is required), so they are not reported.
EMAIL_IGNORE='(@vger\.kernel\.org|@lists\.|@kernel\.org|@linaro\.org|@oss\.qualcomm\.com|@qualcomm\.com|@quicinc\.com|@redhat\.com|@fedoraproject\.org|@example\.(com|org)|noreply@|@users\.noreply\.github\.com)'

TEXTLIST="$TMP/text.lst"
# Text candidates: grep -I skips binaries; size limit 20 MB.
xargs -0 -r -a "$TMP/all.lst" sh -c 'for f; do
    s=$(stat -c %s "$f" 2>/dev/null || echo 0)
    [ "$s" -le 20971520 ] && printf "%s\0" "$f"; done' sh > "$TEXTLIST"

REPORT="$TMP/report"
: > "$REPORT"

emit() { # category file count note
    printf '%-12s %6s  %s%s\n' "$1" "$3" "${2#"$ROOT"/}" "${4:+  ($4)}" >> "$REPORT"
}

scan_fixed() { # category pattern_file
    local cat=$1 pat=$2
    [ -s "$pat" ] || return 0
    sort -u "$pat" -o "$pat"
    xargs -0 -r -a "$TEXTLIST" grep -I -c -w -F -f "$pat" -- 2>/dev/null |
        awk -F: '$NF>0' | while IFS= read -r line; do
            n=${line##*:}; f=${line%:*}
            emit "$cat" "$f" "$n"
        done
}

scan_re() { # category pattern_file [exclude_regex]
    local cat=$1 pat=$2 excl=${3:-}
    xargs -0 -r -a "$TEXTLIST" grep -I -o -E -H -f "$pat" -- 2>/dev/null |
        { if [ -n "$excl" ]; then grep -v -E -i "$excl"; else cat; fi; } |
        cut -d: -f1 | sort | uniq -c | while read -r n f; do
            emit "$cat" "$f" "$n"
        done
}

for c in hostname user email machine-id boot-id ssid mac serial; do
    [ -f "$TMP/lit-$c" ] && scan_fixed "$c" "$TMP/lit-$c"
done

# Any MAC address: zero and broadcast addresses are excluded.
scan_re mac-any "$TMP/re-mac" ':(00:){4}00$|[Ff][Ff](:[Ff][Ff]){5}'
scan_re email "$TMP/re-email" "$EMAIL_IGNORE"
scan_re secret "$TMP/re-privkey"
scan_re serial-any "$TMP/re-serial"
scan_re wifi "$TMP/re-wifi"
scan_re ip-lan "$TMP/re-ip" '[0-9]\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]'

# ---------------------------------------------------------------------------
# 3. File categories (by name and type).
# ---------------------------------------------------------------------------
while IFS= read -r -d '' f; do
    b=${f##*/}
    case "${b,,}" in
        *.png|*.jpg|*.jpeg|*.webp|*.bmp|*.gif|*.pgm|*.ppm|*.raw|*.y10*|*.yuv|*.nv12|*.mp4|*.mkv|*.webm)
            emit image "$f" 1 "check by hand: faces, rooms, screens" ;;
        *.pem|*.key|*.p12|*.pfx|*.der|*.x509|*.sign|id_rsa*|id_ed25519*|*.gpg|*.asc)
            emit key-file "$f" 1 "key or certificate" ;;
        *.log|*.journal|*console*.txt|dmesg*|journal*.txt)
            emit log "$f" 1 "log dump: review or do not publish" ;;
        *.dat|*.npy|models.json|*.dlib)
            case "$f" in *howdy*|*face*) emit howdy "$f" 1 "possible face model" ;; esac ;;
        *.mbn|*.elf|*.jsn|*.exe|*.cab|*.sys|*.cat|*.inf|*.aml|*.dsl|*.bin|*.efi)
            emit firmware "$f" 1 "ASUS/Qualcomm file: not redistributable" ;;
        *.rpm|*.ko|*.o|*.dtb|*.dtbo|*.tar*|*.zip|*.7z|*.xz|*.gz)
            emit artifact "$f" 1 "build output or archive: ship via releases only" ;;
    esac
done < "$TMP/all.lst"

# ---------------------------------------------------------------------------
# 4. Report.
# ---------------------------------------------------------------------------
{
    echo "# scan-private.sh: $(date -Iseconds)"
    echo "# tree: $ROOT"
    if [ $ALL -eq 0 ]; then
        echo "# skipped directories (use -a to include): ${PRUNE_NAMES[*]}"
        echo "# NOTE: vendor packages (asus-bsp/) and kernel trees must never be published as a whole, whatever this report says"
    fi
    echo "# files: $(tr -cd '\0' < "$TMP/all.lst" | wc -c), text candidates up to 20 MB: $(tr -cd '\0' < "$TEXTLIST" | wc -c)"
    echo "# matched values are never printed; COUNT = hits in the file"
    [ -s "$TMP/skipped" ] && echo "# identifiers skipped as too generic (categories): $(sort -u "$TMP/skipped" | tr '\n' ' ')"
    echo "#"
    echo "# CATEGORY    COUNT  FILE"
    sort -k1,1 -k3 "$REPORT"
    echo "#"
    echo "# summary:"
    awk '{c[$1]++} END {for (k in c) printf "#   %-12s %d files\n", k, c[k]}' "$REPORT" | sort
} > "$TMP/final"

if [ -n "$OUT" ]; then cp "$TMP/final" "$OUT"; fi
cat "$TMP/final"
[ -s "$REPORT" ] && exit 1
exit 0
