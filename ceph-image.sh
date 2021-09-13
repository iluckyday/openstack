#!/bin/bash
set -ex

timedatectl set-timezone "Asia/Shanghai"

release=$(curl -sSkL https://www.debian.org/releases/ | grep -oP 'codenamed <em>\K(.*)(?=</em>)')
include_apps="systemd,systemd-sysv,sudo,openssh-server,busybox,xz-utils,ca-certificates"

export DEBIAN_FRONTEND=noninteractive
apt-config dump | grep -we Recommends -e Suggests | sed 's/1/0/' | tee /etc/apt/apt.conf.d/99norecommends
sed -i '/src/d' /etc/apt/sources.list
rm -rf /etc/apt/sources.list.d
apt update
apt install -y debootstrap qemu-system-x86 qemu-utils

MNTDIR=/tmp/debian
mkdir -p ${MNTDIR}

qemu-img create -f raw /tmp/debian.raw 201G
loopx=$(losetup --show -f -P /tmp/debian.raw)
mkfs.ext4 -F -L debian-root -b 1024 -I 128 -O "^has_journal" $loopx
mount $loopx ${MNTDIR}

sed -i 's/ls -A/ls --ignore=lost+found -A/' /usr/sbin/debootstrap
/usr/sbin/debootstrap --no-check-gpg --no-check-certificate --components=main,contrib,non-free --include="$include_apps" --variant minbase ${release} ${MNTDIR}

mount -t proc none ${MNTDIR}/proc
mount -o bind /sys ${MNTDIR}/sys
mount -o bind /dev ${MNTDIR}/dev

cat << EOF > ${MNTDIR}/etc/fstab
LABEL=debian-root /          ext4    defaults,noatime              0 0
tmpfs             /run       tmpfs   defaults,size=50%             0 0
tmpfs             /tmp       tmpfs   mode=1777,size=90%            0 0
tmpfs             /var/log   tmpfs   defaults,noatime              0 0
EOF

cat << EOF > ${MNTDIR}/etc/apt/apt.conf.d/99freedisk
APT::Authentication "0";
APT::Get::AllowUnauthenticated "1";
Dir::Cache "/dev/shm";
Dir::State::lists "/dev/shm";
Dir::Log "/dev/shm";
DPkg::Post-Invoke {"/bin/rm -f /dev/shm/archives/*.deb || true";};
EOF

cat << EOF > ${MNTDIR}/etc/apt/apt.conf.d/99norecommend
APT::Install-Recommends "0";
APT::Install-Suggests "0";
EOF

cat << EOF > ${MNTDIR}/etc/dpkg/dpkg.cfg.d/99nofiles
path-exclude *__pycache__*
path-exclude *.py[co]
path-exclude /usr/share/doc/*
path-exclude /usr/share/man/*
path-exclude /usr/share/bug/*
path-exclude /usr/share/groff/*
path-exclude /usr/share/info/*
path-exclude /usr/share/lintian/*
path-exclude /usr/share/linda/*
path-exclude /usr/share/locale/*
path-exclude /usr/lib/locale/*
path-include /usr/share/locale/en*
path-exclude /usr/include/*
path-exclude /usr/lib/x86_64-linux-gnu/perl/*/auto/Encode/CN*
path-exclude /usr/lib/x86_64-linux-gnu/perl/*/auto/Encode/JP*
path-exclude /usr/lib/x86_64-linux-gnu/perl/*/auto/Encode/KR*
path-exclude /usr/lib/x86_64-linux-gnu/perl/*/auto/Encode/TW*
path-exclude *bin/x86_64-linux-gnu-dwp
path-exclude *bin/systemd-analyze
path-exclude *bin/resolve_stack_dump
path-exclude /usr/lib/x86_64-linux-gnu/libicudata.a
path-exclude /lib/modules/*/kernel/drivers/net/ethernet*
path-exclude /usr/share/python-babel-localedata/locale-data*
path-exclude /boot/System.map*
path-exclude /lib/modules/*/sound*
EOF

mkdir -p ${MNTDIR}/etc/systemd/system-environment-generators
cat << EOF > ${MNTDIR}/etc/systemd/system-environment-generators/20-python
#!/bin/sh
echo 'PYTHONDONTWRITEBYTECODE=1'
echo 'PYTHONSTARTUP=/usr/lib/pythonstartup'
EOF
chmod +x ${MNTDIR}/etc/systemd/system-environment-generators/20-python

cat << EOF > ${MNTDIR}/etc/profile.d/python.sh
#!/bin/sh
export PYTHONDONTWRITEBYTECODE=1 PYTHONSTARTUP=/usr/lib/pythonstartup
EOF

cat << EOF > ${MNTDIR}/usr/lib/pythonstartup
import readline
import time

readline.add_history("# " + time.asctime())
readline.set_history_length(-1)
EOF

cat << EOF > ${MNTDIR}/etc/pip.conf
[global]
download-cache=/tmp
cache-dir=/tmp
EOF

mkdir -p ${MNTDIR}/etc/initramfs-tools/conf.d
cat << EOF > ${MNTDIR}/etc/initramfs-tools/conf.d/custom
#MODULES=dep
COMPRESS=xz
EOF

cat << EOF > ${MNTDIR}/etc/systemd/system/server-init.service
[Unit]
Description=stack init script
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/server-init.sh
ExecStartPost=/bin/rm -f /etc/systemd/system/server-init.service /etc/systemd/system/multi-user.target.wants/server-init.service /usr/sbin/server-init.sh
RemainAfterExit=true
EOF

cat << "EOF" > ${MNTDIR}/usr/sbin/server-init.sh
#!/bin/bash
set -ex

UUID=$(cat /sys/class/dmi/id/product_uuid)

ifnames=$(find /sys/class/net -name en* -execdir basename '{}' ';' | sort)
for (( n=1; n<=5; n++)); do
	for ifname in $ifnames; do
		busybox ip addr add 169.254.$((RANDOM%256)).$((RANDOM%256))/16 dev $ifname
		busybox ip link set dev $ifname up
		busybox wget -qO /tmp/run.sh http://169.254.169.254/$UUID/run.sh && br=y && break || busybox ip addr flush dev $ifname
	done
	[ -n $br ] && break || sleep 1
done

[ -r /tmp/run.sh ] && source /tmp/run.sh && rm -f /tmp/run.sh || exit 1
EOF
chmod +x ${MNTDIR}/usr/sbin/server-init.sh

sed -i '/src/d' ${MNTDIR}/etc/apt/sources.list
( umask 226 && echo 'Defaults env_keep+="PYTHONDONTWRITEBYTECODE PYTHONHISTFILE"' > ${MNTDIR}/etc/sudoers.d/env_keep )

ln -sf /etc/systemd/system/server-init.servie ${MNTDIR}/etc/systemd/system/multi-user.target.wants/server-init.service

mkdir -p ${MNTDIR}/boot/syslinux
cat << EOF > ${MNTDIR}/boot/syslinux/syslinux.cfg
PROMPT 0
TIMEOUT 0
DEFAULT debian

LABEL debian
        LINUX /vmlinuz
        INITRD /initrd.img
        APPEND root=LABEL=debian-root console=ttyS0 quiet cgroup_enable=memory swapaccount=1
EOF

cat << EOF > ${MNTDIR}/etc/hostname
localhost
EOF

cat << EOF > ${MNTDIR}/etc/hosts
127.0.0.1 localhost
EOF

curl -sSkL -o /tmp/cephadm https://github.com/ceph/ceph/raw/master/src/cephadm/cephadm
cp /tmp/cephadm ${MNTDIR}/root/

chroot ${MNTDIR} /bin/bash -c "
export PATH=/bin:/sbin:/usr/bin:/usr/sbin PYTHONDONTWRITEBYTECODE=1 DEBIAN_FRONTEND=noninteractive
sed -i 's/root:\*:/root::/' /etc/shadow
rm -f /var/lib/dpkg/info/libc-bin.postinst /var/lib/dpkg/info/man-db.postinst /var/lib/dpkg/info/dbus.postinst /var/lib/dpkg/info/initramfs-tools.postinst

systemctl disable e2scrub_all.timer \
apt-daily-upgrade.timer \
apt-daily.timer \
logrotate.timer \
man-db.timer \
fstrim.timer \
cron.service \
e2scrub_all.service \
e2scrub_reap.service \
logrotate.service

apt update
apt install -y -o APT::Install-Recommends=0 -o APT::Install-Suggests=0 debianutils python3 lvm2 apparmor dbus iptables
apt install -y -o APT::Install-Recommends=0 -o APT::Install-Suggests=0 linux-image-cloud-amd64 extlinux initramfs-tools
dd if=/usr/lib/EXTLINUX/mbr.bin of=$loopx
extlinux -i /boot/syslinux

sed -i '/src/d' /etc/apt/sources.list
rm -rf /tmp/* /var/tmp/* /var/log/* /var/cache/apt/* /var/lib/apt/lists/*
rm -rf /etc/hostname /etc/resolv.conf /etc/networks /usr/share/doc /usr/share/man /var/lib/*/*.sqlite /var/lib/openvswitch/conf.db
rm -rf /usr/bin/systemd-analyze /usr/bin/perl*.* /usr/bin/sqlite3 /usr/share/misc/pci.ids /usr/share/mysql /usr/share/ieee-data /usr/share/sphinx /usr/share/python-wheels /usr/share/fonts/truetype /usr/lib/udev/hwdb.d /usr/lib/udev/hwdb.bin
find /usr -type d -name __pycache__ -prune -exec rm -rf {} +
find /usr -type d -name tests -prune -exec rm -rf {} +
find /usr/*/locale -mindepth 1 -maxdepth 1 ! -name 'en' -prune -exec rm -rf {} +
find /usr/share/zoneinfo -mindepth 1 -maxdepth 2 ! -name 'UTC' -a ! -name 'UCT' -a ! -name 'Etc' -a ! -name '*UTC' -a ! -name '*UCT' -a ! -name 'PRC' -a ! -name 'Asia' -a ! -name '*Shanghai' -prune -exec rm -rf {} +
"

sync ${MNTDIR}
sleep 1
sync ${MNTDIR}
sleep 1
sync ${MNTDIR}
sleep 1
umount ${MNTDIR}/dev
sleep 1
umount ${MNTDIR}/proc
sleep 1
umount ${MNTDIR}/sys
sleep 1
killall -r provjobd || true
sleep 1
umount ${MNTDIR}
sleep 1
losetup -d $loopx

sleep 2

qemu-img convert -c -f raw -O qcow2 /tmp/debian.raw /tmp/ceph.img

exit 0
