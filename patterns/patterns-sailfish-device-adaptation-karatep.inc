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

# The -dummy-af is needed for newer devices that run the main
# audiosystem-passthrough in qti mode (e.g. >=Android 9 Qualcomm),
# to fix non-responding Camera app and/or voice during a phone call:
#Requires: audiosystem-passthrough-dummy-af

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
# sailfish-devicelock-fpd (pulled in by the Fingerprint block below) REPLACES
# jolla-devicelock-daemon-encsfa rather than complementing it -- it Conflicts
# with both jolla-devicelock-daemon-encsfa and jolla-devicelock-plugin-encsfa,
# and Provides nemo-devicelock-daemon, jolla-devicelock and
# jolla-devicelock-plugin-encsfa >= 0.1.42 in their place, adding the
# fingerprint-unlock path on top.
#
# Requiring both makes the adaptation pattern uninstallable, and mic fails the
# whole image with an unhelpful message that names only the pattern:
#     repo problem: the to be installed
#     patterns-sailfish-device-configuration-karatep ... requires
#     'patterns-sailfish-device-adaptation-karatep', but this requirement
#     cannot be provided
#
#Requires: jolla-devicelock-daemon-encsfa

# Enable home encryption
#Requires: sailfish-device-encryption

# For GPS
Requires: geoclue-provider-hybris

# Telephony
Requires: ofono-ril-binder-plugin

# Bluetooth
Requires: bluebinder

# Fingerprint (FPC 1020)
#
# The hardware side is already in place on karatep and needs nothing from us:
# the kernel has CONFIG_INPUT_FPC_1020=y (drivers/input/misc/fpc1020_tee_qsee4.c,
# IRQ thread irq/16-soc:fpc1), and the vendor HAL
# /vendor/bin/hw/android.hardware.biometrics.fingerprint@2.0-service is started
# by droid-hal-init and registers
# android.hardware.biometrics.fingerprint@2.1::IBiometricsFingerprint.
#
# sailfish-fpd is Jolla's fingerprint daemon, but it needs a closed,
# per-device sailfish-fpd-slave package that does not exist for karatep.
# sailfish-fpd-community implements the same org.sailfishos.fingerprint1 D-Bus
# API and talks to the HIDL service itself through libhybris, so it replaces
# it -- its spec carries "Provides: sailfish-fpd", which is what satisfies
# sailfish-devicelock-fpd below. Requiring it by name is deliberate: without
# that, the dependency could equally be resolved by Jolla's sailfish-fpd from
# the 'jolla' repo, which would then sit there with no slave and never work.
#
# Built from hybris/mw/sailfish-fpd-community (see bin/build-fpd.sh for the
# Android library and bin/build-fpd-rpm.sh for the two RPMs). fake_crypt is
# NOT needed here -- it is only for keymaster 4, and karatep declares
# keymaster 3.0 in device/lenovo/karate-common/manifest.xml.
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
