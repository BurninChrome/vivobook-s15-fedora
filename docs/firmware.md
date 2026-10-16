# Firmware

The laptop needs vendor-signed firmware for the audio DSP (ADSP, also battery
and charging), the compute DSP (CDSP), the GPU and the video decoder. Fedora's
`linux-firmware` / `qcom-firmware` packages contain the generic parts and the
audio topology `X1E80100-ASUS-Vivobook-S15-tplg.bin.xz`, but **not** the
ASUS-signed images. Their license does not allow redistribution, so this
repository does not ship them.

| File | Purpose | Path inside the ASUS BSP 1.367 |
|---|---|---|
| `qcadsp8380.mbn` | ADSP firmware (audio, battery, USB-C) | `Driver/QualcommBSP/Subsystem/qcsubsys_ext_adsp8380_QAD_Signed/` |
| `adsp_dtbs.elf` | ADSP device tree | same |
| `qccdsp8380.mbn` | CDSP firmware | `Driver/QualcommBSP/NPU/qcnspmcdm_ext_cdsp8380/` |
| `cdsp_dtbs.elf` | CDSP device tree | same |
| `qcdxkmsuc8380.mbn` | GPU microcode (Adreno X1-85) | `Driver/QualcommBSP/GFX/qcdx8380/` |
| `qcvss8380.mbn` | video decoder (iris) | same |

Install location: `/usr/lib/firmware/updates/qcom/x1e80100/ASUSTeK/vivobook-s15/`
(the `updates/` directory is searched first and is never touched by packages).

## Silverblue

`/usr` is read-only, so the files become part of the locally built image:
`image/fetch-local.sh` runs Option A in a Fedora container and stores the
files in `image/local/firmware/`, from where the image build copies them to
the path above. For Option B, copy the six files there yourself (for example
from a `toolbox` with `qcom-firmware-extract`). The image then contains
vendor firmware: do not push it to a public registry or share the OCI archive.

The commands below are for Fedora Workstation.

## Option A: official ASUS package (no Windows needed)

```bash
tools/fetch-firmware.sh            # downloads about 170 MB from dlcdnets.asus.com
sudo install -D -m 0644 -t /usr/lib/firmware/updates/qcom/x1e80100/ASUSTeK/vivobook-s15/ firmware-out/*
```

The script checks the SHA-256 of the package (BSP V1.367.7800.0, 2025-09-05,
as published on the ASUS support page of the S5507QAD) and extracts only the
six files above with `7z`.

## Option B: from an existing Windows installation

```bash
sudo dnf install qcom-firmware-extract      # Fedora 45: updates-testing
sudo qcom-firmware-extract
```

## S5507QA (non-QAD)

The ADSP image is signed per variant. It is not yet known whether the QAD
image works on the S5507QA. If you own one, please file a hardware report.

## Long term

The right fix is for ASUS (or Qualcomm on its behalf) to submit these files to
`linux-firmware`, as Lenovo did for the ThinkPad T14s Gen 6
(`qcom/x1e80100/LENOVO/21N1/`). Please ask ASUS support for it.
