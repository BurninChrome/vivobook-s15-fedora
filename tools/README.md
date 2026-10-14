# Tools

| Script | Root | Purpose |
|---|---|---|
| `fetch-firmware.sh` | no | download the ASUS BSP, verify it, extract the firmware |
| `selftest.sh` | no | check battery, audio, cameras, EC, overlay and hook after installation |
| `collect-hwinfo.sh` | no | redacted system summary for issue reports |
| `scan-private.sh` | no | find private data in a tree before publishing it (maintainers, contributors) |
| `set-identity.sh` | no | replace the identity tokens (`@` + `OWNER`/`AUTHOR`/`AUTHOR_EMAIL` + `@`) with the values from `identity.conf` (maintainer, once; already done in this repository) |
