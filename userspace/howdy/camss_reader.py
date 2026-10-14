# SPDX-License-Identifier: MIT
#
# Howdy frame reader for the HM1092 IR camera behind Qualcomm CAMSS
# (ASUS Vivobook S 15).
#
# CAMSS (legacy binding) delivers only Y10P (packed mono RAW10) from the RDI
# outputs, which OpenCV/ffmpeg/pyv4l2 in Howdy cannot read, and the media
# pipeline has to be configured with media-ctl first. This module mimics
# cv2.VideoCapture:
#   - on open it links hm1092 -> msm_csiphy0 -> msm_csid1 -> msm_vfe1_rdi0
#     (the RGB camera path csiphy4/csid0/vfe0_rdi0 is left alone),
#   - runs "v4l2-ctl --stream-mmap --stream-to=-" and reads frames from the pipe,
#   - converts Y10P to 8 bit (upper bits) and returns a BGR image (3 channels,
#     because Howdy calls cvtColor(BGR2GRAY)).
# The stream, and with it the IR LED strobe, runs only from open to release(),
# i.e. only during authentication.
#
# Installed by install-howdy.sh as recorders/camss_reader.py of the howdy
# package; selected in /etc/howdy/config.ini: recording_plugin = camss,
# device_path = /dev/howdy-ir (symlink from the udev rule 70-howdy-ir.rules).
#
# Optional settings in the [video] section of config.ini:
#   camss_csid = msm_csid1        camss_vfe = msm_vfe1_rdi0
#   camss_rotate = 0 | 180        camss_mirror = false | true
#   camss_exposure = (lines, empty = driver default 500)
#   camss_analogue_gain =         camss_digital_gain =
# Howdy's own "exposure" setting (CAP_PROP_EXPOSURE) is passed to the sensor.

import glob
import os
import re
import subprocess
import sys

import numpy
from cv2 import (CAP_PROP_EXPOSURE, CAP_PROP_FRAME_HEIGHT,
                 CAP_PROP_FRAME_WIDTH)

WIDTH, HEIGHT = 560, 360
MBUS = "Y10_1X10/%dx%d" % (WIDTH, HEIGHT)
# PAM (GDM) may run with a reduced PATH
MEDIA_CTL = "/usr/bin/media-ctl"
V4L2_CTL = "/usr/bin/v4l2-ctl"
CSIPHY = "msm_csiphy0"
OTHER_PHYS = ("msm_csiphy1", "msm_csiphy2", "msm_csiphy4")


def _run(args, check=True):
    p = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if check and p.returncode != 0:
        raise RuntimeError("%s: %s" % (" ".join(args), p.stderr.strip()))
    return p.stdout


