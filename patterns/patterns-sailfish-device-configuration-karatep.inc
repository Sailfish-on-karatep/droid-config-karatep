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

# Add voice recorder. Jolla's "Recorder" app -- verified to resolve in the
# device target with `zypper se --match-exact sailfish-audiorecorder` before
# being enabled, per the note above about unresolvable names taking down the
# whole pattern. It is also the easiest way to exercise the microphones from
# the UI, which is otherwise awkward on this port.
Requires: sailfish-audiorecorder

# First-party applications.
#
# Sailfish composes images from patterns rather than package lists (see
# https://docs.sailfishos.org/Reference/Software_Packaging/Patterns_and_Images),
# so require the app patterns instead of hand-listing their contents. That way
# the set tracks whatever Jolla puts in them rather than drifting against a list
# maintained here.
#
#   patterns-sailfish-applications           the base app set: camera, gallery,
#       browser, clock, contacts, messages, vault, archive, tutorial,
#       startupwizard, locale, all-translations-pack and the jolla-settings-*
#       pieces. Mostly already present in the image; required explicitly so it
#       is a stated dependency rather than an accident of what the base pulls.
#   patterns-sailfish-store-applications     the Jolla Store apps: calculator,
#       calendar, email, mediaplayer, notes, office and weather.
#
# Both were resolved against the lenovo-karatep-aarch64 target with
# `zypper install --dry-run` before being added -- a name that does not resolve
# takes the whole adaptation pattern down and aborts the image build with a
# message that names only the pattern, not the missing package.
Requires: patterns-sailfish-applications
Requires: patterns-sailfish-store-applications

# Not in either pattern.
Requires: jolla-settings-system-flashlight

# jolla-maps is genuinely absent from the repos available here and cannot be
# preinstalled. Weather is not: it ships as sailfish-weather (pulled in by
# patterns-sailfish-store-applications above), and the earlier note claiming it
# was unavailable was looking for the wrong package name.

# Check binder
#Requires: libgbinder-tools package

# Devices with 2G or more memory should also include this booster
# to improve camera startup times and the like
#Requires: mapplauncherd-booster-silica-qt5-media

%description -n patterns-sailfish-device-configuration-karatep
Pattern with packages for karatep configurations

%files -n patterns-sailfish-device-configuration-karatep
