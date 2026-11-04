#!/bin/sh
# Runs inside the image (debos "run" action).
set -eu
echo wf2489t > /etc/hostname
echo "127.0.1.1	wf2489t" >> /etc/hosts
echo root:admin | chpasswd
# everything for the tablet (kernel, kiosk, board support) from the local copy
# of the apt repository; the package adds the published repository for updates
echo "deb [trusted=yes] file:/var/tmp/repo ./" > /etc/apt/sources.list.d/local.list
apt-get update
apt-get install -y --no-install-recommends wf2489t
rm -rf /etc/apt/sources.list.d/local.list /var/tmp/repo
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
apt-get clean
rm -rf /var/lib/apt/lists/*
