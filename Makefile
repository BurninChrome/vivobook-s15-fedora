# SPDX-License-Identifier: MIT
#
# make                 build the overlays (no stock DTB needed)
# make check           syntax checks and a test merge with the running kernel's DTB
# sudo make install    install hooks, overlays, UCM and rules (default PREFIX=/usr/local)
# sudo make apply      apply the overlay to all installed kernels and the UCM profile
# sudo make uninstall  remove what install added (does not restore /boot images)
# sudo make image      build the Silverblue image (image/build.sh, see image/README.md)
#
# Packaging: make install PREFIX=/usr SYSCONFDIR=/etc DESTDIR=... \
#   KERNELINSTALLDIR=/usr/lib/kernel/install.d UNITDIR=/usr/lib/systemd/system \
#   UDEVRULESDIR=/usr/lib/udev/rules.d MODULESLOADDIR=/usr/lib/modules-load.d

PREFIX           ?= /usr/local
LIBEXECDIR       ?= $(PREFIX)/libexec
DATADIR          ?= $(PREFIX)/share
DOCDIR           ?= $(DATADIR)/doc/vivobook-s15-support
SYSCONFDIR       ?= /etc
KERNELINSTALLDIR ?= $(SYSCONFDIR)/kernel/install.d
UNITDIR          ?= $(SYSCONFDIR)/systemd/system
UDEVRULESDIR     ?= $(SYSCONFDIR)/udev/rules.d
WPCONFDIR        ?= $(DATADIR)/wireplumber/wireplumber.conf.d
MODULESLOADDIR   ?= $(SYSCONFDIR)/modules-load.d
DESTDIR          ?=

LIB  := $(DESTDIR)$(LIBEXECDIR)/vivobook-s15
DATA := $(DESTDIR)$(DATADIR)/vivobook-s15
SUBST = sed -e 's|@LIBEXECDIR@|$(LIBEXECDIR)|g' -e 's|@DATADIR@|$(DATADIR)|g' -e 's|@DOCDIR@|$(DOCDIR)|g'

DTBOS := overlay/build/vivobook-s15.dtbo overlay/build/vivobook-s15-experimental.dtbo
SCRIPTS := hooks/apply-dtb hooks/apply-ucm hooks/lpass-rpm-on hooks/30-vivobook-s15.install \
	overlay/build-overlay.sh overlay/update-include.sh tools/*.sh packaging/kernel/*.sh userspace/*/*.sh \
	image/*.sh

all: $(DTBOS)

$(DTBOS): overlay/build-overlay.sh $(wildcard overlay/fragments/*.dtsi overlay/fragments/experimental/*.dtsi)
	overlay/build-overlay.sh --dtbo-only

check:
	for f in $(SCRIPTS); do shell=bash; head -1 $$f | grep -q "bin/sh$$" && shell=sh; $$shell -n $$f || exit 1; done
	python3 -m py_compile hooks/patch-vmlinuz-dtb.py && rm -rf hooks/__pycache__
	overlay/build-overlay.sh

install: all
	install -d $(LIB) $(DATA)/ucm $(DESTDIR)$(KERNELINSTALLDIR) $(DESTDIR)$(UNITDIR) \
		$(DESTDIR)$(UDEVRULESDIR) $(DESTDIR)$(WPCONFDIR) $(DESTDIR)$(SYSCONFDIR) $(DESTDIR)$(DOCDIR) \
		$(DESTDIR)$(MODULESLOADDIR)
	for f in apply-dtb apply-ucm lpass-rpm-on; do $(SUBST) hooks/$$f > $(LIB)/$$f; chmod 0755 $(LIB)/$$f; done
	install -m 0755 hooks/patch-vmlinuz-dtb.py $(LIB)/
	install -m 0644 $(DTBOS) $(DATA)/
	install -m 0644 ucm/Qualcomm/x1e80100/ASUS-Vivobook-S15*.conf $(DATA)/ucm/
	$(SUBST) hooks/30-vivobook-s15.install > $(DESTDIR)$(KERNELINSTALLDIR)/30-vivobook-s15.install
	chmod 0755 $(DESTDIR)$(KERNELINSTALLDIR)/30-vivobook-s15.install
	install -m 0644 hooks/vivobook-s15-ucm.path $(DESTDIR)$(UNITDIR)/
	$(SUBST) hooks/vivobook-s15-ucm.service > $(DESTDIR)$(UNITDIR)/vivobook-s15-ucm.service
	$(SUBST) udev/90-vivobook-s15-lpass-rpm.rules > $(DESTDIR)$(UDEVRULESDIR)/90-vivobook-s15-lpass-rpm.rules
	install -m 0644 userspace/camera/50-qcom-camss-hide-v4l2.conf $(DESTDIR)$(WPCONFDIR)/
	install -m 0644 modules-load/vivobook-s15-cpufreq.conf $(DESTDIR)$(MODULESLOADDIR)/
	[ -e $(DESTDIR)$(SYSCONFDIR)/vivobook-s15.conf ] || \
		$(SUBST) hooks/vivobook-s15.conf > $(DESTDIR)$(SYSCONFDIR)/vivobook-s15.conf
	install -m 0644 docs/firmware.md docs/ec-fan-control.md $(DESTDIR)$(DOCDIR)/

apply:
	systemctl daemon-reload
	udevadm control --reload
	systemctl enable --now vivobook-s15-ucm.path
	$(LIBEXECDIR)/vivobook-s15/apply-ucm
	for k in /usr/lib/modules/*/; do $(LIBEXECDIR)/vivobook-s15/apply-dtb "$$(basename $$k)" || true; done

uninstall:
	-systemctl disable --now vivobook-s15-ucm.path
	rm -rf $(LIB) $(DATA)
	rm -f $(DESTDIR)$(KERNELINSTALLDIR)/30-vivobook-s15.install \
		$(DESTDIR)$(UNITDIR)/vivobook-s15-ucm.path $(DESTDIR)$(UNITDIR)/vivobook-s15-ucm.service \
		$(DESTDIR)$(UDEVRULESDIR)/90-vivobook-s15-lpass-rpm.rules \
		$(DESTDIR)$(WPCONFDIR)/50-qcom-camss-hide-v4l2.conf \
		$(DESTDIR)$(MODULESLOADDIR)/vivobook-s15-cpufreq.conf
	rm -rf $(DESTDIR)$(DOCDIR)
	@echo "kept $(SYSCONFDIR)/vivobook-s15.conf; /boot images keep the merged DTB until the next kernel install"

image:
	image/build.sh

clean:
	rm -rf overlay/build hooks/__pycache__

.PHONY: all check install apply uninstall image clean
