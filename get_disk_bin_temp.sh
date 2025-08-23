#!/bin/sh
# Monitor max disk temperature via smartctl with caching and log rotation.

set -euo pipefail
PATH="$PATH:/usr/sbin:/usr/bin"

CONFIG_FILE="${1:-/etc/disk_bin_temp_monitor.conf}"
LOG_ENABLED=0   # 0=off, 1=short temps, 2=short+full smartctl, 3=debug
LOG_FILE="/var/log/disk_bin_temp_monitor.log"
LOG_MAX_SIZE=1048576       # 1 MB
LOG_MAX_ROTATE=5
LOG_COMPRESS="gzip -9"

CACHE_FILE="/tmp/disk_bin_temp_monitor.cache"
CACHE_TTL=30

rotate_logs() {
    [ ! -f "$LOG_FILE" ] && return 0
    size=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
    [ "$size" -lt "$LOG_MAX_SIZE" ] && return 0

    i=$LOG_MAX_ROTATE
    while [ $i -gt 0 ]; do
        prev=$((i-1))
        [ $i -eq $LOG_MAX_ROTATE ] && rm -f "${LOG_FILE}.${i}"* 2>/dev/null || true
        if [ -f "${LOG_FILE}.${prev}" ]; then
            mv "${LOG_FILE}.${prev}" "${LOG_FILE}.${i}" || true
            [ $i -ge 2 ] && eval "$LOG_COMPRESS \"${LOG_FILE}.${i}\"" 2>/dev/null || true
        fi
        i=$prev
    done
    mv "$LOG_FILE" "${LOG_FILE}.1" || true
}

log() {
    lvl="$1"; shift
    if [ "$LOG_ENABLED" -ge "$lvl" ]; then
        echo "$(date '+%F %T') $*" >> "$LOG_FILE"
    fi
}

[ -f "$CONFIG_FILE" ] || { echo "Error: config $CONFIG_FILE not found!" >&2; exit 1; }

DISKS=""
while IFS= read -r line; do
    case "$line" in
        ''|\#*) continue ;;
        CACHE_TTL=*) CACHE_TTL="${line#*=}" ;;
        *) DISKS="$DISKS${DISKS:+ }$line" ;;
    esac
done < "$CONFIG_FILE"

rotate_logs
log 3 "Loaded config: disks='$DISKS' CACHE_TTL=$CACHE_TTL"

# cache file format: "<epoch> <max_temp>"
cache_time=0 cache_temp=0
if [ -f "$CACHE_FILE" ]; then
    IFS=' ' read -r cache_time cache_temp < "$CACHE_FILE" || true
    now=$(date +%s)
    age=$(( now - cache_time ))
    log 3 "Cache found: time=$cache_time temp=$cache_temp age=$age"
    if [ "$age" -lt "$CACHE_TTL" ]; then
        echo "$cache_temp"
        log 1 "Cache hit ${age}s, max=${cache_temp}C"
        exit 0
    fi
    log 3 "Cache expired"
else
    log 3 "No cache file found"
fi

max_temp=0
log 1 "smartctl run started"

for disk in $DISKS; do
    [ -b "$disk" ] || { log 1 "Skipping $disk (not a block device)"; continue; }
    log 3 "Running smartctl for $disk"

    if ! output=$(timeout 10 smartctl -a "$disk" 2>&1); then
        rc=$?
        log 1 "Error: smartctl failed for $disk (exit $rc)"
        [ "$LOG_ENABLED" -ge 2 ] && printf "%s\n" "$output" >> "$LOG_FILE"
        continue
    fi

    temps=""
    while IFS= read -r line; do
        case "$line" in
            *Temperature* )
                t=$(printf '%s\n' "$line" | awk '{print $NF}')
                case "$t" in *[!0-9]*) continue ;; esac
                temps="$temps $t"
                [ "$t" -gt "$max_temp" ] && max_temp=$t
                ;;
        esac
    done <<EOF
$output
EOF

    for t in $temps; do
        log 1 "$disk now has ${t}C"
        log 3 "Parsed temperature $t from $disk"
    done

    [ "$LOG_ENABLED" -ge 2 ] && printf "%s\n" "$output" >> "$LOG_FILE"
done

[ "$max_temp" -gt 0 ] || { echo "Error: no temp data" >&2; exit 1; }

echo "$max_temp"
log 1 "Max temperature $max_temp C"

# Save epoch + temp → no stat needed
now=$(date +%s)
umask 077
printf "%s %s\n" "$now" "$max_temp" > "$CACHE_FILE"
log 3 "Cache updated at $now with $max_temp C"
