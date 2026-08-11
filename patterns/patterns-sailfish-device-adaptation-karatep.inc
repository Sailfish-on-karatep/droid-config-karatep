# Feel free to disable non-critical HA parts during devel by commenting lines out
# Generated in hadk by executing: rpm/dhd/helpers/add_new_device.sh

%package -n patterns-sailfish-device-adaptation-karatep
Summary: Jolla HW Adaptation karatep
Requires: droid-hal-karatep
Requires: droid-hal-karatep-img-boot
Requires: droid-hal-karatep-kernel-modules
Requires: droid-config-karatep-sailfish
Requires: droid-config-karatep-pulseaudio-settings
Requires: droid-config-karatep-policy-settings
Requires: droid-config-karatep-preinit-plugin
Requires: droid-config-karatep-flashing
Requires: droid-config-karatep-bluez5
Requires: droid-hal-version-karatep

# Hybris packages
Requires: libhybris-libEGL
Requires: libhybris-libGLESv2
Requires: libhybris-libwayland-egl

# Sensors
Requires: hybris-libsensorfw-qt5

# Vibra
Requires: ngfd-plugin-native-vibrator
Requires: libngf-qt5-qtfeedback

# Needed for /dev/touchscreen symlink
Requires: qt5-plugin-generic-evdev

Requires: pulseaudio-modules-droid
Requires: pulseaudio-modules-droid-hidl

# Sailfish has no AudioFlinger -- audio goes through PulseAudio -- but
# minimediaservice still waits on the media.audio_flinger binder service when a
# recording starts. Without -dummy-af it never arrives: minimediaservice logs
# "Waiting for service 'media.audio_flinger'" once a second forever, and since
# that same process also hosts CameraService, its binder threads park there and
# every later camera call queues behind them. That, not the encoder, is why the
# camera app stayed unresponsive until a reboot. -dummy-af answers the lookup
# with a stub. Note karatep does not run the main passthrough in qti mode (no
# AUDIOSYSTEM_PASSTHROUGH_TYPE in /etc/sysconfig/pulseaudio, no
# audiosystem-passthrough.service) -- it is needed here anyway.
Requires: audiosystem-passthrough-dummy-af

# for audio recording to work:
Requires: qt5-qtmultimedia-plugin-mediaservice-gstmediacapture

# These need to be per-device due to differing backends (fbdev, eglfs, hwc, ..?)
Requires: qt5-qtwayland-wayland_egl
Requires: qt5-qpa-hwcomposer-plugin
Requires: qtscenegraph-adaptation

# For hybris devices with droidmedia, see HADK pdf for more information
Requires: gstreamer1.0-droid
Requires: gmp-droid

# This is needed for notification LEDs
Requires: mce-plugin-libhybris

# USB mode controller
Requires: usb-moded

# hammerhead, grouper, and maguro use this in scripts, so include for all
Requires: rfkill

# enable device lock and allow to select untrusted software
#
# sailfish-devicelock-fpd (below) Conflicts with this and Provides it instead,
# so requiring both makes the pattern uninstallable.
#Requires: jolla-devicelock-daemon-encsfa

# Enable home encryption
#Requires: sailfish-device-encryption

# For GPS
Requires: geoclue-provider-hybris

# Telephony
#
# ofono-binder-plugin replaces the legacy grilio stack (it Obsoletes and
# Conflicts both ofono-ril-plugin and ofono-ril-binder-plugin, so this is a
# straight swap, not a coexistence). The reason for the move is VoLTE: IMS
# extensions load only into ofono-binder-plugin, via libofonobinderpluginext,
# so on the old stack ofono never publishes org.ofono.IpMultimediaSystem no
# matter what the hardware offers. Configuration moves from
# ril_subscription.conf to binder.conf.
Requires: ofono-binder-plugin

# VoLTE. Drives vendor.qti.hardware.radio.ims@1.0::IImsRadio, which this
# device's vendor partition provides and registers (imsradio0 and imsradio1).
# Selected by extPlugin=qti in binder.conf.
Requires: ofono-binder-plugin-ext-qti

# Bluetooth
Requires: bluebinder

# Fingerprint (FPC 1020)
#
# Jolla's sailfish-fpd needs a closed per-device slave package that does not
# exist for karatep; sailfish-fpd-community serves the same D-Bus API over
# libhybris and Provides: sailfish-fpd. Named explicitly so the dependency is
# not resolved by Jolla's package instead.
Requires: sailfish-fpd-community
Requires: sailfish-devicelock-fpd

# For FM radio on some QCOM devices
Requires: qt5-qtmultimedia-plugin-mediaservice-irisradio
Requires: jolla-mediaplayer-radio

# NFC support
# 1. binder plugin requires Android 8 or a newer base
# 2. pn54x plugin talks directly to pn54x driver
# These plugins are mutually exclusive, you need to pick one:
#Requires: nfcd-binder-plugin
#Requires: nfcd-pn54x-plugin

%description -n patterns-sailfish-device-adaptation-karatep
Pattern with packages for karatep HW Adaptation

%files -n patterns-sailfish-device-adaptation-karatep
