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



CLEAN=yes


echo =============================17.11================================
echo "Build DPDK RPM for 17.11 release"

./build_dpdk_rpm.sh -g 17.11

echo "Build DPDK SRPM for 17.11 release"

./build_dpdk_rpm.sh -g 17.11 -s yes

echo =============================18.02================================
echo "Build DPDK RPM for 18.02 release"

./build_dpdk_rpm.sh -g 18.02

echo "Build DPDK SRPM for 18.02 release"

./build_dpdk_rpm.sh -g 18.02 -s yes

echo =============================18.05================================
echo "Build DPDK RPM for 18.05 release"

./build_dpdk_rpm.sh -g 18.05

echo "Build DPDK SRPM for 18.05 release"

./build_dpdk_rpm.sh -g 18.05 -s yes


if [[ -z "${CLEAN##*y*}" ]]; then
    echo =============================Clean up temporary directories================================
    ./clean.sh
fi


exit 0
