#!/bin/bash
set -ex

export XZ_DEFAULTS="-9 -T 0"

apt update
DEBIAN_FRONTEND=noninteractive apt -y install ansible

pip install kolla-ansible docker

DDATE=$(date +%Y%m%d%H%M%S)
LATEST_RELEASE=$(curl -sSkL http://www.openstack.com |  grep -oP 'LATEST RELEASE: \K(.*)(?=<)')
LATEST_RELEASE=${LATEST_RELEASE,,}

cp -r /usr/local/share/kolla-ansible/etc_examples/kolla /etc

#DISTRO=$(awk -F'"' '/kolla_base_distro/ {print $2}' /etc/kolla/globals.yml)
#TYPE=$(awk -F'"' '/kolla_install_type/ {print $2}' /etc/kolla/globals.yml)

for d in ubuntu
do
	for t in source binary
	do
		cat etc_kolla_globals.yml | sed -e "s/DISTRO/$d/" -e "s/TYPE/$t/" -e "s/LATEST_RELEASE/${LATEST_RELEASE}/" -e '/openstack_core/,$d' | tee /etc/kolla/globals.yml
		kolla-ansible pull
		sleep 1
	done
done

docker image list "kolla/*"

sleep 1

for d in ubuntu
do
	for t in source binary
	do
		docker save $(docker image list "kolla/$d-$t-*" | awk 'NR>1 {print $1 ":" $2 }') | xz > /tmp/dockerhub-kolla-core-$d-$t-images-${LATEST_RELEASE}-${DDATE}.tar.xz
	done
done

for (( n=1; n<=3; n++)); do
  ver="$(curl -skL https://api.github.com/repos/Mikubill/transfer/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')"
  [ ! "$ver" ] || break
done

curl -skL https://github.com/Mikubill/transfer/releases/download/"$ver"/transfer_"${ver/v/}"_linux_amd64.tar.gz | tar -xz -C /tmp

for f in /tmp/dockerhub-kolla-core-*xz; do
FILENAME=$(basename $f)
SIZE=$(du -h $f | awk '{print $1}')
trans_url=$(/tmp/transfer wet --silent $f)
[[ -z "$trans_url" ]] && exit
data="$FILENAME-$SIZE-${trans_url}"
curl -skLo /dev/null "https://wxpusher.zjiecode.com/api/send/message/?appToken=${WXPUSHER_APPTOKEN}&uid=${WXPUSHER_UID}&content=${data}"
done
