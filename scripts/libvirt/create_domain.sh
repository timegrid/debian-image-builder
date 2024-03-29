#!/usr/bin/env bash
# For copyright and license terms, see LICENSE.txt (top level of repository)
# Repository: https://github.com/timegrid/debian-image-builder
#
#% Usage: ./create_domain.sh [OPTIONS] name network pool volume
#%
#%   Creates/Prepares a libvirt domain.
#%
#% Arguments:
#%   name:             name of the domain
#%   network:          name of the network
#%   pool:             name of the pool
#%   volume:           name of the volume
#%
#% Options:
#%   -c, --cpus=INT         number of cpus (default: 2)
#%   -m, --memory=INT       amount of memory (default: 4096)
#%   -o, --os-variant=CODE  debian codename (default: autodetected)
#%
#%   -H, --hostname=NAME    hostname (default: domain name)
#%   -p, --password=PWD     root password (default: 'password')
#%   -s, --ssh-key=PATH     path to public root ssh key
#%                            (default: './ssh/libvirtlocal.pub')
#%   -S, --sshd-keys=DIR    directory with ssh host keys (default: autogenerated)
#%   -t, --timezone=ZONE    timezone (default: 'Europe/Berlin')
#%   -k, --keyboard=LAYOUT  keyboard layout (default: 'de')
#%   -f, --interface=PATH   path to / name of interface configuration file
#%                            (default: 'dhcp')
#%   -i, --ip4=IP           ip of the domain (default: EMPTPY -> dhcp)
#%   -g, --ip4-gateway=IP   gateway for the domain (default: EMPTY -> dhcp)
#%   -I, --ip6=IP           ip of the domain (default: EMPTPY -> dhcp)
#%   -G, --ip6-gateway=IP   gateway for the domain (default: EMPTY -> dhcp)
#%
#%   -h, --help             display this help
#%       --colorless        omit colors

set -eu

# Project
scriptDir="$(dirname "$(readlink -vf "$0")")"
long=(
    cpus:
    memory:
    os-variant:
    hostname:
    password:
    ssh-key:
    sshd-keys:
    timezone:
    keyboard:
    interface:
    ip4:
    ip4-gateway:
    ip6:
    ip6-gateway:
)
source "$scriptDir/.project.sh" \
       --short "c:m:o:H:p:s:S:t:k:f:i:g:I:G:" \
       --long "$(printf '%s,' "${long[@]}" | sed 's/,$//')" \
       --root \
       -- "$@"
libvirtDir="$libvirtDir"

# Options
osVariant=
cpus=2
memory=4096

hostname=
password=password
sshKey="$libvirtDir/ssh/libvirtlocal.pub"
sshdKeys=
timezone="Europe/Berlin"
keyboard="de"
interface="$libvirtDir/interface/dhpc"
ip4=
ip4Gateway=
ip6=
ip6Gateway=
while true; do
    case "$1" in
       -c | --cpus)        cpus="$2"       ; shift 2 ;;
       -m | --memory)      memory="$2"     ; shift 2 ;;
       -o | --os-variant)  osVariant="$2"  ; shift 2 ;;

       -H | --hostname)    hostname="$2"   ; shift 2 ;;
       -p | --password)    password="$2"   ; shift 2 ;;
       -s | --ssh-key)     sshKey="$2"     ; shift 2 ;;
       -S | --sshd-keys)   sshdKeys="$2"   ; shift 2 ;;
       -t | --timezone)    timezone="$2"   ; shift 2 ;;
       -k | --keyboard)    keyboard="$2"   ; shift 2 ;;
       -f | --interface)   interface="$2"  ; shift 2 ;;
       -i | --ip4)         ip4="$2"        ; shift 2 ;;
       -g | --ip4-gateway) ip4Gateway="$2" ; shift 2 ;;
       -I | --ip6)         ip6="$2"        ; shift 2 ;;
       -G | --ip6-gateway) ip6Gateway="$2" ; shift 2 ;;

       --) shift; break ;;
       *)  usage "ERROR: unknown flag '$1'." 1 ;;
    esac
done

# Arguments
name="${1:-}"; shift || usage "missing argument: name" 1
network="${1:-}"; shift || usage "missing argument: network" 1
pool="${1:-}"; shift || usage "missing argument: pool" 1
volume="${1:-}"; shift || usage "missing argument: volume" 1

# Defaults
hostname="${hostname:-"$name"}"
[ "$ip4" ] && ip4Gateway="${ip4Gateway:-"${ip4%.*}.1"}"
[ "$ip6" ] && ip6Gateway="${ip6Gateway:-"fe80::"}"

# Switches
created=false
virsh dominfo "$name" &> /dev/null && created=true || true


