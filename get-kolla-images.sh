#!/bin/bash
set -ex

apt update
DEBIAN_FRONTEND=noninteractive apt -y install ansible

pip install kolla-ansible docker

LATEST_RELEASE=$(curl -sSkL http://www.openstack.com |  grep -oP 'LATEST RELEASE: \K(.*)(?=<)')
LATEST_RELEASE=${LATEST_RELEASE,,}

mkdir /etc/kolla
cat << EOF > /etc/kolla/globals.yml
kolla_base_distro: "ubuntu"
kolla_install_type: "binary"
openstack_release: "${LATEST_RELEASE}"
network_interface: "eth0"
kolla_internal_vip_address: "10.0.2.10"
neutron_plugin_agent: "openvswitch"
neutron_ipam_driver: "internal"
keystone_admin_user: "admin"
keystone_admin_project: "admin"
glance_enable_rolling_upgrade: "no"
nova_compute_virt_type: "kvm"
EOF

docker save $(docker image list "kolla/ubuntu-binary-*" -q) | xz > /tmp/kolla-ubuntu-binary-images-${LATEST_RELEASE}.tar.xz

echo kolla-ubuntu-binary-images-${LATEST_RELEASE} is:
ls -lh /tmp/kolla-ubuntu-binary-images-${LATEST_RELEASE}.tar.xz

exit

for f in /tmp/kolla-*xz; do
FILENAME=$(basename $f)
SIZE=$(du -h $f | awk '{print $1}')
trans_url=$(/tmp/transfer wet --silent $f)
[[ -z "$trans_url" ]] && exit
data="$FILENAME-$SIZE-${trans_url}"
curl -skLo /dev/null "https://wxpusher.zjiecode.com/api/send/message/?appToken=${WXPUSHER_APPTOKEN}&uid=${WXPUSHER_UID}&content=${data}"
done
