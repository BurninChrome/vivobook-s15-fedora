# SPDX-License-Identifier: MIT
#
# Kickstart for a fresh installation of the vivobook-s15 Silverblue image from
# an installer USB stick. Only the image source is set here; language,
# keyboard, disk (LUKS), user and time zone stay interactive in Anaconda.
# How to build the stick: image/README.md, "Fresh installation".
#
# The OCI archive is the output of: sudo image/build.sh --oci-archive vivobook-s15-silverblue-45.oci.tar
# mkksiso --add puts the directory "vivobook" at the root of the ISO, which
# Anaconda mounts as /run/install/repo.
ostreecontainer --url=/run/install/repo/vivobook/vivobook-s15-silverblue-45.oci.tar --transport=oci-archive --no-signature-verification

# The same arguments as image/kargs.d, for the first boot: not every Anaconda
# version applies kargs.d (bootc switch/upgrade do). A duplicate is harmless.
bootloader --append="systemd.tpm2_wait=0 plymouth.force-scale=2"
