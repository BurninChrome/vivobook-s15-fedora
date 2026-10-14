#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# collect-hwinfo.sh: print a redacted hardware and software summary for bug
# and hardware reports. No root needed, read only, no network.
#
# Redacted: serial numbers, UUIDs, MAC addresses, Wi-Fi network names,
# machine ID, boot IDs, host name and user name. Read the output before
# posting it anyway.

set -u
export LC_ALL=C

USER_NAME=$(id -un)
HOST_NAME=$(hostname 2>/dev/null || cat /etc/hostname)
MACHINE_ID=$(cat /etc/machine-id 2>/dev/null)

redact() {
    sed -E \
        -e 's/([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}/<mac>/g' \
        -e 's/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/<uuid>/g' \
        -e "s/${MACHINE_ID:-@@none@@}/<machine-id>/g" \
        -e "s#/home/${USER_NAME}#/home/<user>#g" \
        -e "s/\\b${USER_NAME}\\b/<user>/g" \
        -e "s/\\b${HOST_NAME}\\b/<host>/g" \
        -e 's/(SSID|ssid)([ :=]+)[^ ,]+/\1\2<ssid>/g' \
        -e 's/((S|s)erial( ?(N|n)umber)?|iSerial)([ :=]+)[^ ]+/\1\5<serial>/g'
}

section() { printf '\n### %s\n' "$1"; }

{
    section "Machine"
    for f in sys_vendor product_name product_version bios_version bios_date ec_firmware_release; do
        printf '%-20s %s\n' "$f" "$(cat /sys/class/dmi/id/$f 2>/dev/null)"
    done
    printf '%-20s %s\n' "dt model" "$(tr -d '\0' < /proc/device-tree/model 2>/dev/null)"
    printf '%-20s %s\n' "cpus" "$(nproc)"
    printf '%-20s %s\n' "memory" "$(awk '/MemTotal/ {printf "%.1f GiB", $2/1048576}' /proc/meminfo)"

    section "System"
    grep -E '^(PRETTY_NAME|VERSION_ID)=' /etc/os-release
    printf 'kernel: %s\n' "$(uname -r)"
    printf 'cmdline: %s\n' "$(cat /proc/cmdline)"
    printf 'secure boot: %s\n' "$(mokutil --sb-state 2>/dev/null || echo unknown)"
    rpm -q kernel-vivobook vivobook-s15-support alsa-ucm qcom-firmware linux-firmware 2>/dev/null

    section "Firmware files"
    for d in /usr/lib/firmware/updates/qcom/x1e80100/ASUSTeK/vivobook-s15 /usr/lib/firmware/qcom/x1e80100/ASUSTeK/vivobook-s15; do
        [ -d "$d" ] || continue
        echo "$d:"
        (cd "$d" && sha256sum -- * 2>/dev/null | awk '{printf "  %.16s  %s\n", $1, $2}')
    done
    for r in /sys/class/remoteproc/remoteproc*; do
        [ -e "$r/name" ] && printf '%s %s %s\n' "${r##*/}" "$(cat "$r/name")" "$(cat "$r/state" 2>/dev/null)"
    done

    section "Device tree overlay"
    for n in sound camera@36 camera@24 embedded-controller@76; do
        if find /sys/firmware/devicetree/base -maxdepth 5 -name "$n" 2>/dev/null | grep -q .; then
            echo "node $n: present"
        else
            echo "node $n: absent"
        fi
    done

    section "Modules"
    lsmod | awk 'NR>1 {print $1}' | grep -E '^(qcom_hamoa_ec|hid_asus_ec|hm1092|ov02c10|qcom_camss|snd_soc_x1e80100|ath12k|qcom_battmgr|qcom_q6v5_pas)' | sort

    section "Battery"
    upower -i /org/freedesktop/UPower/devices/battery_qcom_battmgr_bat 2>/dev/null |
        grep -E 'state|percentage|energy-full:|energy-full-design|capacity' || echo "no battery device"

    section "Audio"
    aplay -l 2>/dev/null | grep -E '^card' || echo "no playback devices"
    arecord -l 2>/dev/null | grep -E '^card' || echo "no capture devices"

    section "Cameras"
    cam -l 2>/dev/null | sed -n '1,10p' || echo "libcamera 'cam' not installed"

    section "Thermal and fans"
    for z in /sys/class/thermal/thermal_zone*; do
        t=$(cat "$z/type" 2>/dev/null); v=$(cat "$z/temp" 2>/dev/null)
        case $t in *cpu*|*gpu*|*aoss*|*ec*|*fan*) printf '%-24s %s\n' "$t" "$v" ;; esac
    done | head -20
    for h in /sys/class/hwmon/hwmon*; do
        n=$(cat "$h/name" 2>/dev/null)
        ls "$h"/fan*_input >/dev/null 2>&1 && printf '%s: %s RPM\n' "$n" "$(cat "$h"/fan*_input | tr '\n' ' ')"
    done

    section "Kernel messages (warnings and errors, this boot)"
    journalctl -k -b -p warning --no-pager -q 2>/dev/null | tail -n 60 ||
        dmesg --level=err,warn 2>/dev/null | tail -n 60
} | redact
