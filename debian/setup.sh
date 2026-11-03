#!/bin/sh
# Runs inside the image (debos "run" action).
set -eu
echo wf2489t > /etc/hostname
echo "127.0.1.1	wf2489t" >> /etc/hosts
echo root:admin | chpasswd
# kernel: postinst hooks build the initramfs and u-boot-menu writes extlinux.conf
dpkg -i /var/tmp/kernel/linux-image-*-wf2489t_*.deb
rm -rf /var/tmp/kernel
systemctl enable systemd-networkd systemd-resolved systemd-timesyncd
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
apt-get clean
rm -rf /var/lib/apt/lists/*
