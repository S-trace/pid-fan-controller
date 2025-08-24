#!/usr/bin/env sh
[ -n "$CONFIG_FILE" ] || echo "CONFIG_FILE is undefined - please define it in your docker-compose.yml and restart the project"
.//override_auto_fan_control.py 1
.//main_loop.py
