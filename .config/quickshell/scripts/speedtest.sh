#!/bin/sh
# Download/upload throughput probe for the network panel.
#
#   speedtest.sh down|up
#
# Prints one line per second: the current throughput in Mbps, so the QML side can show a live
# number while it runs. Method (borrowed from Omarchy's omarchy-network-speedtest): ask Fast.com for
# a few Netflix OCA URLs, run several parallel curl workers against them, and measure what actually
# crosses the interface via /sys/class/net/<iface>/statistics. That measures the LINK, not what one
# TCP stream happens to get, which is the number people care about.
#
# Requires curl + jq (both in the system profile). Exits 1 with a message on stderr if it cannot
# run, so the panel can show the reason instead of a zero.
set -e

direction="${1:-}"
test_seconds="${2:-15}"
probe=1.1.1.1
parallel=8
url_count=3

case "$direction" in
down | up) ;;
*)
    echo "usage: speedtest.sh down|up [seconds]" >&2
    exit 2
    ;;
esac

command -v curl >/dev/null 2>&1 || { echo "curl is missing" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is missing" >&2; exit 1; }

iface=$(ip route get "$probe" 2>/dev/null \
    | awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }')

if [ -z "$iface" ] || [ ! -r "/sys/class/net/$iface/statistics/rx_bytes" ]; then
    echo "no active interface route" >&2
    exit 1
fi

token="YXNkZmFzZGxmbnNkYWZoYXNkZmhrYWxm"
urls=$(curl -fsS --max-time 8 \
    "https://api.fast.com/netflix/speedtest/v2?https=true&token=$token&urlCount=$url_count" 2>/dev/null \
    | jq -r '.targets[]?.url // empty' 2>/dev/null) || true

if [ -z "$urls" ]; then
    echo "could not reach the speed test service" >&2
    exit 1
fi

pids=""

cleanup() {
    for pid in $pids; do
        kill "$pid" 2>/dev/null || true
    done
    wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM

worker() {
    set -- $urls
    count=$#
    idx=$(( $$ % count + 1 ))
    while :; do
        url=$(echo "$urls" | sed -n "${idx}p")
        [ -n "$url" ] || url=$(echo "$urls" | sed -n "1p")
        if [ "$direction" = "down" ]; then
            curl -fsS -o /dev/null --max-time 20 "$url" 2>/dev/null || return 0
        else
            dd if=/dev/zero bs=1M count=32 2>/dev/null \
                | curl -fsS -o /dev/null --max-time 20 -X POST --data-binary @- "$url" 2>/dev/null || return 0
        fi
        idx=$(( idx % count + 1 ))
    done
}

i=0
while [ "$i" -lt "$parallel" ]; do
    worker &
    pids="$pids $!"
    i=$((i + 1))
done

if [ "$direction" = "down" ]; then
    counter="/sys/class/net/$iface/statistics/rx_bytes"
else
    counter="/sys/class/net/$iface/statistics/tx_bytes"
fi

prev=$(cat "$counter")
started=$(date +%s)

while :; do
    sleep 1
    now=$(cat "$counter")
    elapsed=$(( $(date +%s) - started ))

    awk -v a="$prev" -v b="$now" 'BEGIN {
        d = b - a
        if (d < 0) d = 0
        printf "%.1f\n", d * 8 / 1000000
    }'

    prev=$now

    [ "$elapsed" -ge "$test_seconds" ] && break
done
