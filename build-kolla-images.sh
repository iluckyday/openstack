#!/bin/bash
set -ex

pip install kolla

python3 -c "import pprint;from kolla.image.build import UNBUILDABLE_IMAGES;print(':::::UNBUILDABLE_IMAGES:::::');pprint.pprint(UNBUILDABLE_IMAGES)"

sleep 1

LATEST_RELEASE=$(curl -sSkL http://www.openstack.com |  grep -oP 'LATEST RELEASE: \K(.*)(?=<)')
LATEST_RELEASE=${LATEST_RELEASE,,}

DISTRO=ubuntu
TYPE=source

kolla-build --skip-parents --skip-existing --summary --nokeep -b ${DISTRO} -t ${TYPE} --tag ${LATEST_RELEASE} --openstack-branch ${LATEST_RELEASE} --openstack-release ${LATEST_RELEASE} barbican cinder designate glance haproxy heat horizon ironic iscsid keepalived keystone kolla-toolbox manila mariadb masakari memcached mistral multipathd neutron nova octavia openvswitch placement prometheus redis sahara senlin swift tacker tgtd vitrage zookeeper

sleep 1

#docker image list "kolla/${DISTRO}-${TYPE}-*"
#docker image rm $(docker image list "kolla/${DISTRO}-${TYPE}-*base" -q)
docker image list "kolla/${DISTRO}-${TYPE}-*"
DDATE=$(date +%Y%m%d%H%M%S)
docker save $(docker image list "kolla/${DISTRO}-${TYPE}-*" -q) | xz > /tmp/kolla-build-${DISTRO}-${TYPE}-images-${LATEST_RELEASE}-${DDATE}.tar.xz

echo kolla-build-${DISTRO}-${TYPE}-images-${LATEST_RELEASE} is:
ls -lh /tmp/kolla-build-${DISTRO}-${TYPE}-images-${LATEST_RELEASE}-${DDATE}.tar.xz

dir=/tmp/kolla-build-Dockerfile
zfile=/tmp/kolla-build-Dockerfile-${DDATE}.tar.xz

rm -rf $dir $zfile

for d in centos ubuntu debian
do
	for t in binary source
	do
		tdir=$dir/$d/$t
		mkdir -p $tdir
		kolla-build -b $d -t $t --template-only --work-dir $tdir
	done
done

find $dir -type d -name "__pycache__" -exec rm -rf {} +
cd $dir && tar -cJf ${zfile} *  && cd -

for (( n=1; n<=3; n++)); do
  ver="$(curl -skL https://api.github.com/repos/Mikubill/transfer/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')"
  [ ! "$ver" ] || break
done
curl -skL https://github.com/Mikubill/transfer/releases/download/"$ver"/transfer_"${ver/v/}"_linux_amd64.tar.gz | tar -xz -C /tmp

for f in /tmp/kolla-build-*xz; do
FILENAME=$(basename $f)
SIZE=$(du -h $f | awk '{print $1}')
trans_url=$(/tmp/transfer wet --silent $f)
[[ -z "$trans_url" ]] && exit
data="$FILENAME-$SIZE-${trans_url}"
curl -skLo /dev/null "https://wxpusher.zjiecode.com/api/send/message/?appToken=${WXPUSHER_APPTOKEN}&uid=${WXPUSHER_UID}&content=${data}"
done
