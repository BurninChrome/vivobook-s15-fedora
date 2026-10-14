#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Set the digital gain of the OV02C10 sensor (brighter picture in low light,
# at the cost of more noise). libcamera 0.7 (software ISP) does not control
# digital_gain and the driver does not reset it, so the value applies to all
# applications until the module is reloaded or the laptop reboots.
# Usage: set-digital-gain.sh [VALUE]   1024 = 1x (driver default), 2048 = 2x, max 16383
# No root needed (the subdev has a uaccess ACL). Requires v4l-utils.
set -u
VAL=${1:-2048}
for s in /sys/class/video4linux/v4l-subdev*; do
	[ -e "$s/name" ] || continue
	case "$(cat "$s/name")" in
	ov02c10*)
		dev=/dev/$(basename "$s")
		v4l2-ctl -d "$dev" -c digital_gain="$VAL" && v4l2-ctl -d "$dev" -C digital_gain
		exit $?
		;;
	esac
done
echo "set-digital-gain: no ov02c10 subdev found" >&2
exit 1
