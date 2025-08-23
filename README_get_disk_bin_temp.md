# Disk Bin Temperature Monitor

A lightweight POSIX `sh` script to monitor maximum disk temperature using
`smartctl`, with caching and log rotation.

## Features

- Collects disk temperature from `smartctl -a`
- Caches results for a configurable TTL (to avoid spamming `smartctl`)
- Rotates and compresses log files (`gzip -9` by default)
- Multiple logging levels (silent, short, full smartctl output, debug)
- Configurable via a simple config file

## Requirements

- `smartmontools` (`smartctl`)
- `timeout` command (from GNU coreutils or BusyBox)
- `gzip` (or another compressor if you change `$LOG_COMPRESS`)
- POSIX shell (`/bin/sh`)

## Installation

1. Copy the script to `/usr/local/bin/disk_bin_temp_monitor.sh`
2. Make it executable:
   ```sh
   chmod +x /usr/local/bin/disk_bin_temp_monitor.sh
   ```
3. Create a config file /etc/disk_bin_temp_monitor.conf

## Configuration

Example /etc/disk_bin_temp_monitor.conf:
```
# List of block devices to monitor
/dev/sda
/dev/sdb

# Optional cache TTL in seconds
CACHE_TTL=60
```

## Logging

Controlled by the LOG_ENABLED variable inside the script:
	0 – no logging
	1 – short messages with temperatures
	2 – + full smartctl output
	3 – debug (verbose)

Log file: /var/log/disk_bin_temp_monitor.log

## Log rotation

Max log size: 1 MB (LOG_MAX_SIZE)
Rotations: 5 files (.1 ... .5)
Compression: gzip -9 (applied to .2+)

## Usage

### Run manually:
```sh
./disk_bin_temp_monitor.sh
```

Output: max temperature in °C.

#### Example:

```sh
$ /usr/local/pid-fan-controller/bin/disk_bin_temp_monitor.sh
42
```

### Integrate with pid_fan_controller_config as new heat_pressure_src:
```yaml
heat_pressure_srcs:
  - name: HDD
    temp_cmd: /usr/local/pid-fan-controller/get_disk_bin_temp.sh /etc/disk_bin_temp_monitor.conf
	PID_params:
      set_point: 50
      P: -0.03
      I: -0.002
      D: -0.0005
```

### Integrate with cron or systemd timers for periodic monitoring.

## Exit codes

0 – success, printed max temperature
1 – config not found or no temperature data
other – internal errors

## Cache

Cache file: `/tmp/disk_bin_temp_monitor.cache`

### Format:

<epoch> <max_temp>

If cache age < CACHE_TTL, the script will return cached value.
