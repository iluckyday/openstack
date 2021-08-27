#!/bin/bash
set -ex

apt update
DEBIAN_FRONTEND=noninteractive apt -y install ansible

pip install kolla-ansible docker

LATEST_RELEASE=$(curl -sSkL http://www.openstack.com |  grep -oP 'LATEST RELEASE: \K(.*)(?=<)')
LATEST_RELEASE=${LATEST_RELEASE,,}

cp -r /usr/local/share/kolla-ansible/etc_examples/kolla /etc
cat etc_kolla_globals.yml | sed "s/LATEST_RELEASE/${LATEST_RELEASE}/" | tee /etc/kolla/globals.yml

DISTRO=$(awk -F'"' '/kolla_base_distro/ {print $2}' /etc/kolla/globals.yml)
TYPE=$(awk -F'"' '/kolla_install_type/ {print $2}' /etc/kolla/globals.yml)

kolla-ansible pull

sleep 1

docker image list "kolla/${DISTRO}-${TYPE}-*"
docker save $(docker image list "kolla/${DISTRO}-${TYPE}-*" -q) | xz > /tmp/kolla-${DISTRO}-${TYPE}-images-${LATEST_RELEASE}.tar.xz

echo kolla-${DISTRO}-${TYPE}-images-${LATEST_RELEASE} is:
ls -lh /tmp/kolla-${DISTRO}-${TYPE}-images-${LATEST_RELEASE}.tar.xz

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
