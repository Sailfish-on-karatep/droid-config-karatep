#!/usr/bin/python3
#
# Stage the modem's software carrier configs, with IMS switched on.
#
# Two separate faults are being worked around here.
#
# First, /vendor/bin/init.qcom.sh cannot stage these configs at all on this
# firmware. It copies from modem_pr/mcfg/configs/*, a tree this modem image
# does not have, and then sets ro.vendor.ril.mbn_copy_completed=1 regardless.
# It also rm -rf's the target directory on every boot. So the modem is left
# with no carrier configuration and qcril is told the copy succeeded.
#
# Second, the config the modem selects for any SIM that matches no carrier --
# ROW_Generic_3GPP, which every Indian operator except Jio falls through to --
# ships with ims/IMS_enable = 0 and voice_domain_pref = CsVoiceOnly. IMS is
# switched off in NV, so the modem publishes no IMS QMI services at all and
# VoLTE cannot work at any layer above. Qualcomm turned IMS on in this same
# generic config in later modem branches: an MSM8937 LA.3.1.2 image ships it
# as IMS_enable = 1 / ImsPsVoicePreferred, as does a 2024 SM8250 image. This
# reproduces that change on our LA.2.0 config.
#
# Nothing proprietary is shipped. The configs are read from the device's own
# /vendor/firmware_mnt/image, and row.mbn is patched in place -- two value
# bytes and a version bump -- then re-hashed. These files carry three SHA-256
# hashes and no signature, and this modem checks only the hashes.
#
# See karatep-port docs/rca/volte-registration-change-is-test-mode.md.

import hashlib
import os
import struct
import subprocess
import sys
import time

VENDOR = "/vendor/firmware_mnt/image"
TARGET = "/data/vendor/radio/modem_config/mcfg_sw"
MARKER = "/var/lib/karatep/modem-config-applied"

RADIO_UID = 1001          # Android's "radio" user, which rild runs as
MARKER_VERSION = 1        # bump to force a re-stage after changing this script

# Item files whose value byte we change, and what to change it to.
#     IMS_enable         0 -> 1
#     voice_domain_pref  0 (CsVoiceOnly) -> 3 (ImsPsVoicePreferred)
#
# In the MCFG payload an item is stored as its NUL-terminated path followed by
# four bytes of record framing and then a two-byte value, of which the first
# is a type tag (0x07) and the second the value itself. Matching on the path
# plus that framing makes the edit unambiguous.
PATCHES = (
    (b"/nv/item_files/ims/IMS_enable", 1),
    (b"/nv/item_files/modem/mmode/voice_domain_pref", 3),
)
ITEM_PREFIX = b"\x00\x02\x00\x02\x00\x07"

# voice_domain_pref = 3 prefers IMS but keeps CS as the fallback, so a failure
# to register on IMS costs nothing.


def log(msg):
    print("karatep-modem-config: " + msg, file=sys.stderr, flush=True)


def getprop(name):
    try:
        return subprocess.run(["getprop", name], capture_output=True,
                              text=True, timeout=10).stdout.strip()
    except Exception:
        return ""


def setprop(name, value):
    subprocess.run(["setprop", name, value], timeout=10)


def patch_config(data):
    """Return row.mbn with IMS enabled and the MCFG version bumped."""
    if data[:4] != b"\x7fELF" or data[4] != 1:
        raise ValueError("not a 32-bit ELF")

    e_phoff, = struct.unpack_from("<I", data, 0x1c)
    e_phentsize, e_phnum = struct.unpack_from("<HH", data, 0x2a)
    if e_phnum != 3:
        raise ValueError("expected 3 program headers, got %d" % e_phnum)

    def phdr(i):
        o = e_phoff + i * e_phentsize
        _, p_offset, _, _, p_filesz = struct.unpack_from("<5I", data, o)
        return p_offset, p_filesz

    hdr_len = e_phoff + e_phnum * e_phentsize
    hash_off, hash_len = phdr(1)
    mcfg_off, mcfg_len = phdr(2)
    if hash_len < 40 + 3 * 32:
        raise ValueError("hash segment too small (%d)" % hash_len)

    out = bytearray(data)
    payload = out[mcfg_off:mcfg_off + mcfg_len]

    for path, value in PATCHES:
        needle = path + ITEM_PREFIX
        at = payload.find(needle)
        if at < 0:
            raise ValueError("item not found: %s" % path.decode())
        if payload.find(needle, at + 1) >= 0:
            raise ValueError("item found more than once: %s" % path.decode())
        vpos = at + len(needle)
        log("  %s: %d -> %d" % (path.decode(), payload[vpos], value))
        payload[vpos] = value

    # The MCFG version is four bytes, [minor, carrier, oem, family]. It appears
    # in the header and twice more in the MCFG_TRL trailer, and all copies must
    # agree. qcril compares it against the version the modem already has active
    # and skips the load when they match, so an edit that leaves it alone is
    # silently ignored.
    version = bytes(payload[20:24])
    if version[0] == 0xff:
        raise ValueError("minor version is already 0xff")
    bumped = bytes([version[0] + 1]) + version[1:]
    count = payload.count(version)
    if count != 3:
        raise ValueError("expected 3 copies of the version, found %d" % count)
    payload = bytearray(payload.replace(version, bumped))
    log("  MCFG minor version: %d -> %d" % (version[0], bumped[0]))

    out[mcfg_off:mcfg_off + mcfg_len] = payload

    # Re-hash. hash[0] covers the ELF header and program headers, hash[1] is
    # the hash segment's own slot and stays zero, hash[2] covers the payload.
    h0 = hashlib.sha256(bytes(out[:hdr_len])).digest()
    h2 = hashlib.sha256(bytes(payload)).digest()
    out[hash_off + 40:hash_off + 72] = h0
    out[hash_off + 104:hash_off + 136] = h2

    return bytes(out), bumped[0]


