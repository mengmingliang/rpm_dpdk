#!/bin/bash

# Copyright (c) 2016 Open Platform for NFV Project, Inc. and its contributors
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

set -e

echo "==============================="
echo executing $0 $@
echo executing on machine `uname -a`

usage() {
    echo "$0 -g < [master] | [tag] | [commit] > -h -k -p < URL > -u < URL > -v

    -g <DPDK TAG>   -- DPDK release tag commit to build. The default is
                       master.
    -k              -- Build igb_uio kernel module
    -h              -- print this message
    -p <patch url>  -- Specify url to patches if required for ovs rpm.
    -v              -- Set verbose mode."
}
while getopts "g:hkp:s:u:v" opt; do
    case "$opt" in
        g)
            DPDK_VERSION=${OPTARG}
            ;;
        k)
            KMOD="yes"
            ;;
        h|\?)
            usage
            exit 1
            ;;
        p)
            DPDK_PATCH=${OPTARG}
            ;;
        s)
            SRC=${OPTARG}
            ;;
        u)
            DPDK_REPO_URL=${OPTARG}
            ;;
        v)
            verbose="yes"
            ;;
    esac
done

if [ -z $DPDK_REPO_URL ]; then
    DPDK_REPO_URL=http://dpdk.org/git/dpdk
fi
if [ -z $DPDK_VERSION ]; then
    DPDK_VERSION=master
fi

HOME=`pwd`
TOPDIR=$HOME
TMPDIR=$TOPDIR/rpms

function install_pre_reqs() {
    echo "----------------------------------------"
    echo Install dependencies for dpdk.
    echo
    sudo yum -y install gcc make python-devel openssl-devel kernel-devel graphviz \
                kernel-debug-devel autoconf automake rpm-build redhat-rpm-config \
                libtool python-twisted-core desktop-file-utils groff PyQt4          \
                libpcap-devel python-sphinx numactl-devel libvirt-devel
}

mkdir -p $TMPDIR

install_pre_reqs

RPMDIR=$HOME/rpmbuild
if [ -d $RPMDIR ]; then
    rm -rf $RPMDIR
fi
mkdir -p $RPMDIR/RPMS
mkdir -p $RPMDIR/SOURCES
mkdir -p $RPMDIR/SPECS
mkdir -p $RPMDIR/SRPMS


cd $TMPDIR
if [ -d dpdk ]; then
    set +e
    rm -rf dpdk
    set -e
fi
git clone $DPDK_REPO_URL
cd dpdk

if [[ "$DPDK_VERSION" =~ "master" ]]; then
    git checkout master
    snapgit=`git log --pretty=oneline -n1|cut -c1-8`
else
    git checkout v$DPDK_VERSION
fi

if [[ "$DPDK_VERSION" =~ "rc" ]]; then
    DPDK_VERSION=`echo $DPDK_VERSION | sed -e 's/-/_/'`
fi

snapser=`git log --pretty=oneline | wc -l`

makever=`make showversion`
basever=`echo ${makever} | cut -d- -f1`
rc=`echo ${makever} | cut -d- -f2 -s`
snapver=${snapser}.git${snapgit}


if [[ "$DPDK_VERSION" =~ "master" ]]; then
    prefix=dpdk-${basever}.${snapser}.git${snapgit}
    cp $HOME/dpdk-snap/dpdk.spec $TMPDIR/dpdk/dpdk.spec
elif [ ! -z "$rc" ]; then
    prefix=dpdk-${basever:0:5}_${rc}
    cp $HOME/dpdk-snap/dpdk.spec $TMPDIR/dpdk/dpdk.spec
else
    prefix=dpdk-${basever:0:5}
    if [[ "$DPDK_VERSION" =~ "18" ]]; then
        cp $HOME/dpdk-snap/dpdk.1802.spec $TMPDIR/dpdk/dpdk.spec
    else #1711
        cp $HOME/dpdk-snap/dpdk.spec $TMPDIR/dpdk/dpdk.spec
    fi
fi
cp $TMPDIR/dpdk/dpdk.spec $RPMDIR/SOURCES
cp $TMPDIR/dpdk/dpdk.spec $RPMDIR/SPECS


if [[ ! "${SRC}dummy" == "dummy" ]]; then
    echo "---------------------------------------"
    echo "Build SRPM"
    echo
#   Workaround for some versions of centos dist macro is defined as .el7.centos
#   breaking downstream builds when built from src rpm
    BUILD_OPT=(-bs --define "dist .el7")
    if [[ "$DPDK_VERSION" =~ "master" ]]; then
        sed -i "/%define ver.*/c\\
                %define ver ${basever}\\
                %define _snapver ${snapver}" $TMPDIR/dpdk/dpdk.spec
    else
        sed -i "s/%define ver.*/%define ver ${DPDK_VERSION}/" $TMPDIR/dpdk/dpdk.spec
    fi
else
    BUILD_OPT=(-bb)
fi

archive=${prefix}.tar.gz

echo "-------------------------------"
echo "Creating archive: ${archive}"
echo
git archive --prefix=${prefix}/ HEAD  | gzip -9 > ${archive}
cp ${archive} $RPMDIR/SOURCES/
echo "-------------------------------"
echo building RPM for DPDK version $DPDK_VERSION
echo
echo DPDK_VERSION is $DPDK_VERSION

if [[ "$DPDK_VERSION" =~ "master" ]]; then
    rpmbuild "${BUILD_OPT[@]}" --define "_topdir $RPMDIR" --define "_snapver $snapver" --define "_ver $basever" dpdk.spec
else
    rpmbuild "${BUILD_OPT[@]}" --define "_topdir $RPMDIR" --define "_ver $DPDK_VERSION" dpdk.spec
fi
#
# Copy all RPMs to build directory
#
echo Copy all RPMs to build directory
cd $RPMDIR
RPMS=$(find . -type f -name '*.rpm')
SRCRPMS=$(find . -type f -name '*.src.rpm')

for i in $RPMS $SRCRPMS
do
    cp $i $HOME
done

exit 0
