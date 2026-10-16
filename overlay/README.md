# Device tree overlay

`build-overlay.sh` concatenates the fragments in name order, compiles them and
test-applies the result to the stock DTB, printing the size and the margin
left in the `.dtbauto` section (206336 bytes on Fedora 45).

| Output | Fragments | Used when |
|---|---|---|
| `build/vivobook-s15.dtbo` | `fragments/NN-*.dtsi` | default |
| `build/vivobook-s15-experimental.dtbo` | the same plus `fragments/experimental/NN-*.dtsi` | `EXPERIMENTAL_EC=yes` (`image/build.sh --ec yes`, or `/etc/vivobook-s15.conf` on Workstation) |

| Fragment | Content | Requires |
|---|---|---|
| `10-audio.dtsi` | `sound` node, 2 x WSA8845 speakers, WCD9385 headset codec, DMIC pair | firmware |
| `20-camera-rgb.dtsi` | CAMCC, CCI0/CCI1, CAMSS, OV02C10 at 0x36 on CSIPHY4, `rotation = <180>` | kernel with the CCI fix (0010) |
| `30-camera-ir.dtsi` | HM1092 at 0x24 on CCI0/CSIPHY0, IR LED on the PM8550 flash | patches 0200-0202, fragment 20 |
| `experimental/40-ec.dtsi` | `asus,vivobook-s15-ec` node with the `tsens` zones for Tj | patches 0401-0410; read docs/ec-fan-control.md |

Fragments are written as overlay fragments (`&{/} { ... };` and label
references), so the same text can later become a mainline DTS patch.

`include/` holds the `dt-bindings` headers the fragments need, copied
unmodified from the kernel tree (`include/VERSION`), so no kernel source is
needed to build. Refresh them with `update-include.sh <kernel tree>`.

```bash
overlay/build-overlay.sh               # test against the running kernel's stock DTB
STOCK_DTB=/path/x1e80100-asus-vivobook-s15.dtb overlay/build-overlay.sh
overlay/build-overlay.sh --dtbo-only   # compile only (packaging)
```
