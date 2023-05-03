#!/usr/bin/env bash
# For copyright and license terms, see LICENSE.txt (top level of repository)
# Repository: https://github.com/timegrid/debian-image-builder
#
#% Usage: ./create_volume.sh [OPTIONS] image pool
#%
#%   Copies an image into the pool directory and refreshes the pool.
#%
#% Arguments:
#%   image:                path to the image
#%   pool:                 name of the pool
#%
#% Options:
#%   -n, --name            name of the volume (default: image basename)
#%
#%   -h, --help            display this help
#%       --colorless       omit colors

set -eu

# Project
scriptDir="$(dirname "$(readlink -vf "$0")")"
source "$scriptDir/.project.sh" \
       --short "n:" \
       --long  "name:" \
       --root \
       -- "$@"
projectUser="$projectUser"
projectGroup="$projectGroup"
libvirtDir="$libvirtDir"

# Options
name=
while true; do
    case "$1" in
       -n | --name) name="$2" ; shift 2 ;;

       --) shift; break ;;
       *)  usage "ERROR: unknown flag '$1'." 1 ;;
    esac
done

# Arguments
image="${1:-}"; shift || usage "missing argument: image" 1
[ -e "$image" ] || error "image $image does not exist"
pool="${1:-}"; shift || usage "missing argument: pool" 1

# Paths
poolDir="$(virsh pool-dumpxml $pool | grep -Po "(?<=<path>).*(?=</path>)")"
[ -d $poolDir ] || error "pool '$pool' or directory '$poolDir' does not exist"
volume="$poolDir/${name:-"$(basename "$image")"}"


#------------------------------------------------------------------------------
#%% Add disk image to libvirt pool
#------------------------------------------------------------------------------

title "Add disk image to libvirt pool"
info "image" "$image"
info "volume" "$volume"
if [ -f $volume ]; then
    info "volume already exists, skipping copy"
else
    cp "$image" "$volume"
    chown "$projectUser:$projectGroup" "$volume"
fi
success


#------------------------------------------------------------------------------
#%% Refresh libvirt pool
#------------------------------------------------------------------------------

title "Refresh libvirt pool"
virsh pool-refresh "$pool"
success
