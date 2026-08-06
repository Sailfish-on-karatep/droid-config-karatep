#!/bin/sh
# Hand the device's real WLAN MAC to the wcnss platform driver, BEFORE the wlan
# module is loaded.
#
# WHY THIS IS NEEDED
# ------------------
# prima picks the interface MAC in hdd_wlan_startup()
# (drivers/staging/prima/CORE/HDD/src/wlan_hdd_main.c) in this order:
#
#     ret = wcnss_get_wlan_mac_address((char*)&mac_addr.bytes);   <- 1. platform driver
#     if ((0 == ret) && (!vos_is_macaddr_zero(&mac_addr))) { use it }
#     else if (hdd_update_config_from_nv(...) != SUCCESS) {       <- 2. NV field image
#         static const v_MACADDR_t default_address =
#                                  {{0x00,0x0A,0xF5,0x89,0x89,0xFF}};
#         if (0 == memcmp(&default_address, &cfg_ini->intfMacAddr[0], ...))
#             hdd_generate_iface_mac_addr_auto(...);              <- 3. autogenerate
#     }
#
# On karatep all three inputs are empty or default, so we land on (3):
#   * /sys/devices/soc/*.qcom,wcnss-wlan/wcnss_mac_addr reads 00:00:00:00:00:00,
#   * /mnt/vendor/persist/WCNSS_qcom_wlan_nv.bin contains no MAC, and
#   * /vendor/firmware/wlan/prima/WCNSS_qcom_cfg.ini still has the stock
#     Intf0MacAddress=000AF58989FF, which is the exact constant that triggers
#     the autogen branch.
# The result is a made-up 00:0a:f5:xx:xx:xx address derived from the SoC serial.
#
# The device's real addresses are in /mnt/vendor/persist/wlan_mac.bin, in ini
# syntax (values below are illustrative -- the real ones are per-device and are read
# off the device at boot, never stored in this repo), and nothing under Sailfish reads
# them: prima never mentions the file
# (`grep -r wlan_mac` over drivers/staging/prima finds nothing) and neither does
# /vendor/bin/wcnss_service (its strings reference only the ini and NV paths).
#
#     Intf0MacAddress=AABBCCDDEEFF
#     Intf1MacAddress=AABBCCDDEEF0
#     END
#
# So we feed input (1) ourselves. wcnss_wlan_macaddr_store()
# (drivers/net/wireless/wcnss/wcnss_wlan.c) parses "%02x:..." and requires
# strlen(buf) == WCNSS_USER_MAC_ADDR_LENGTH == 18, i.e. exactly the 17 characters
# plus the newline that `echo` appends -- do not use `printf` without one, and do
# not quote-strip the newline away.
#
# ORDERING IS THE WHOLE POINT
# ---------------------------
# This must run BEFORE `modprobe wlan`, which is why it is an ExecStartPre of
# wlan-module-load.service rather than a service of its own. hdd_wlan_startup()
# reads the platform MAC once, at module init.
#
# DO NOT be tempted to "fix" this after the fact with `ip link set wlan0
# address`. prima's __hdd_set_mac_address() only does two memcpys -- into
# pAdapter->macAddressCurrent and dev->dev_addr -- and never tells the firmware.
# Doing that leaves the firmware associating under the old address while the
# netdev filters for the new one: association succeeds, then EAPOL message 1 is
# never delivered, the 4-way handshake never starts, and the AP gives up with
# deauth reason=2. That was tried, it broke WLAN completely, and it was reverted.
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
