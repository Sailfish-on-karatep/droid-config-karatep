#!/bin/sh
# Populate /var/lib/bluetooth/board-address for bluebinder_post.sh.
#
# bluebinder ships bluebinder_post.sh as ExecStartPost. It first calls this
# hook, and if /var/lib/bluetooth/board-address still does not exist it falls
# back to ro.bt.bdaddr_path, ro.vendor.bt.bdaddr_path and
# persist.vendor.service.bdroid.bdaddr. karatep sets none of those, so without
# this hook bluebinder_post.sh exits 1 ("Failed to get bluetooth address!"),
# systemd fails the unit, and Restart=always turns bluebinder into a restart
# loop that repeatedly powers the shared WCNSS/pronto radio up and down.
#
# On karatep the BD address belongs to the QTI BT HAL: /vendor/lib64/libbtnv.so
# keeps it in /mnt/vendor/persist/bluetooth/.bt_nv.bin as a 3-byte TLV header
# (tag 0x01, 0x01, len 0x06) followed by the 6-byte address, least significant
# octet first -- e.g. "01 01 06 ff ee dd cc bb aa" is AA:BB:CC:DD:EE:FF. The real
# value is per-device and is read off the device at boot, never stored here.
#
# This runs as ExecStartPost, so bluebinder has already created the vhci HCI
# device; prefer the address the kernel actually reports and use the NV file
# only as a fallback.

ADDRFILE=/var/lib/bluetooth/board-address
NVFILE=/mnt/vendor/persist/bluetooth/.bt_nv.bin

addr=
for hci in /sys/class/bluetooth/hci*; do
    [ -r "$hci/address" ] || continue
    a=$(cat "$hci/address")
    case "$a" in
        ""|00:00:00:00:00:00) continue ;;
    esac
    addr=$a
    break
done

if [ -z "$addr" ] && [ -s "$NVFILE" ]; then
    hex=$(od -An -tx1 -j 3 -N 6 "$NVFILE" | tr -d ' \n')
    if [ ${#hex} -eq 12 ]; then
        addr=$(echo "$hex" | sed 's/\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)/\6:\5:\4:\3:\2:\1/')
    fi
fi

# No address found: say nothing and let bluebinder_post.sh report the failure.
[ -n "$addr" ] || exit 0

mkdir -p /var/lib/bluetooth
echo "$addr" | tr 'abcdef' 'ABCDEF' > "$ADDRFILE" || exit 1
chown root:root "$ADDRFILE"
chmod 644 "$ADDRFILE"
exit 0
