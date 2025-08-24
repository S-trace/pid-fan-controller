#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi
dest="/usr/local/pid-fan-controller"
unit_file="/etc/systemd/system"

CONFIG_FILE=${1:-pid_fan_controller_config.yaml}
echo "Config file set to ${CONFIG_FILE}"

DISK_CONFIG_FILE=${2:-disk_bin_temp_monitor.conf}
echo "Disk config file set to ${DISK_CONFIG_FILE}"


mkdir ${dest} 2>/dev/null

echo -n "Checking for presence of VENV..."
if ! [ -f "${dest}/pid_fan_env/bin/activate" ]; then
       echo "Attempting to create VENV..."
       pushd /usr/local/pid-fan-controller/
       python3 -m venv pid_fan_env
       popd
fi
source ${dest}/pid_fan_env/bin/activate

echo -n "Installing requirements to VENV..."
pip install -r requirements.txt || exit 1

for file in main_loop.py override_auto_fan_control.py pid_fan_controller.py set_manual_fan_speed.py get_disk_bin_temp.sh; do
	echo "Copying ${file} to ${dest}..."
	cp ${file} ${dest}
done

for file in ${CONFIG_FILE} ${DISK_CONFIG_FILE}; do
  echo "Copying ${file} to /etc..."
  cp "${file}" /etc/
done

for file in pid-fan-controller.service pid-fan-controller-sleep-hook.service set-manual-fan-speed@.service; do
	echo "Copying ${file} to ${unit_file}..."
	cp ${file} ${unit_file}
done

echo "Reloading systemd unit files..."
systemctl daemon-reload
