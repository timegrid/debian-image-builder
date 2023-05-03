#!/usr/bin/env bash
# For copyright and license terms, see LICENSE.txt (top level of repository)
# Repository: https://github.com/timegrid/debian-image-builder
#
#% Usage: ./test_libvirt.sh [OPTIONS]
#%
#%   Tests image build for libvirt, builds and runs a libvirt domain.
#%
#% Options:
#%   --dhcp  use dhcp instead of static ip

set -eu

# Project
scriptDir="$(dirname "$(readlink -vf "$0")")"
source "$scriptDir/.project.sh" \
       --root \
       --long "dhcp" \
       -- "$@"
libvirtDir="$libvirtDir"

# Options
dhcp=false
while true; do
    case "$1" in
       --dhcp) dhcp=true ; shift ;;

       --) shift; break ;;
       *)  usage "ERROR: unknown flag '$1'." 1 ;;
    esac
done

# Configuration
suite="bookworm"
network="debian"
domain="bookworm-libvirt.test"
sshdKeys="$libvirtDir/ssh"
ip="192.168.100.102"

# Interface
ipRange="${ip%.*}"
gateway="${ip%.*}.1"
if $dhcp; then
    interface="$libvirtDir/interface/dhcp"
else
    interface="$libvirtDir/interface/static"
fi


#------------------------------------------------------------------------------
#%% Build the libvirt domain
#------------------------------------------------------------------------------

if ! virsh dominfo "$domain" &> /dev/null; then
    buildArgs=(
        --network-ip-range "$ipRange"
        --domain-name "$domain"
        --domain-sshd-keys "$sshdKeys"
        --domain-interface "$interface"
    )
    if ! $dhcp; then
        buildArgs+=(
            --domain-ip      "$ip"
            --domain-gateway "$gateway"
        )
    fi
    "$libvirtDir/build.sh" "${buildArgs[@]}" "$suite"
fi


#------------------------------------------------------------------------------
#%% Start libvirt network
#------------------------------------------------------------------------------

title "Start libvirt network"
info "name" "$network"
if virsh net-info "$network" 2> /dev/null | grep -q "^Active:.*yes"; then
    info "network already started"
else
    virsh net-start "$network"
fi
success


#------------------------------------------------------------------------------
#%% Start the libvirt domain
#------------------------------------------------------------------------------

title "Start the libvirt domain"
if virsh dominfo "$domain" | grep -q "^State:.*running"; then
    info "domain already running, skipping start."
else
    virsh start "$domain"
fi
success


#------------------------------------------------------------------------------
#%% Wait for the libvirt domain to boot
#------------------------------------------------------------------------------

title "Wait for the libvirt domain to boot"
echo -n "  ..."
while ! virsh dominfo "$domain" | grep -q "^State:.*running"; do
    echo -n "."
    sleep 1
done;
echo
success


#------------------------------------------------------------------------------
#%% Connect to the libvirt domain via serial console
#------------------------------------------------------------------------------

title "Connect to the libvirt domain via serial console"
echo -e "\n> Connecting to VM via serial console ..."
virsh console "$domain"


#------------------------------------------------------------------------------
#%% Connect to the libvirt domain via ssh
#------------------------------------------------------------------------------

title "Connect to the libvirt domain via ssh"
if $dhcp; then
    ip="$(virsh net-dhcp-leases "$network" | grep -oP "(\d{1,3}\.){3}\d{1,3}(?=.*$domain)")"
fi
ssh "root@${ip%/*}"


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
