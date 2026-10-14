# Face login with Howdy and the IR camera

Optional. Needs the kernel patches 0200-0202 (HM1092 driver with IR LED
strobe) and the overlay fragments `20-camera-rgb` and `30-camera-ir`.

## Packages

Howdy comes from the COPR **starfish/howdy-beta**, the only repository with
`fedora-45-aarch64` builds (howdy 3.0.0, dlib 20.0, python-keyboard,
python-pyv4l2). The package has no `%post` scripts and does not touch PAM.
Its dlib models are data from davisking/dlib-models, not firmware.
`python3-opencv` and `python3-numpy` come from Fedora.

## Why a custom reader (`camss_reader.py`)

Howdy reads cameras through OpenCV, ffmpeg or pyv4l2. The IR camera behind
Qualcomm CAMSS does not work with any of them:

- the video node only works after the media pipeline (sensor, CSIPHY0, CSID,
  VFE RDI) has been set up with `media-ctl`,
- RDI delivers only `Y10P` (packed mono RAW10), which OpenCV, ffmpeg and
  GStreamer cannot decode,
- Howdy calls `cvtColor(BGR2GRAY)`, so frames need three channels.

`camss_reader` mimics `cv2.VideoCapture`: it links
`hm1092 -> msm_csiphy0 -> msm_csid1 -> msm_vfe1_rdi0` (the RGB path
`csiphy4/csid0/vfe0_rdi0` is not touched), runs `v4l2-ctl --stream-to=-`,
converts Y10P to 8 bit and returns BGR frames. The stream, and therefore the
IR LED strobe, runs only during recognition. Howdy gets five extra lines in
`recorders/video_capture.py` (`video_capture-camss.patch`,
`recording_plugin = camss`).

An update of the howdy package overwrites that change. Howdy then fails with
a camera error and PAM falls back to the password (safe); run
`install-howdy.sh install` again.

Rejected alternatives: v4l2loopback (out-of-tree module that would have to be
built for every kernel, and a permanent stream would keep the IR LED on);
libcamera (its simple pipeline targets Bayer sensors, the mono RAW10 would
still have to reach Howdy through OpenCV).

## Configuration (`/etc/howdy/config.ini`, set by `install-howdy.sh install`)

| Key | Value | Why |
|---|---|---|
| `device_path` | `/dev/howdy-ir` | symlink from `70-howdy-ir.rules` to `msm_vfe1_video0` (the `/dev/videoN` number changes, iris has video nodes too) |
| `recording_plugin` | `camss` | the reader above |
| `max_height` | `360` | native sensor height, no scaling |
| `timeout` | `5` | one second more than default (pipeline setup, sensor start) |
| `dark_threshold` | `60` | default; the 10 Hz strobe gives some dark frames, Howdy skips them |
| `camss_rotate` | `180` | the module is mounted upside down |
| `camss_exposure`, `camss_analogue_gain`, `camss_digital_gain` | empty | sensor tuning if the picture is too dark or bright (driver default: exposure 500 lines, gain 0) |
| `detection_notice`, `abort_if_ssh`, `abort_if_lid_closed` | `true` | |

## PAM

The password always stays as fallback: `pam_howdy.so` is `sufficient` and
comes **before** the password; failure, camera error, missing model or a
missing module (`-auth` entry) all lead to the normal password prompt.

| Target | File | How | Undo |
|---|---|---|---|
| GDM login and lock screen | `/etc/pam.d/gdm-password-auth-substack` | new file overriding `/usr/lib/pam.d/gdm-password-auth-substack` (Howdy line + copy of the vendor file) | delete the file |
| sudo | `/etc/pam.d/sudo` | one marked line after `#%PAM-1.0`, backup in `/var/lib/vivobook-howdy/orig/` | remove the marked line |
| polkit (optional, untested) | `/etc/pam.d/polkit-1` | like GDM | delete the file |

authselect files (`system-auth`, `password-auth`) are not touched, so
`authselect apply-changes` neither breaks nor undoes anything.

Notes:
- After logging in **with your face at boot**, the GNOME keyring stays locked
  (no password was typed) and asks for the password on first use. Unlocking
  the screen has no such problem.
- SELinux stays enforcing: `howdy_camss.te` lets GDM (`xdm_t`) open and mmap
  `/dev/video*` and `/dev/media*` and allows execmem for dlib/numpy. If GDM
  recognition does not start while sudo works, it is almost certainly an AVC
  denial: `ausearch -m avc -ts recent`.

## Steps

```bash
sudo ./install-howdy.sh install          # packages, reader, udev, config, SELinux; no PAM
sudo ./install-howdy.sh add "$USER"      # look at the camera for about 5 s; repeat with glasses
sudo ./install-howdy.sh test-cam "$USER" # expect exit code 0; 13 = too dark, tune camss_exposure
sudo ./install-howdy.sh pam              # GDM + sudo; or "pam sudo" to start with
# immediately, in a new terminal:
sudo -k; sudo true
```

Then lock the screen (Super+L), unlock with your face, and once with the
password (cover the camera).

Undo: `sudo ./uninstall-howdy.sh` (PAM only) or `--purge` (everything).
Face models are biometric data: they stay on your machine
(`/etc/howdy/models`), never attach them to bug reports.
