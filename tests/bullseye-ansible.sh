#!/usr/bin/env bash
# For copyright and license terms, see LICENSE.txt (top level of repository)
# Repository: https://github.com/timegrid/debian-image-builder
#
#% Usage: ./test_ansible.sh [OPTIONS]
#%
#%   Tests ansible provisioning for libvirt VMs.

set -eu

# Project
scriptDir="$(dirname "$(readlink -vf "$0")")"
source "$scriptDir/.project.sh" \
       --root \
       -- "$@"
projectDir="$projectDir"

# Configuration
domain=bullseye-ansible.test
suite=bullseye
ip="192.168.100.111/24"


#------------------------------------------------------------------------------
#%% Build the libvirt domain and provision it with ansible
#------------------------------------------------------------------------------

"$projectDir/build.sh" --suite "$suite" "$domain" "$ip"


#------------------------------------------------------------------------------
#%% Connect to the libvirt domain via ssh (admin user)
#------------------------------------------------------------------------------

title "Connect to the libvirt domain via ssh (admin user)"
ssh "admin@$domain"


#------------------------------------------------------------------------------
#%% Shutdown the libvirt domain
#------------------------------------------------------------------------------

title "Shutdown the libvirt domain"
if ! virsh dominfo "$domain" | grep -q "^State:.*running"; then
    info "not running, skipping destruction"
else
    virsh shutdown "$domain"
fi
success
