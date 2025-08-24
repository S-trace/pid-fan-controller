# Installing on Aoostar WTR PRO with Proxmox VE 9.0

## Go to the place for sources
```sh
pushd /usr/src/
```

## Enable pve-no-subscription repository (using post-pve-install.sh or manually):
```sh
curl -fsSLO https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/post-pve-install.sh
bash post-pve-install.sh
```

## Install deps
```sh
apt install -y dkms git python3.13-venv pve-headers python3-pip
```

## Install kernel driver for T8613E (Aoostar WTR PRO fan controller) as it87 in 6.14.8-2-pve does not support IT8613E
```sh
git clone https://github.com/a1wong/it87 it87-0.0
dkms install it87/0.0
```

## Load it87 right now
```sh
modprobe it87
```

## Enable it87 loading at boot
```sh
echo it87 > /etc/modules-load.d/it87.conf
```

## Check if it87 loaded successfully and T8613E is found: "it87: Found IT8613E chip at 0xa30, revision 8" means it's OK.
```sh
dmesg | grep it87:
```
### Ignore "it87: module verification failed: signature and/or required key missing - tainting kernel" message - it's OK.

## Install pid-fan-controller userspace fan control daemon
```sh
git clone https://github.com/S-trace/pid-fan-controller
pushd pid-fan-controller
./install.sh pid_fan_controller_config_WTR_PRO.yaml
popd
```

## Look how smooth it's works now
```sh
apt -y install stress s-tui
s-tui
```
Switch Mode to Stress and watch charts, exit when satisfied.

## Go back where we was before
```sh
popd
```
