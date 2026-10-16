# Release and privacy checklist

Run through this list before every push to the public repository and before
every release.

## Privacy

- [ ] `tools/scan-private.sh .` reports nothing (or only reviewed false hits).
- [ ] No absolute paths with a user name (`/home/<name>/...`); scripts use
      paths relative to the repository or `$PREFIX`.
- [ ] No Wi-Fi network names (SSIDs), not even in examples or tests.
- [ ] No MAC addresses (Wi-Fi, Bluetooth), not even in pasted log lines.
- [ ] No serial numbers, product UUIDs, machine ID (`/etc/machine-id`),
      boot IDs, BLS entry file names (they start with the machine ID).
- [ ] No e-mail addresses other than patch authorship lines.
- [ ] No journal or dmesg dumps; quote only the needed lines, redacted.
- [ ] No camera captures (RGB or IR), no screenshots showing personal data.
- [ ] No Howdy face models (`/usr/lib64/security/howdy/models/*.dat`).
- [ ] No keys: kernel module signing keys (`certs/signing_key.pem`), SSH, GPG,
      MOK, API tokens.
- [ ] Git history is clean too, not only the last commit. The first public
      push starts from a fresh history (one import commit); later, private
      data committed by mistake is removed with `git filter-repo`, not with a
      new commit.
- [ ] Git author e-mail is the one you want to be public (or GitHub's
      `ID+user@users.noreply.github.com`).

## Legal

- [ ] No ASUS/Qualcomm firmware (`*.mbn`, `*.elf`, `*.jsn`), BSP installers,
      BIOS images, extracted ACPI tables (`DSDT*.aml`, `.dsl`), Windows
      drivers or AeoB resource files.
- [ ] No ASUS logo or other trademarks as files (the Plymouth theme reads the
      logo from the firmware at install time).
- [ ] Nothing from `image/local/` committed, no `*.oci.tar`, and no
      vivobook-s15 image pushed to any registry (it contains the firmware).
- [ ] Every third-party file keeps its license header and is listed in
      `docs/credits.md`.
- [ ] Every kernel patch has its original `From:`, the full `Signed-off-by:`
      chain and a `Link:` to its posting if there is one.
- [ ] `reuse lint` passes.

## Release

- [ ] `CHANGELOG.md`: move "Unreleased" to the new version.
- [ ] Tag `vYYYY.MM.N` (signed tag if possible), push the tag.
- [ ] COPR builds started by the tag succeeded for `fedora-45-aarch64` (and
      `fedora-rawhide-aarch64`).
- [ ] Image built with `image/build.sh --switch` on the test laptop, booted,
      `tools/selftest.sh` passed; rollback to the previous image works.
- [ ] Installed on a Workstation test system from COPR, `tools/selftest.sh` passed,
      battery, audio, cameras and fans checked after a reboot.
- [ ] GitHub release created with the changelog section (no binaries needed,
      COPR ships the RPMs).
