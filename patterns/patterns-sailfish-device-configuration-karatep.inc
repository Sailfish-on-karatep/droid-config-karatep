# Feel free to disable non-critical HA parts during devel by commenting lines out
# Generated in hadk by executing: rpm/dhd/helpers/add_new_device.sh

%package -n patterns-sailfish-device-configuration-karatep
Summary: Jolla Configuration karatep
Requires: patterns-sailfish-device-configuration-common-karatep
Requires: patterns-sailfish-device-adaptation-karatep

# For devices with cellular modem. Those without one, please comment out:
Requires: patterns-sailfish-cellular-apps

# Early stages of porting benefit from these:
Requires: patterns-sailfish-device-tools

Requires: sailfish-content-graphics-z%{icon_res}

# For multi-SIM devices
Requires: jolla-settings-networking-multisim

# For devices which support NFC
#Requires: jolla-settings-system-nfc
#Requires: nfcd-dbuslog-plugin
#Requires: nfcd-mce-plugin

# Introduced starting Sailfish OS 2.0.4.x:
# 3rd party accounts like Twitter, VK, cloud services, etc
Requires: jolla-settings-accounts-extensions-3rd-party-all

# Introduced starting Sailfish OS 2.1.1.26
# Required for Jolla Store Access
Requires: patterns-sailfish-consumer-generic

# For Mozilla location services (online)
Requires: geoclue-provider-mlsdb

# Voice recorder (Jolla's "Recorder"), also the easiest way to exercise the
# microphones from the UI.
Requires: sailfish-audiorecorder

# First-party applications: require the app patterns rather than hand-listing
# their contents, so the set tracks whatever Jolla puts in them. Resolve any
# name against the device target before adding it -- one that does not resolve
# takes the whole pattern down and aborts the image build.
Requires: patterns-sailfish-applications
Requires: patterns-sailfish-store-applications

# Not in either pattern.
Requires: jolla-settings-system-flashlight

# jolla-maps is absent from the repos available here and cannot be preinstalled.

# Check binder
#Requires: libgbinder-tools package

# Devices with 2G or more memory should also include this booster
# to improve camera startup times and the like
#Requires: mapplauncherd-booster-silica-qt5-media

%description -n patterns-sailfish-device-configuration-karatep
Pattern with packages for karatep configurations

%files -n patterns-sailfish-device-configuration-karatep