def elf_segments(data):
    """(offset, length) of each program header's contents, or None."""
    if len(data) < 0x34 or data[:4] != b"\x7fELF" or data[4] != 1:
        return None
    e_phoff, = struct.unpack_from("<I", data, 0x1c)
    e_phentsize, e_phnum = struct.unpack_from("<HH", data, 0x2a)
    if e_phnum < 3 or e_phoff + e_phnum * e_phentsize > len(data):
        return None
    segs = []
    for i in range(e_phnum):
        o = e_phoff + i * e_phentsize
        _, p_offset, _, _, p_filesz = struct.unpack_from("<5I", data, o)
        segs.append((p_offset, p_filesz))
    return segs


def is_software_config(data):
    """True for a software carrier config (mcfg_sw), false for anything else.

    /vendor/firmware_mnt/image holds more than carrier configs: mba.mbn is the
    modem boot authenticator and is not an MCFG at all, and mcfg_hw.mbn is a
    hardware configuration that belongs in a different directory. Staging
    either into mcfg_sw would be wrong, so identify the real ones by their
    payload rather than by filename.
    """
    segs = elf_segments(data)
    if not segs:
        return False
    off, length = segs[2]
    if off + length > len(data) or length < 8:
        return False
    payload = data[off:off + length]
    if payload[:4] != b"MCFG":
        return False
    config_type, = struct.unpack_from("<H", payload, 6)
    return config_type == 1     # 1 = software, 0 = hardware


def already_applied():
    """Has this script already run for this MARKER_VERSION?

    The marker alone decides. Testing whether the staged files are still
    present would re-stage on every boot -- init.qcom.sh deletes them every
    time -- and that would restart rild every boot for no benefit, because the
    modem keeps the activated configuration itself. If /data is wiped the
    marker goes with it and this runs again, which is correct.
    """
    try:
        with open(MARKER) as f:
            return f.read().strip() == str(MARKER_VERSION)
    except OSError:
        return False


def main():
    if already_applied():
        log("already applied, nothing to do")
        return 0

    # init.qcom.sh rm -rf's the target directory on every boot and sets this
    # property when it is done, so waiting on it avoids racing its cleanup.
    for _ in range(60):
        if getprop("ro.vendor.ril.mbn_copy_completed") == "1":
            break
        time.sleep(1)
    else:
        log("timed out waiting for ro.vendor.ril.mbn_copy_completed")
        return 1

    src = os.path.join(VENDOR, "row.mbn")
    if not os.path.exists(src):
        log("no %s -- nothing to stage" % src)
        return 1

    with open(src, "rb") as f:
        original = f.read()
    try:
        patched, minor = patch_config(original)
    except ValueError as e:
        log("refusing to patch row.mbn: %s" % e)
        return 1

    os.makedirs(TARGET, exist_ok=True)
    staged = []
    for name in sorted(os.listdir(VENDOR)):
        if not name.endswith(".mbn"):
            continue
        path = os.path.join(VENDOR, name)
        if name == "row.mbn":
            blob = patched
        else:
            try:
                with open(path, "rb") as f:
                    blob = f.read()
            except OSError:
                continue
            if not is_software_config(blob):
                continue
        dst = os.path.join(TARGET, name)
        with open(dst, "wb") as f:
            f.write(blob)
        os.chown(dst, RADIO_UID, 0)
        os.chmod(dst, 0o444)
        staged.append(name)
    log("staged %d config(s) (%s), row.mbn at MCFG minor %d"
        % (len(staged), " ".join(staged), minor))

    # Without these two qcril loads every config into its database, never runs
    # a selection query, deletes them all again and stops. They ship empty.
    setprop("persist.vendor.radio.sw_mbn_volte", "1")
    setprop("persist.vendor.radio.sw_mbn_openmkt", "1")
    setprop("persist.vendor.radio.sw_mbn_update", "1")
    setprop("persist.vendor.radio.sw_mbn_loaded", "0")

    os.makedirs(os.path.dirname(MARKER), exist_ok=True)
    with open(MARKER, "w") as f:
        f.write("%d\n" % MARKER_VERSION)

    # The modem keeps an activated config across reboots, so this restart is
    # paid once per install rather than on every boot.
    log("restarting rild to load and activate")
    setprop("ctl.restart", "ril-daemon")
    return 0


if __name__ == "__main__":
    sys.exit(main())
