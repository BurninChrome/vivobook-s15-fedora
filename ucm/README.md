# ALSA UCM profile

Files under `Qualcomm/x1e80100/` mirror the layout of
[alsa-ucm-conf](https://github.com/alsa-project/alsa-ucm-conf) `ucm2/`, so they
can be submitted upstream unchanged:

- `ASUS-Vivobook-S15.conf`: entry point, selected by DMI
  (`ASUSTeK COMPUTER.*ASUS Vivobook S 15`),
- `ASUS-Vivobook-S15-Speaker.conf`, `ASUS-Vivobook-S15-Headphones.conf`:
  verbs, including the internal and headset microphones.

The DMI branch for `x1e80100.conf` is in `x1e80100.conf.patch` (against
alsa-ucm-conf 1.2.16; it also removes "Vivobook S 15" from the T14s branch).
Until it is upstream, `hooks/apply-ucm` applies the same change on the system.
