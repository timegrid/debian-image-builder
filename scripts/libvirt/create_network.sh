#!/usr/bin/env bash
# For copyright and license terms, see LICENSE.txt (top level of repository)
# Repository: https://github.com/timegrid/debian-image-builder
#
#% Usage: ./create_network.sh [OPTIONS] name
#%
#%   Creates a NAT network like the libvirt default net.
#%
#% Arguments:
#%   name:               name of the network
#%
#% Options:
#%   -u, --uuid=UUID     uuid of network (default: random)
#%   -m, --mac=MAC       mac of the interface (default: random)
#%   -r, --ip-range=IP   ip range of the network (default: 192.168.100)
#%       --xml-dir=PATH  directory of the xml configuration (default: './xml')
#%
#%   -h, --help          display this help
#%       --colorless     omit colors

set -eu

# Project
scriptDir="$(dirname "$(readlink -vf "$0")")"
source "$scriptDir/.project.sh" \
       --short "u:r:m:" \
       --long  "uuid:,ip-range:,mac:,xml-dir:" \
       --root \
       -- "$@"
projectUser="$projectUser"
projectGroup="$projectGroup"
libvirtDir="$libvirtDir"

# Options
uuid="$(uuidgen)"
mac="$(od -An -N6 -tx1 /dev/urandom \
    | sed -e 's/^  *//' -e 's/  */:/g' -e 's/:$//' -e 's/^\(.\)[13579bdf]/\10/')"
ipRange=192.168.100
xmlDir="$scriptDir/xml"
while true; do
    case "$1" in
       -u | --uuid)     uuid="$2"    ; shift 2 ;;
       -m | --mac)      mac="$2"     ; shift 2 ;;
       -r | --ip-range) ipRange="$2" ; shift 2 ;;
            --xml-dir)  xmlDir="$2"  ; shift 2 ;;

       --) shift; break ;;
       *)  usage "ERROR: unknown flag '$1'." 1 ;;
    esac
done

# Arguments
name="${1:-}"; shift || usage "missing argument: name" 1

# Paths
netXml="$xmlDir/network-$name.xml"
mkdir -p "$xmlDir"
chown "$projectUser:$projectGroup" "$xmlDir"


#------------------------------------------------------------------------------
#%% Generate libvirt network XML
#------------------------------------------------------------------------------

title "Generate libvirt network XML"
info "xml" "$netXml"
info "name" "$name"
info "uuid" "$uuid"
info "bridge" "vibr-$name"
info "mac" "$mac"
info "ip range" "$ipRange.0/24"
if [ -f "$netXml" ]; then
    info "network xml already generated, skipping generation"
else
    cat << EOF > "$netXml"
<network>
  <name>$name</name>
  <uuid>$uuid</uuid>
  <forward mode='nat'/>
  <bridge name='virbr-$name' stp='on' delay='0'/>
  <mac address='$mac'/>
  <ip address='$ipRange.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='$ipRange.2' end='$ipRange.254'/>
    </dhcp>
  </ip>
</network>
EOF
fi
chown "$projectUser:$projectGroup" "$netXml"
success


#------------------------------------------------------------------------------
#%% Define libvirt network
#------------------------------------------------------------------------------

title "Define libvirt network"
info "name" "$name"
info "xml" "$netXml"
if virsh net-info "$name" &> /dev/null; then
    info "network already defined, skipping definition"
else
    virsh net-define "$netXml"
fi
success


#------------------------------------------------------------------------------
#%% Start libvirt network
#------------------------------------------------------------------------------

title "Start libvirt network"
info "name" "$name"
netInfo="$(virsh net-info "$name" 2> /dev/null)"
if grep -q "^Active:.*yes" <<< "$netInfo"; then
    info "network already started"
else
    virsh net-start "$name"
fi
success
