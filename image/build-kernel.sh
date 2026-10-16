#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Build the kernel-vivobook RPMs locally, in a Fedora 45 container, and put
# them into image/local/rpms/. No root needed. Takes several hours on the
# laptop and about 30 GB in image/local/rpmbuild/.
# Not needed once the COPR builds exist (packaging/kernel/README.md).
#
# Usage: image/build-kernel.sh [--jobs N]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL=$ROOT/image/local
FEDORA=${FEDORA_IMAGE:-registry.fedoraproject.org/fedora:45}
JOBS=$(nproc)
[ "${1:-}" = --jobs ] && JOBS=${2:?}

mkdir -p "$LOCAL"/rpmbuild "$LOCAL"/rpms
podman run --rm -v "$ROOT:/src:ro,Z" -v "$LOCAL:/local:Z" -e JOBS="$JOBS" "$FEDORA" bash -euc '
	dnf -y -q install rpm-build curl git-core "dnf5-command(builddep)" >/dev/null
	cd /src
	packaging/kernel/prepare-srpm.sh --out /local/rpmbuild/srpm
	srpm=$(ls -t /local/rpmbuild/srpm/kernel-*.vivobook*.src.rpm | head -1)
	dnf -y -q builddep "$srpm" >/dev/null
	# kernel.spec signs vmlinuz for FIPS with sha512hmac (libkcapi), which needs
	# AF_ALG. Kernels with crypto.af_alg_restrict=1 refuse it, also inside the
	# container. Same result in userspace: HMAC-SHA512 with hmaccalc'"'"'s key,
	# "<hex>  <file>" (checked against the .hmac of a stock Fedora kernel).
	if ! sha512hmac /etc/os-release >/dev/null 2>&1; then
		echo "sha512hmac: AF_ALG not available, using a userspace replacement"
		cat > /usr/bin/sha512hmac <<-"PY"
		#!/usr/bin/python3
		import hashlib, hmac, sys
		for f in sys.argv[1:]:
		    with open(f, "rb") as fh:
		        d = hmac.new(b"FIPS-FTW-RHT2009", fh.read(), hashlib.sha512).hexdigest()
		    print(d + "  " + f)
		PY
		chmod 0755 /usr/bin/sha512hmac
		sha512hmac /etc/os-release
	fi
	rpmbuild --rebuild "$srpm" --define "_topdir /local/rpmbuild" \
		--define "_smp_mflags -j$JOBS" --with baseonly --without debuginfo
	chown -R "$(stat -c %u:%g /local)" /local
'
. "$ROOT"/packaging/kernel/BASE
rm -f "$LOCAL"/rpms/*.rpm
for n in kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra kernel-uki-dtbloader; do
	cp -v "$LOCAL"/rpmbuild/RPMS/aarch64/"$n"-[0-9]*.vivobook"$VIVOBOOK_RELEASE".*.aarch64.rpm "$LOCAL"/rpms/
done
echo "Next: sudo image/build.sh"
