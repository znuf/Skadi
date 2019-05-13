#!/bin/bash

SKADI_USER="skadi"
DISK_USAGE_BEFORE_CLEANUP=$(df -h)

# Make sure udev does not block our network - http://6.ptmc.org/?p=164
echo "==> Cleaning up udev rules"
rm -rf /dev/.udev/
rm -rf /lib/udev/rules.d/75-persistent-net-generator.rules

echo "==> Cleaning up leftover dhcp leases"
# Ubuntu 10.04
if [ -d "/var/lib/dhcp3" ]; then
    rm /var/lib/dhcp3/*
fi
# Ubuntu 12.04 & 14.04
if [ -d "/var/lib/dhcp" ]; then
    rm /var/lib/dhcp/*
fi

UBUNTU_VERSION=$(lsb_release -sr)
# Add delay to prevent "vagrant reload" from failing
echo "pre-up sleep 2" >> /etc/network/interfaces

echo "==> Cleaning up tmp"
rm -rf /tmp/*

# Cleanup apt cache
apt-get -y autoremove --purge
apt-get -y clean
apt-get -y autoclean

# Remove Bash history
unset HISTFILE
rm -f /root/.bash_history
rm -f /home/$SKADI_USER/.bash_history
rm -f /home/$SKADI_USER/.bash_history

# Clean up log files
find /var/log -type f | while read f; do echo -ne '' > "${f}"; done;

echo "==> Clearing last login information"
>/var/log/lastlog
>/var/log/wtmp
>/var/log/btmp

# Whiteout /boot
echo '==> Clear out swap and disable until reboot'
set +e
swapuuid=$(/sbin/blkid -o value -l -s UUID -t TYPE=swap)
case "$?" in
    2|0) ;;
    *) exit 1 ;;
esac
set -e
# if [ "x${swapuuid}" != "x" ]; then
#     # Whiteout the swap partition to reduce box size
#     # Swap is disabled till reboot
#     swappart=$(readlink -f /dev/disk/by-uuid/$swapuuid)
#     /sbin/swapoff "${swappart}"
#     dd if=/dev/zero of="${swappart}" bs=1M || echo "dd exit code $? is suppressed"
#     /sbin/mkswap -U "${swapuuid}" "${swappart}"
# fi

# Disable Swap on reboot
sudo sed -i '/ swap / s/^/#/' /etc/fstab

echo '==> Zero out free space on root partition /'
# Zero out the free space to save space in the final image
dd if=/dev/zero of=/EMPTY bs=1M  || echo "dd exit code $? is suppressed"
rm -f /EMPTY

# Make sure we wait until all the data is written to disk, otherwise
# Packer might quite too early before the large files are deleted
sync

echo "==> Disk usage before cleanup"
echo "${DISK_USAGE_BEFORE_CLEANUP}"

echo "==> Disk usage after cleanup"
df -h
