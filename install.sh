#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi
dest="/usr/local/pid-fan-controller"
unit_file="/etc/systemd/system"

CONFIG_FILE=${1:-pid_fan_controller_config.yaml}
echo "Config file set to ${CONFIG_FILE}"

FINAL_RESULT="OK"
for module in six simple_pid yaml time glob subprocess; do
echo -n "Checking for module ${module}... "
RESULT=$(module=${module} python3 -c 'import pkgutil, os; print("OK" if pkgutil.find_loader(os.environ["module"]) else "missing")')
echo "$RESULT"
if [ "$RESULT" != "OK" ]; then
	FINAL_RESULT="Failed"
fi
done

if [ "$FINAL_RESULT" != "OK" ]; then
	exit 1
fi

mkdir ${dest} 2>/dev/null
for file in main_loop.py override_auto_fan_control.py pid_fan_controller.py set_manual_fan_speed.py; do
	echo "Copying ${file} to ${dest}..."
	cp ${file} ${dest}
done

echo "Copying ${CONFIG_FILE} to /etc..."
cp ${CONFIG_FILE} /etc

for file in pid-fan-controller.service pid-fan-controller-sleep-hook.service set-manual-fan-speed@.service; do
	echo "Copying ${file} to ${unit_file}..."
	cp ${file} ${unit_file}
done

echo "Reloading systemd unit files..."
systemctl daemon-reload
