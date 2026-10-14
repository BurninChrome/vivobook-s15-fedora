# Plymouth boot splash

Two problems on this laptop with Fedora's default themes:

1. **Tiny spinner and password dialog.** The LUKS prompt and the shutdown
   screen are drawn by the `msm` DRM driver. The panel is 344 x 194 mm at
   2880x1620 (212.5 dpi); Plymouth switches to scale 2 only above a threshold
   this panel just misses, so it uses scale 1.
   Fix: kernel parameter `plymouth.force-scale=2`.
2. **Spinner in the lower third.** The `bgrt` and `spinner` themes place the
   spinner at 70% height, under the vendor logo from the ACPI BGRT table.
   When booting from a device tree there is no BGRT and no fallback logo,
   so the spinner floats under an empty space.
   Fix: the `vivobook-center` theme, which shows the ASUS logo exactly as the
   firmware does during POST, with the spinner and the LUKS dialog below it
   and the Fedora logo at the bottom.

The ASUS logo is a trademark and is **not** part of this repository.
`get-logo.sh` extracts it locally from the official ASUS BIOS image (inside
the same ASUS package as the firmware, see `docs/firmware.md`).

```bash
./get-logo.sh                        # no root; or --exe <downloaded ASUS package>
sudo ./install.sh --scale --theme    # --dry-run shows the commands
```

`install.sh --theme` rebuilds the initramfs of the running kernel and
restores the previous image if any firmware file or module would go missing.
Kernels installed later pick up the theme automatically.

Undo: `sudo ./uninstall.sh`.
