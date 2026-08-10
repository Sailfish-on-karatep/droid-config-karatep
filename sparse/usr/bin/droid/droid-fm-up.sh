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
# Ordering matters, and systemd ordering alone cannot express it. init.qcom.rc has
#
#   on boot
#       chown system system /sys/module/radio_iris_transport/parameters/fmsmd_set
#
# and droid-hal-init.service is Type=simple, so systemd calls it started the moment
# it forks, while Android init works through `on boot` asynchronously some seconds
# later. After=droid-hal-init.service therefore buys nothing: measured on device,
# this unit ran 13 s into boot and init's chown still landed afterwards and put the
# group back to system.
#
# So wait for the chown rather than race it. The kernel creates module parameters
# root:root -- 532 of the 533 on this device still are -- and the only one that is
# system:system is this one, because init.qcom.rc is what makes it so. That makes
# system:system an unambiguous "init has processed `on boot`" signal for exactly the
# file we care about, so observing it means we are past the chown, not guessing at
# it. `on boot` runs once, so nothing chowns it back after this point.
#
# If the ownership never shows up -- someone dropped the init.qcom.rc block, say --
# fall through after the timeout and apply anyway rather than leaving FM broken.

set -eu

FMSMD=/sys/module/radio_iris_transport/parameters/fmsmd_set

i=0
while [ "$(stat -c %U:%G "$FMSMD")" != "system:system" ] && [ "$i" -lt 60 ]; do
    sleep 1
    i=$((i + 1))
done

chgrp audio "$FMSMD"
chmod 0660 "$FMSMD"
