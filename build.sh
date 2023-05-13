#!/usr/bin/env bash
# For copyright and license terms, see LICENSE.txt (top level of repository)
# Repository: https://github.com/timegrid/debian-image-builder
#
#% Usage: ./build.sh [OPTIONS] domain ip
#%
#%   Builds a debian libvirt domain and provisions it with ansible.
#%
#% Arguments:
#%   domain:            name of the domain
#%   ip:                ip of the domain
#%
#% Options:
#%   -s, --suite=SUITE  codename of debian version (default: 'bookworm')

set -eu

# Project
scriptDir="$(dirname "$(readlink -vf "$0")")"
source "$scriptDir/.project.sh" \
       --short "s:" \
       --long  "suite:" \
       --root \
       -- "$@"
aptcacherngDir="$aptcacherngDir"
libvirtDir="$libvirtDir"
ansibleDir="$ansibleDir"

# Options
suite="bookworm"
while true; do
    case "$1" in
       -s | --suite) suite="$2" ; shift 2 ;;

       --) shift; break ;;
       *)  usage "ERROR: unknown flag '$1'." 1 ;;
    esac
done

# Arguments
domain="${1:-}"; shift || usage "missing argument: domain" 1
ip="${1:-}"; shift || usage "missing argument: ip" 1

# Configuration
network="debian"
sshdKeys="$libvirtDir/ssh"
pool="develop"

# Interface
ipRange="${ip%.*}"
gateway="${ip%.*}.1"
interface="static"

# Ansible
export ANSIBLE_CONFIG="$ansibleDir/ansible.cfg"


#------------------------------------------------------------------------------
#%% Build the libvirt domain
#------------------------------------------------------------------------------

if ! virsh dominfo "$domain" &> /dev/null; then
    buildArgs=(
        --network-name     "$network"
        --network-ip-range "$ipRange"
        --pool-name        "$pool"
        --domain-name      "$domain"
        --domain-sshd-keys "$sshdKeys"
        --domain-interface "$interface"
        --domain-ip        "$ip"
        --domain-gateway   "$gateway"
    )
    "$libvirtDir/build.sh" "${buildArgs[@]}" "$suite"
fi


#------------------------------------------------------------------------------
#%% Start libvirt network
#------------------------------------------------------------------------------

title "Start libvirt network"
info "name" "$network"
netInfo="$(virsh net-info "$network" 2> /dev/null)"
if grep -q "^Active:.*yes" <<< "$netInfo"; then
    info "network already started"
else
    virsh net-start "$network"
fi
success


#------------------------------------------------------------------------------
#%% Start the libvirt domain
#------------------------------------------------------------------------------

title "Start the libvirt domain"
domInfo="$(virsh dominfo "$domain" 2> /dev/null)"
if grep -q "^State:.*running" <<< "$domInfo"; then
    info "domain already running, skipping start."
else
    virsh start "$domain"
fi
success


#------------------------------------------------------------------------------
#%% Wait for ssh connectivity
#------------------------------------------------------------------------------

title "Wait for ssh connectivity"
echo -n "  ..."
while ! ssh -q -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 $ip 'exit 0'; do
    echo -n "."
    sleep 1
done;
echo
success


#------------------------------------------------------------------------------
#%% Run an apt-cacher-ng docker service
#------------------------------------------------------------------------------

$aptcacherngDir/start.sh
trap "$aptcacherngDir/stop.sh" EXIT


#------------------------------------------------------------------------------
#%% Run ansible
#------------------------------------------------------------------------------

ansibleArgs=(
    --verbose
    --timeout 100
    --inventory "$domain",
    --user root
    --tags setup
)

title "Run ansible"
ansible-playbook "${ansibleArgs[@]}" "$ansibleDir/debian.yml"
success
