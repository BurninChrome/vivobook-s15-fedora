# Hardware compatibility

Add your machine with the
[hardware report form](../../issues/new?template=hardware-report.yml).
Please run `tools/collect-hwinfo.sh` and paste its output: it hides serial
numbers, MAC addresses, network names and user names.

| Model | SoC | BIOS | RAM | Fedora | Kernel | Battery | Audio | Mics | Camera | IR + Howdy | Fans (EC) | Suspend | Reporter |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| S5507QAD | X1E-78-100 | 367 | 32 GB | 45 | 7.3.0 vivobook5 | yes | yes | yes | yes | yes | experimental | yes (s2idle) | maintainer |

## Known differences between variants

| Item | S5507QAD | S5507QA | Notes |
|---|---|---|---|
| ADSP firmware | `qcsubsys_ext_adsp8380_QAD_Signed` in BSP 1.367 | unknown | signed per variant; a wrong ADSP image breaks battery reporting and audio |
| BIOS line | `S5507QAD.3xx` | `S5507QA.3xx` | |
| Device tree | `x1e80100-asus-vivobook-s15.dts` | same | |
