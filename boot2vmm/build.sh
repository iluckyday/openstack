#!/bin/sh
set -ex

apt update
apt install -y libelf-dev

export KCONFIG_ALLCONFIG=$(pwd)/boot2vmm/build.config

RELEASE=$(curl -skL https://buildroot.org/downloads/Vagrantfile | awk  -F"'" '/RELEASE=/ {print $2}')
curl -skL https://buildroot.org/downloads/buildroot-${RELEASE}.tar.gz | tar -xz
cd buildroot-${RELEASE}

make -s allnoconfig
make -s

cp output/images/rootfs.iso9660 /tmp/boot2vmm.iso
