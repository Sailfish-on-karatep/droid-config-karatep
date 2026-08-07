#!/bin/sh
# Populate /var/lib/bluetooth/board-address for bluebinder_post.sh, which
# otherwise fails the unit and restart-loops the shared WCNSS radio: karatep
# sets none of the ro.*bt.bdaddr_path properties it falls back to.
#
# bluebinder has already created the vhci device by ExecStartPost, so prefer
# the address the kernel reports. Fallback is the QTI BT HAL's NV blob, where
# the address follows a 3-byte TLV header, least significant octet first.

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
