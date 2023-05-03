#!/usr/bin/env bash
# For copyright and license terms, see LICENSE.txt (top level of repository)
# Repository: https://github.com/timegrid/debian-image-builder
#
#% Usage: ./clean
#%
#%   Cleans all libvirt artifacts for a complete rebuild
#%
#% Options:
#%   -h, --help              display this help
#%       --colorless         omit colors

set -eu

# Project
scriptDir="$(dirname "$(readlink -vf "$0")")"
source "$scriptDir/.project.sh" \
       --root --confirm -- "$@"
libvirtDir="$libvirtDir"

# Configuration
network="debian"
pools=(
    debian
    develop
)
domains=(
    bullseye-ansible.test
    bullseye-libvirt.test
    bookworm-ansible.test
    bookworm-libvirt.test
)

# Paths
imageDir="$libvirtDir/image"
poolDir="$libvirtDir/pool"
xmlDir="$libvirtDir/xml"


#------------------------------------------------------------------------------
#%% Destroy/Undefine libvirt domains
#------------------------------------------------------------------------------

title "Destroy/Undefine libvirt domains"
for domain in ${domains[*]}; do
    domInfo="$(virsh dominfo "$domain" 2> /dev/null)" || true
    if grep -q "^State:.*running" <<< "$domInfo"; then
        virsh destroy "$domain" > /dev/null
    fi
    if virsh dominfo "$domain" &> /dev/null; then
        virsh undefine "$domain" > /dev/null
    fi
done
success


#------------------------------------------------------------------------------
#%% Delete disk images
#------------------------------------------------------------------------------

title "Delete disk images"
rm -rf "$imageDir"
success


#------------------------------------------------------------------------------
#%% Destroy/Delete/Undefine libvirt pools
#------------------------------------------------------------------------------

title "Destroy/Delete/Undefine libvirt pools"
for pool in ${pools[*]}; do
    poolInfo="$(virsh pool-info "$pool" 2> /dev/null)" || true
    if grep -q "^State:.*running" <<< "$poolInfo"; then
        virsh pool-destroy "$pool" > /dev/null
    fi
    if virsh pool-info "$pool" &> /dev/null; then
        virsh pool-undefine "$pool" > /dev/null
    fi
done
rm -rf "$poolDir"
success


#------------------------------------------------------------------------------
#%% Destroy/Undefine libvirt network
#------------------------------------------------------------------------------

title "Destroy/Undefine libvirt network"
netInfo="$(virsh net-info "$network" 2> /dev/null)" || true
if grep -q "^Active:.*yes" <<< "$netInfo"; then
    virsh net-destroy "$network" > /dev/null
    virsh net-undefine "$network" > /dev/null
fi
success


#------------------------------------------------------------------------------
#%% Remove libvirt xml folder
#------------------------------------------------------------------------------

title "Remove libvirt xml folder"
if [ -d "$xmlDir" ]; then
    find "$xmlDir" -maxdepth 1 -type f -name "*.xml" -delete
    rmdir "$xmlDir"
fi
success
