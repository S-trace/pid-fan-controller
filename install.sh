#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi
dest="/usr/local/pid-fan-controller"
unit_file="/etc/systemd/system"

CONFIG_FILE=${1:-pid_fan_controller_config.yaml}
echo "Config file set to ${CONFIG_FILE}"

mkdir ${dest} 2>/dev/null

echo -n "Checking for presence of VENV..."
RESULTSTR=$(source ${dest}/pid_fan_env/bin/activate)
EXITCODE=$?
if [ "$EXITCODE" -ne 0 ]; then
       echo "Failed"
       echo "Attempting to create VENV..."
       pushd /usr/local/pid-fan-controller/
       python3 -m venv pid_fan_env
       popd
       source ${dest}/pid_fan_env/bin/activate
fi       

echo -n "Installing requirements to VENV..."
pip install -r requirements.txt

FINAL_RESULT="OK"
for module in $(cat requirements.txt); do
echo -n "Checking for module ${module}... "
RESULT=$(module=${module} ${dest}/pid_fan_env/bin/python3 -c 'import pkgutil, os; print("OK" if pkgutil.find_loader(os.environ["module"]) else "missing")')
echo "$RESULT"
if [ "$RESULT" != "OK" ]; then
	FINAL_RESULT="Failed"
fi
done

if [ "$FINAL_RESULT" != "OK" ]; then
	exit 1
fi

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
