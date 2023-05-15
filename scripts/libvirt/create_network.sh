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
#%   -n, --ip4-net=IP    ip4 network (default: '192.168.100.0/24')
#%   -N, --ip6-net=IP    ip6 network (default: 'fd00:d1b::/64')
#%       --xml-dir=PATH  directory of the xml configuration (default: './xml')
#%
#%   -h, --help          display this help
#%       --colorless     omit colors

set -eu

# Project
scriptDir="$(dirname "$(readlink -vf "$0")")"
source "$scriptDir/.project.sh" \
       --short "u:m:n:N:" \
       --long  "uuid:,mac:,ip4-net:,ip6-net:,xml-dir:" \
       --root \
       -- "$@"
projectUser="$projectUser"
projectGroup="$projectGroup"
libvirtDir="$libvirtDir"

# Options
uuid="$(uuidgen)"
mac="$(od -An -N6 -tx1 /dev/urandom \
    | sed -e 's/^  *//' -e 's/  */:/g' -e 's/:$//' -e 's/^\(.\)[13579bdf]/\10/')"
ip4Net="192.168.100.0/24"
ip6Net="fd00:d1b::/64"
xmlDir="$scriptDir/xml"
while true; do
    case "$1" in
       -u | --uuid)    uuid="$2"   ; shift 2 ;;
       -m | --mac)     mac="$2"    ; shift 2 ;;
       -n | --ip4-net) ip4Net="$2" ; shift 2 ;;
       -N | --ip6-net) ip6Net="$2" ; shift 2 ;;
            --xml-dir) xmlDir="$2" ; shift 2 ;;

       --) shift; break ;;
       *)  usage "ERROR: unknown flag '$1'." 1 ;;
    esac
done

# Arguments
name="${1:-}"; shift || usage "missing argument: name" 1

# IPs
ip4=""
if [ "$ip4Net" ]; then
    ip4Info="$(sipcalc "$ip4Net")"
    ip4Prefix="$(grep "Network mask (bits)\s*-" <<< "$ip4Info" | grep -Po "(?<=- ).*")"
    ip4Range="$(grep "Usable range\s*-" <<< "$ip4Info" | grep -Po "(?<=- ).*")"
    ip4Gateway="${ip4Range% -*}"
    ip4Start="${ip4Gateway%.*}.$(( ${ip4Gateway##*.} + 1 ))"
    ip4End="${ip4Range#*- }"
    ip4="<ip family='ipv4' address='$ip4Gateway' prefix='$ip4Prefix'>
    <dhcp>
      <range start='$ip4Start' end='$ip4End'/>
    </dhcp>
  </ip>"
fi
ip6=""
if [ "$ip6Net" ]; then
    ip6Info="$(sipcalc "$ip6Net")"
    ip6Prefix="$(grep "Prefix length\s*-" <<< "$ip6Info" | grep -Po "(?<=- ).*")"
    ip6First="$(grep -A1 "Network range\s*-" <<< "$ip6Info" | head -n1 | grep -Po "(?<=- )[\w:]*")"
    ip6First="${ip6First%:*}"
    ip6Gateway="$ip6First:0001"
    ip6Start="$ip6First:0002"
    ip6End="$ip6First:ffff"
    ip6="<ip family='ipv6' address='$ip6Gateway' prefix='$ip6Prefix'>
    <dhcp>
      <range start='$ip6Start' end='$ip6End' />
    </dhcp>
  </ip>"
fi

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
info "ip4 net" "$ip4Net"
info "ip6 net" "$ip6Net"
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
  $ip4
  $ip6
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
