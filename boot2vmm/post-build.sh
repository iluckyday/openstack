#!/bin/sh

mkdir -p $TARGET_DIR/var/lib/libvirt/qemu $TARGET_DIR/var/lib/libvirt/secrets $TARGET_DIR/var/lib/libvirt/storage

ln -sf /run $TARGET_DIR/var/run