class camss_reader:
    """Mimics the cv2.VideoCapture methods used by Howdy."""

    def __init__(self, config):
        self.config = config
        self.video = config.get("video", "device_path")
        self.csid = config.get("video", "camss_csid", fallback="msm_csid1")
        self.vfe = config.get("video", "camss_vfe", fallback="msm_vfe1_rdi0")
        # Howdy itself only rotates by 90 degrees; 180 degrees and mirroring are done here
        self.rotate = config.getint("video", "camss_rotate", fallback=0)
        self.mirror = config.getboolean("video", "camss_mirror", fallback=False)
        self.proc = None
        self.media = None
        self.sensor = None
        self.subdev = None
        self.stride = 0
        self.sizeimage = 0
        try:
            self._setup()
            self._start()
        except Exception as e:  # Howdy exits with code 14 on camera errors
            print("camss_reader: %s" % e, file=sys.stderr)
            self.release()
            sys.exit(14)

    # ---- media pipeline setup ----
    def _setup(self):
        for m in sorted(glob.glob("/dev/media*")):
            topo = _run([MEDIA_CTL, "-d", m, "-p"], check=False)
            if re.search(r"driver\s+qcom-camss", topo):
                self.media = m
                break
        if not self.media:
            raise RuntimeError("no /dev/media* from qcom-camss")
        found = re.search(r"entity \d+: (hm1092 \S+)", topo)
        if not found:
            raise RuntimeError("no hm1092 entity (driver not bound?)")
        self.sensor = found.group(1)
        self.subdev = _run([MEDIA_CTL, "-d", self.media, "-e", self.sensor]).strip()

        mc = [MEDIA_CTL, "-d", self.media]
        # free the input of our CSID and RDI from other sources, leave the rest alone
        for phy in OTHER_PHYS:
            _run(mc + ["-l", '"%s":1->"%s":0[0]' % (phy, self.csid)], check=False)
        for i in range(5):
            other = "msm_csid%d" % i
            if other != self.csid:
                _run(mc + ["-l", '"%s":1->"%s":0[0]' % (other, self.vfe)], check=False)
        # drop a CSIPHY0 link to another CSID (e.g. set up by libcamera); camss
        # allows only one link from a CSIPHY output
        for i in range(5):
            other = "msm_csid%d" % i
            if other != self.csid:
                _run(mc + ["-l", '"%s":1->"%s":0[0]' % (CSIPHY, other)], check=False)
        _run(mc + ["-l", '"%s":1->"%s":0[1]' % (CSIPHY, self.csid)])
        _run(mc + ["-l", '"%s":1->"%s":0[1]' % (self.csid, self.vfe)])
        for ent, pad in ((self.sensor, 0), (CSIPHY, 0), (self.csid, 0),
                         (self.csid, 1), (self.vfe, 0)):
            _run(mc + ["-V", '"%s":%d[fmt:%s field:none]' % (ent, pad, MBUS)])

        ctrls = []
        for key, ctrl in (("camss_exposure", "exposure"),
                          ("camss_analogue_gain", "analogue_gain"),
                          ("camss_digital_gain", "digital_gain")):
            val = self.config.get("video", key, fallback="").strip()
            if val:
                ctrls.append("%s=%s" % (ctrl, val))
        if ctrls:
            _run([V4L2_CTL, "-d", self.subdev, "-c", ",".join(ctrls)], check=False)

        _run([V4L2_CTL, "-d", self.video,
              "--set-fmt-video=width=%d,height=%d,pixelformat=Y10P" % (WIDTH, HEIGHT)])
        fmt = _run([V4L2_CTL, "-d", self.video, "--get-fmt-video"])
        m = re.search(r"Bytes per Line\s*:\s*(\d+)", fmt)
        s = re.search(r"Size Image\s*:\s*(\d+)", fmt)
        self.stride = int(m.group(1)) if m else WIDTH * 5 // 4
        self.sizeimage = int(s.group(1)) if s else self.stride * HEIGHT

    def _start(self):
        self.proc = subprocess.Popen(
            [V4L2_CTL, "-d", self.video, "--stream-mmap=4", "--stream-count=0",
             "--stream-to=-"],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, bufsize=0)

    # ---- OpenCV style API ----
    def _read_raw(self):
        buf = bytearray()
        while len(buf) < self.sizeimage:
            chunk = self.proc.stdout.read(self.sizeimage - len(buf))
            if not chunk:
                return None
            buf += chunk
        return bytes(buf)

    def grab(self):
        return self._read_raw() is not None

    def read(self):
        if self.proc is None:
            return False, None
        raw = self._read_raw()
        if raw is None:
            return False, None
        rows = numpy.frombuffer(raw, dtype=numpy.uint8)[: self.stride * HEIGHT]
        rows = rows.reshape(HEIGHT, self.stride)[:, : WIDTH * 5 // 4]
        gray = rows.reshape(HEIGHT, WIDTH // 4, 5)[:, :, :4].reshape(HEIGHT, WIDTH)
        if self.rotate == 180:
            gray = gray[::-1, ::-1]
        if self.mirror:
            gray = gray[:, ::-1]
        return True, numpy.ascontiguousarray(numpy.repeat(gray[:, :, None], 3, axis=2))

    def set(self, prop, value):
        if prop == CAP_PROP_EXPOSURE and self.subdev and float(value) > 0:
            _run([V4L2_CTL, "-d", self.subdev, "-c", "exposure=%d" % int(value)],
                 check=False)
        return True

    def get(self, prop):
        if prop == CAP_PROP_FRAME_WIDTH:
            return WIDTH
        if prop == CAP_PROP_FRAME_HEIGHT:
            return HEIGHT
        return 0

    def release(self):
        if self.proc is not None:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.proc.kill()
            self.proc = None
