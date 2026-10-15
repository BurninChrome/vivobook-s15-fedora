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
