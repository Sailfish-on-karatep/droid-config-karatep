#!/bin/sh
# Hand the FM SMD transport switch to the audio group so the Media app can use it.
#
# radio-iris talks to the WCNSS FM core over an SMD channel that radio-iris-transport
# opens. That transport has no module_init at all -- the whole driver is one
# module_param_call (drivers/media/radio/radio-iris-transport.c:45), so the channel
# opens only when something writes 1 to
#
#   /sys/module/radio_iris_transport/parameters/fmsmd_set
#
# and closes when something writes 0 (radio_hci_smd_deregister() also resets the
# parameter to 0 itself, so this is a per-session cycle, not a one-off at boot).
#
# On Android that write is driven by init.qcom.rc:
#
#   on property:hw.fm.init=1
#       write /sys/module/radio_iris_transport/parameters/fmsmd_set 1
#
# with libfm_jni setting hw.fm.init. Nothing on Sailfish sets that property, but we
# do not need it to: qt5-qtmultimedia-plugin-mediaservice-irisradio has done the
# write itself since 0.6.0 ("Open v4l fd after smd is initialized", JB#48080) --
# fmradioiriscontrol.cpp hardcodes the same path and writes "1"/"0" around each
# session. The plugin runs as defaultuser, and init.qcom.rc's `on boot` chowns the
# parameter to system:system 0660, which defaultuser cannot write. The write fails
# silently inside an `if (f.open(...))`, the plugin opens /dev/radio0 anyway, and
# every ioctl then returns ENODEV with "iris_radio: __radio_hci_request, hci dev is
# null" in dmesg. That is the whole reason FM never worked here.
#
# So the only thing missing is permission. droid-config-mido does this same fix as
# `chmod a+w`; we hand it to the audio group instead, which defaultuser is already
# in, rather than making a kernel parameter world-writable. The audio group is also
# what hadk-faq's 999-droid-fm.rules gives /dev/radio0, so the two match.
#
# Ordering matters: this must run after droid-hal-init has processed init.qcom.rc's
# `on boot`, or that chown lands afterwards and puts it back to system:system.
# See droid-fm-up.service.

set -eu

FMSMD=/sys/module/radio_iris_transport/parameters/fmsmd_set

chgrp audio "$FMSMD"
chmod 0660 "$FMSMD"
