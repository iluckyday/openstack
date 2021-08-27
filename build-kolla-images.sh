#!/bin/bash
set -ex

pip install kolla

LATEST_RELEASE=$(curl -sSkL http://www.openstack.com |  grep -oP 'LATEST RELEASE: \K(.*)(?=<)')
LATEST_RELEASE=${LATEST_RELEASE,,}

DISTRO=ubuntu
TYPE=source

kolla-build -b ${DISTRO} -t ${TYPE} --tag ${LATEST_RELEASE} --use-dumb-init --summary --nokeep --openstack-branch ${LATEST_RELEASE} --openstack-release ${LATEST_RELEASE} barbican cinder designate glance haproxy heat horizon ironic iscsid keepalived keystone kolla-toolbox manila mariadb masakari memcached mistral multipathd neutron nova octavia openvswitch placement prometheus qdrouterd redis sahara senlin swift tacker tgtd vitrage zookeeper

sleep 1

#docker image list "kolla/${DISTRO}-${TYPE}-*"
#docker image rm $(docker image list "kolla/${DISTRO}-${TYPE}-*base" -q)
docker image list "kolla/${DISTRO}-${TYPE}-*"
DDATE=$(date +%Y%m%d%H%M%S)
docker save $(docker image list "kolla/${DISTRO}-${TYPE}-*" -q) | xz > /tmp/kolla-${DISTRO}-${TYPE}-images-${LATEST_RELEASE}-${DDATE}.tar.xz

echo kolla-${DISTRO}-${TYPE}-images-${LATEST_RELEASE} is:
ls -lh /tmp/kolla-${DISTRO}-${TYPE}-images-${LATEST_RELEASE}-${DDATE}.tar.xz

for (( n=1; n<=3; n++)); do
  ver="$(curl -skL https://api.github.com/repos/Mikubill/transfer/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')"
  [ ! "$ver" ] || break
done

curl -skL https://github.com/Mikubill/transfer/releases/download/"$ver"/transfer_"${ver/v/}"_linux_amd64.tar.gz | tar -xz -C /tmp

for f in /tmp/kolla-*xz; do
FILENAME=$(basename $f)
SIZE=$(du -h $f | awk '{print $1}')
trans_url=$(/tmp/transfer wet --silent $f)
[[ -z "$trans_url" ]] && exit
data="$FILENAME-$SIZE-${trans_url}"
curl -skLo /dev/null "https://wxpusher.zjiecode.com/api/send/message/?appToken=${WXPUSHER_APPTOKEN}&uid=${WXPUSHER_UID}&content=${data}"
done
