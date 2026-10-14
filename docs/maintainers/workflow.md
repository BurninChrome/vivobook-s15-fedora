# Maintainer workflow

## Branches and tags

- `main`: always installable. Changes arrive through pull requests, even the
  maintainer's own, so that CI runs.
- Tags `vYYYY.MM.N` mark releases of the support package.
- The kernel package has its own version: `kernel-vivobook-<upstream>-<fedora
  release>.vivobook<N>`, e.g. `7.3.0-0.rc6.55.vivobook3`. `N` grows with every
  change of the patch series or config.

## Kernel updates

1. When Fedora publishes a new kernel (`koji list-builds --package=kernel`),
   update `packaging/kernel/BASE` (Fedora kernel NVR and dist-git commit).
2. `kernel/patches/series` must apply: CI checks it. Drop patches that are now
   upstream and record that in `docs/upstream.md`.
3. Bump `N`, update `CHANGELOG.md`, tag, COPR builds.
4. Test on the laptop before announcing.

## Issues

Labels: `hardware-report`, `bug`, `audio`, `camera`, `ec`, `suspend`,
`wifi`, `packaging`, `upstream`, `help wanted`, `S5507QA`.
Hardware reports are summarised in `HARDWARE.md` and then closed.

## Who builds what

| Artifact | Where | Trigger |
|---|---|---|
| `vivobook-s15-support` (noarch) | Fedora COPR, from this repository (SCM source, `make srpm`) | tag push (webhook) |
| `kernel-vivobook` | Fedora COPR, aarch64 builders, from `packaging/kernel/` | manual `copr-cli build` or tag `kernel-*` |
| CI checks | GitHub Actions (`ubuntu-24.04-arm`) | push, pull request |
