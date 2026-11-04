#!/bin/sh
# Runs inside the image (debos "run" action).
set -eu
echo wf2489t > /etc/hostname
echo "127.0.1.1	wf2489t" >> /etc/hosts
echo root:admin | chpasswd
# kernel: postinst hooks build the initramfs and u-boot-menu writes extlinux.conf
apt-get install -y --no-install-recommends /var/tmp/kernel/*.deb   # kernel, AIC8800 firmware + Wi-Fi driver, TouchKio (+ its dependencies)
rm -rf /var/tmp/kernel
systemctl enable systemd-networkd systemd-resolved systemd-timesyncd
# kiosk: browser on the display (URL in /etc/default/kiosk)
useradd --system --create-home --groups video,render,input,audio kiosk
chmod 755 /usr/local/bin/kiosk-session
chmod 600 /etc/default/kiosk   # may hold the MQTT password
systemctl enable kiosk.service
systemctl enable aic8800-bluetooth.service
chmod 755 /usr/local/bin/wlopm /usr/local/bin/wf2489t-mqtt
systemctl enable wf2489t-mqtt.service
chmod 440 /etc/sudoers.d/kiosk-power
systemctl set-default graphical.target
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
apt-get clean
rm -rf /var/lib/apt/lists/*
