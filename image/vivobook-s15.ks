# SPDX-License-Identifier: MIT
#
# Kickstart for a fresh installation of the vivobook-s15 Silverblue image from
# the official Fedora Silverblue 45 aarch64 installer on a USB stick, with the
# directory "vivobook/" (this file and the OCI archive) added to the stick.
# Only the image source is set here: language, keyboard, time zone, disk
# (LUKS) and user stay interactive in Anaconda. Kernel arguments come from the
# image's /usr/lib/bootc/kargs.d. How to prepare the stick: image/README.md.
#
# The OCI archive is the output of:
#   sudo image/build.sh --oci-archive vivobook-s15-silverblue-45.oci.tar

# The payload path depends on how the installer mounted the stick; %pre finds it.
%include /tmp/vivobook-payload.ks

%pre --interpreter=/bin/bash --log=/tmp/vivobook-pre.log
F=vivobook/vivobook-s15-silverblue-45.oci.tar
P=""
for d in /run/install/repo /run/install/source /run/install/isodir; do
	[ -f "$d/$F" ] && { P="$d/$F"; break; }
done
if [ -z "$P" ]; then
	mkdir -p /run/vivobook-media
	mount -o ro LABEL=Fedora-45-Silverblue-aarch64 /run/vivobook-media &&
		[ -f "/run/vivobook-media/$F" ] && P="/run/vivobook-media/$F"
fi
echo "image: ${P:-NOT FOUND}"
[ -n "$P" ] || exit 1
echo "ostreecontainer --url=$P --transport=oci-archive --no-signature-verification" > /tmp/vivobook-payload.ks
%end

%post --nochroot --interpreter=/bin/bash --log=/mnt/sysroot/root/vivobook-post.log
# Keep the installer's %pre log in /root of the installed system.
cp /tmp/vivobook-pre.log /mnt/sysroot/root/ 2>/dev/null || true
%end
