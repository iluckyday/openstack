#!/bin/sh
set -x

mkdir -p $TARGET_DIR/var/lib/libvirt/qemu $TARGET_DIR/var/lib/libvirt/secrets $TARGET_DIR/var/lib/libvirt/storage

ln -sf /run $TARGET_DIR/var/run

for srv in libvirtd.service libvirtd.socket libvirtd-ro.socket libvirtd-admin.socket libvirtd-tcp.socket libvirtd-tls.socket
do
	ln -sf /dev/null $TARGET_DIR/etc/systemd/system/$srv
done
