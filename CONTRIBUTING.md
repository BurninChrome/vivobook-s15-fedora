# Contributing

Thank you for helping. Hardware reports from other owners are as valuable as
code.

## Reporting a problem or your hardware

1. Run `tools/collect-hwinfo.sh > hwinfo.txt` and read the file before you
   attach it. The script hides serial numbers, MAC addresses, Wi-Fi network
   names, the machine ID and your user name, but it cannot know everything.
2. Use one of the [issue forms](.github/ISSUE_TEMPLATE/). Always give the model
   (S5507QA or S5507QAD), BIOS version, kernel version and whether the EC
   driver is loaded.
3. Never post photos from the cameras, Howdy face models or full journals.

## Pull requests

- One topic per pull request. Run `tools/scan-private.sh .` and
  `reuse lint` before pushing.
- Every commit needs a `Signed-off-by:` line (`git commit -s`), certifying the
  [Developer Certificate of Origin](https://developercertificate.org/).
- Device tree changes go into `overlay/fragments/NN-topic.dtsi` written as an
  overlay fragment (`&{/} { ... };`). `overlay/build-overlay.sh` must pass and
  print a positive size margin: the merged DTB has to fit into the `.dtbauto`
  section of the UKI (206336 bytes on Fedora 45).
- Kernel patches go into `kernel/patches/` in `git format-patch` format, with
  the original author, `Signed-off-by` chain and a `Link:` to the mailing list
  posting if there is one. Add the patch to `kernel/patches/series` and to the
  table in `kernel/README.md`. The CI checks that the series applies to the
  kernel version in `packaging/kernel/`.
- Work done with AI assistance: follow the kernel rules in
  `Documentation/process/coding-assistants.rst`. An AI tool never adds
  `Signed-off-by`; mark such commits with `Assisted-by: <tool>`. A human
  reviews and signs off every change.

## Sending things upstream

The aim is to upstream everything. Before writing a patch, check
[docs/upstream.md](docs/upstream.md) and lore.kernel.org, so nothing is posted
twice. Patches by other people are sent upstream only by their authors or with
their permission.
