# Front camera (OV02C10)

The camera works through libcamera's "simple" pipeline with the software ISP
(libcamera 0.7.2 in Fedora 45), PipeWire and the camera portal: GNOME Camera
(Snapshot), Firefox and Chromium (enable `chrome://flags/#enable-webrtc-pipewire-camera`).

Needed: overlay fragment `20-camera-rgb.dtsi` and a kernel with the CCI fix
(patch 0010). The sensor is mounted upside down; `rotation = <180>` in the DT
lets libcamera correct it.

| File | Installed by | Purpose |
|---|---|---|
| `50-qcom-camss-hide-v4l2.conf` | support package | hides the raw CAMSS nodes so apps list only the real camera |
| `set-digital-gain.sh`, `ov02c10-digital-gain.service` | you, optional | brighter picture in low light |

## Checks

```bash
sudo dnf install libcamera-tools
cam -l                      # 1: Internal front camera (/base/soc@0/cci@ac16000/i2c-bus@1/camera@36)
cam -c1 --capture=5 --file=/tmp/cam-#.ppm -s pixelformat=RGB888
wpctl status | sed -n '/Video/,/Settings/p'
```

If the GPU path of the software ISP fails, try `LIBCAMERA_SOFTISP_MODE=cpu`.

## Known limitations

- libcamera 0.7.2 has no sensor helper for the OV02C10: warnings in the log
  and a generic gain model, so exposure is not optimal.
- No tuning file (`uncalibrated.yaml`): colours and white balance are
  approximate. A tuning file would be a good upstream contribution.
- The software ISP costs CPU/GPU time (1928x1092, up to 30 fps).
