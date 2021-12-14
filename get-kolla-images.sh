#!/bin/bash
set -ex

export XZ_DEFAULTS="-9 -T 0"

apt update
#DEBIAN_FRONTEND=noninteractive apt -y install ansible
DEBIAN_FRONTEND=noninteractive apt -y install python3-pip python3-dev libffi-dev gcc libssl-dev

pip install -U pip

pip install 'ansible<3.0'

pip install kolla-ansible docker

LATEST_RELEASE=$(curl -sSkL http://www.openstack.com |  grep -oP 'LATEST RELEASE: \K(.*)(?=<)')
LATEST_RELEASE=${LATEST_RELEASE,,}

cp -r /usr/local/share/kolla-ansible/etc_examples/kolla /etc
cp /usr/local/share/kolla-ansible/ansible/inventory/* .

DISTRO=ubuntu
TYPE=source

cat etc_kolla_globals.yml | sed -e "s/DISTRO/$DISTRO/" -e "s/TYPE/$TYPE/" -e "s/LATEST_RELEASE/${LATEST_RELEASE}/" | tee /etc/kolla/globals.yml

#DISTRO=$(awk -F'"' '/kolla_base_distro/ {print $2}' /etc/kolla/globals.yml)
#TYPE=$(awk -F'"' '/kolla_install_type/ {print $2}' /etc/kolla/globals.yml)

kolla-ansible -i all-in-one pull -vvvv

sleep 1

docker image list

DDATE=$(date +%Y%m%d%H%M%S)
imagetags=$(docker image list "quay.io/openstack.kolla/${DISTRO}-${TYPE}-*" | awk 'NR>1 {print $1 ":" $2 }')
docker save $imagetags | xz > /tmp/quay.io-openstack.kolla-${DISTRO}-${TYPE}-images-${LATEST_RELEASE}-${DDATE}.tar.xz

KTMPD=$(mktemp -d)
for it in $imagetags; do
  docker save -o $KTMPD/"$it".tar "$it"
done

cd $KTMPD
tar -Jcf /tmp/quay.io-openstack.kolla-${DISTRO}-${TYPE}-single-images-${LATEST_RELEASE}-${DDATE}.tar.xz *

cd ~

for (( n=1; n<=3; n++)); do
  ver="$(curl -skL https://api.github.com/repos/Mikubill/transfer/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')"
  [ ! "$ver" ] || break
done

curl -skL https://github.com/Mikubill/transfer/releases/download/"$ver"/transfer_"${ver/v/}"_linux_amd64.tar.gz | tar -xz -C /tmp

for f in /tmp/*kolla-*.tar.xz; do
FILENAME=$(basename $f)
SIZE=$(du -h $f | awk '{print $1}')
trans_url=$(/tmp/transfer wet --silent $f)
[[ -z "$trans_url" ]] && exit
data="$FILENAME-$SIZE-${trans_url}"
curl -skLo /dev/null "https://wxpusher.zjiecode.com/api/send/message/?appToken=${WXPUSHER_APPTOKEN}&uid=${WXPUSHER_UID}&content=${data}"
done
