#!/bin/sh
# Hand the device's real WLAN MAC to the wcnss platform driver, before the wlan
# module is loaded.
#
# hdd_wlan_startup() takes the MAC from the platform driver, else the NV image,
# else the ini -- all three are empty or stock here, so prima autogenerates a
# 00:0a:f5:xx:xx:xx address from the SoC serial. The real addresses are in
# /mnt/vendor/persist/wlan_mac.bin, which nothing under Sailfish reads.
#
# Ordering is the whole point: prima reads the platform MAC once, at module
# init, hence ExecStartPre of wlan-module-load.service rather than a unit of
# its own. Setting it afterwards with `ip link set address` does not work --
# prima never tells the firmware, so association succeeds and the 4-way
# handshake never starts (tried, reverted).
#
# wcnss_wlan_macaddr_store() requires exactly 18 bytes, i.e. the 17 characters
# plus the newline `echo` appends.
set -u

MACFILE=/mnt/vendor/persist/wlan_mac.bin

node=$(echo /sys/devices/soc/*.qcom,wcnss-wlan/wcnss_mac_addr)
[ -w "$node" ] || { echo "macaddrsetup: no writable wcnss_mac_addr node"; exit 0; }
[ -r "$MACFILE" ] || { echo "macaddrsetup: $MACFILE not readable"; exit 0; }

# Only fill it in if the platform driver has nothing. If something already set a
# real address, leave it alone.
case "$(cat "$node" 2>/dev/null)" in
    00:00:00:00:00:00|"") ;;
    *) echo "macaddrsetup: wcnss_mac_addr already set, leaving it"; exit 0 ;;
esac

raw=$(sed -n 's/^Intf0MacAddress=\([0-9A-Fa-f]\{12\}\)$/\1/p' "$MACFILE" | head -1)
[ -n "$raw" ] || { echo "macaddrsetup: no Intf0MacAddress in $MACFILE"; exit 0; }

mac=$(echo "$raw" | sed 's/../&:/g; s/:$//' | tr 'A-F' 'a-f')

if echo "$mac" > "$node"; then
    echo "macaddrsetup: wcnss_mac_addr <- $mac (from $MACFILE)"
else
    echo "macaddrsetup: failed to write $mac to $node"
fi
