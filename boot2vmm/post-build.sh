#!/bin/sh
set -x

mkdir -p $TARGET_DIR/var/lib/libvirt/qemu $TARGET_DIR/var/lib/libvirt/secrets $TARGET_DIR/var/lib/libvirt/storage

ln -sf /run $TARGET_DIR/var/run

mkdir -p $TARGET_DIR/etc/systemd/system/virtproxyd.service.d
cat << EOF > $TARGET_DIR/etc/systemd/system/virtproxyd.service.d/restart.conf
[Unit]
StartLimitIntervalSec=0
EOF
