#!/bin/bash
set -e

# The base image `murilomarinho/sas:jazzy` already provides Ubuntu 24.04, ROS 2
# Jazzy, the `sas` LGPL packages and `dqrobotics`. Here we add the `sas`
# CC BY-NC 4.0 (noncommercial) packages on top of it.

# Install the `sas` CC BY-NC 4.0 packages as instructed in
# https://smartarmstack.github.io/ (section "CC BY-NC 4.0 Packages")
curl -s --compressed "https://marinholab.github.io/sas_debian_builder_noncommercial/KEY.gpg" \
| gpg --dearmor \
| tee /etc/apt/trusted.gpg.d/smartarmstack_cc_by_nc.gpg >/dev/null

curl -s --compressed -o /etc/apt/sources.list.d/smartarmstack_cc_by_nc.list \
"https://marinholab.github.io/sas_debian_builder_noncommercial/smartarmstack_cc_by_nc.list"

apt-get update
apt-get install -y ros-jazzy-sas-operator-side-receiver \
    ros-jazzy-sas-patient-side-manager \
    ros-jazzy-sas-robot-kinematics-constrained-multiarm

apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*
