Name:           vivobook-s15-support
Version:        0.1.0
Release:        1%{?dist}
Summary:        Device tree overlay, kernel-install hook and UCM for the ASUS Vivobook S 15 (X1E80100)
License:        MIT AND BSD-3-Clause AND GPL-2.0-only AND (GPL-2.0-only OR BSD-2-Clause) AND (GPL-2.0-only OR MIT)
URL:            https://github.com/BurninChrome/vivobook-s15-fedora
Source0:        %{url}/archive/v%{version}/vivobook-s15-fedora-%{version}.tar.gz
ExclusiveArch:  aarch64
BuildArch:      noarch

BuildRequires:  cpp
BuildRequires:  dtc
BuildRequires:  make
BuildRequires:  python3
BuildRequires:  systemd-rpm-macros
Requires:       dtc
Requires:       python3
Requires:       systemd-udev
Requires:       alsa-ucm
Recommends:     qcom-firmware
Recommends:     libcamera-tools
Recommends:     kernel-uki-dtbloader

%description
Support files for running Fedora on the ASUS Vivobook S 15 S5507QA/S5507QAD
(Snapdragon X Elite): a device tree overlay that adds audio and both cameras
(and, opt-in, the embedded controller), a kernel-install hook that merges it
into the DTB inside the unified kernel image, an ALSA UCM profile, a udev
workaround for LPASS on 7.3 kernels and a WirePlumber camera rule.
Vendor firmware is not included; see firmware.md in the documentation.

%prep
%autosetup -n vivobook-s15-fedora-%{version}

%build
%make_build

%install
%make_install PREFIX=%{_prefix} LIBEXECDIR=%{_libexecdir} DATADIR=%{_datadir} \
    DOCDIR=%{_pkgdocdir} SYSCONFDIR=%{_sysconfdir} \
    KERNELINSTALLDIR=%{_prefix}/lib/kernel/install.d UNITDIR=%{_unitdir} \
    UDEVRULESDIR=%{_udevrulesdir} WPCONFDIR=%{_datadir}/wireplumber/wireplumber.conf.d
install -m 0644 README.md CHANGELOG.md %{buildroot}%{_pkgdocdir}/

%post
%systemd_post vivobook-s15-ucm.path
%udev_rules_update
# Only on the real machine: apply the overlay to all installed kernels and
# restore the UCM profile.
if grep -qs 'Vivobook S 15' /sys/firmware/devicetree/base/model; then
    for k in /usr/lib/modules/*/; do
        %{_libexecdir}/vivobook-s15/apply-dtb "$(basename "$k")" || :
    done
    %{_libexecdir}/vivobook-s15/apply-ucm || :
fi

%preun
%systemd_preun vivobook-s15-ucm.path

%postun
%systemd_postun vivobook-s15-ucm.path
%udev_rules_update

%files
%license LICENSE LICENSES/*
%doc %{_pkgdocdir}/
%config(noreplace) %{_sysconfdir}/vivobook-s15.conf
%{_prefix}/lib/kernel/install.d/30-vivobook-s15.install
%{_libexecdir}/vivobook-s15/
%{_datadir}/vivobook-s15/
%{_unitdir}/vivobook-s15-ucm.path
%{_unitdir}/vivobook-s15-ucm.service
%{_udevrulesdir}/90-vivobook-s15-lpass-rpm.rules
%{_datadir}/wireplumber/wireplumber.conf.d/50-qcom-camss-hide-v4l2.conf

%changelog
* Wed Oct 14 2026 Kacper Goc <11682528+BurninChrome@users.noreply.github.com> - 0.1.0-1
- Initial package
