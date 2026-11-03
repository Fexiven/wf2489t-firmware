#!/bin/sh
# Runs inside the image (debos "run" action).
set -eu
echo wf2489t > /etc/hostname
echo "127.0.1.1	wf2489t" >> /etc/hosts
echo root:admin | chpasswd
# kernel: postinst hooks build the initramfs and u-boot-menu writes extlinux.conf
dpkg -i /var/tmp/kernel/*.deb   # kernel, AIC8800 firmware + Wi-Fi driver
rm -rf /var/tmp/kernel
systemctl enable systemd-networkd systemd-resolved systemd-timesyncd
# kiosk: browser on the display (URL in /etc/default/kiosk)
useradd --system --create-home --groups video,render,input,audio kiosk
systemctl enable kiosk.service
systemctl enable aic8800-bluetooth.service
systemctl set-default graphical.target
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
apt-get clean
rm -rf /var/lib/apt/lists/*