#------------------------------------------------------------------------------
#%% Fetch OS information from disk image
#------------------------------------------------------------------------------

if [ ! "$osVariant" ]; then
    title "Fetch OS information from disk image"
    if $created; then
        info "domain already exists, skipping information gathering"
    else
        info "volume" "$volume"
        volumePath="$(virsh vol-dumpxml $volume --pool $pool \
                      | grep -oP "(?<=<path>).*(?=</path>)")"
        info "volume path" "$volumePath"
        osRelease="$(virt-cat -a $volumePath /etc/os-release)"
        osVariant="debian$(grep -Po "(?<=VERSION_CODENAME=).*" <<< $osRelease)"
        info "os variant" "$osVariant"
    fi
    success
fi


#------------------------------------------------------------------------------
#%% Install libvirt domain
#------------------------------------------------------------------------------

title "Install libvirt domain"
info "name" "$name"
if $created; then
    info "domain already exists, skipping installation"
else
    info "network" "$network"
    info "pool" "$pool"
    info "volume" "$volume"
    info "cpus" "$cpus"
    info "memory" "$memory"
    info "os variant" "$osVariant"
    installArgs=(
        --connect "qemu:///system"
        --virt-type "kvm"
        --os-variant "$osVariant"
        --name "$name"
        --memory "$memory"
        --vcpus "$cpus"
        --disk "vol=$pool/$volume"
        --import
        --network "network=$network"
        --graphics "vnc,listen=127.0.0.1"
        --console "pty,target_type=serial"
        --noautoconsole
        --noreboot
    )
    virt-install "${installArgs[@]}"
fi
success


#------------------------------------------------------------------------------
#%% Prepare libvirt domain
#------------------------------------------------------------------------------

title "Prepare libvirt domain"
info "name" "$name"
if $created; then
    info "domain already exists, skipping preparation"
else
    interfaceName="enp1s0"
    case "$interface" in
        "dhcp")
                        interfaceContent="auto $interfaceName"
                        interfaceContent+="\nallow-hotplug $interfaceName"
            [ $ip4 ] && interfaceContent+="\niface $interfaceName inet dhcp"
            [ $ip6 ] && interfaceContent+="\niface $interfaceName inet6 dhcp"
            ;;
        "static")
                        interfaceContent="auto $interfaceName"
                        interfaceContent+="\nallow-hotplug $interfaceName"
            [ $ip4 ] && interfaceContent+="\niface $interfaceName inet static" \
                     && interfaceContent+="\n    address $ip4" \
                     && interfaceContent+="\n    gateway $ip4Gateway"
            [ $ip6 ] && interfaceContent+="\niface $interfaceName inet6 static" \
                     && interfaceContent+="\n    address $ip6" \
                     && interfaceContent+="\n    gateway $ip6Gateway"
            ;;
        *)  usage "ERROR: unknown interface template '$interface'." 1 ;;
    esac
    printf -v interfaceContent "$interfaceContent"
    info "sysprep" \
         "default operations: https://www.libguestfs.org/virt-sysprep.1.html#operations" \
         "host settings: timezone, hostname" \
         "root access: password, ssh" \
         "network configuration" \
         "setting machine-id" \
         "update apt" \
         "update sshd keys" \
         "update bootloader after lvm id has changed"
    info "timezone" "$timezone"
    info "hostname" "$hostname"
    info "root password" "$password"
    info "root ssh key" "$sshKey"
    info "sshd keys" "${sshdKeys:-autogenerated}"
    info "interface" "$interface"
    info "ip4" "$ip4"
    info "ip4 gateway" "$ip4Gateway"
    info "ip6" "$ip6"
    info "ip6 gateway" "$ip6Gateway"
    prepareArgs=(
        # host settings: timezone, hostname
        --timezone "$timezone"
        --hostname "$hostname"
        # root access: password, ssh
        --root-password "password:$password"
        --ssh-inject "root:file:$sshKey"
        # network configuration
        --write "/etc/network/interfaces.d/$interfaceName:$interfaceContent"
        # machine id
        --touch "/etc/machine-id"
        --truncate "/etc/machine-id"
    )
    # update sshd keys
    if [ "$sshdKeys" ]; then
        for key in "$sshdKeys"/ssh_host_*; do
            prepareArgs+=( --copy-in "$key:/etc/ssh" )
        done
    else
        prepareArgs+=( --run-command "dpkg-reconfigure openssh-server" )
    fi
    # execute
    virt-sysprep -d "$name" "${prepareArgs[@]}"

    customizeArgs=(
        # update apt
        --run-command "apt-get update"
        # update bootloader after lvm id has changed
        --run-command "grub-install /dev/sda"
        --run-command "update-grub2"
    )
    virt-customize -d "$name" "${customizeArgs[@]}"
fi
success
