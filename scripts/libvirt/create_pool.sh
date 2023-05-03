#!/usr/bin/env bash
# For copyright and license terms, see LICENSE.txt (top level of repository)
# Repository: https://github.com/timegrid/debian-image-builder
#
#% Usage: ./create_pool.sh [OPTIONS] name
#%
#%   Defines, builds and starts a dir pool.
#%
#% Arguments:
#%   name:                 name of the pool
#%
#% Options:
#%       --pool-dir=PATH   directory of the pool (default: './pool')
#%
#%   -h, --help            display this help
#%       --colorless       omit colors

set -eu

# Project
scriptDir="$(dirname "$(readlink -vf "$0")")"
source "$scriptDir/.project.sh" \
       --long  "pool-dir:" \
       --root \
       -- "$@"
projectUser="$projectUser"
projectGroup="$projectGroup"
libvirtDir="$libvirtDir"

# Options
poolDir="$libvirtDir/pool"
while true; do
    case "$1" in
       --pool-dir) poolDir="$2" ; shift 2 ;;

       --) shift; break ;;
       *)  usage "ERROR: unknown flag '$1'." 1 ;;
    esac
done

# Arguments
name="${1:-}"; shift || usage "missing argument: pool" 1

# Paths
poolPath="$poolDir/$name"
mkdir -p "$poolDir"
chown "$projectUser:$projectGroup" "$poolDir"


#------------------------------------------------------------------------------
#%% Define libvirt pool
#------------------------------------------------------------------------------

title "Define libvirt pool"
info "name" "$name"
info "path" "$poolPath"
if virsh pool-info "$name" &> /dev/null; then
    info "pool already defined, skipping definition"
else
    defineArgs=(
        --type dir
        --name "$name"
        --target "$poolPath"
    )
    virsh pool-define-as "${defineArgs[@]}"
fi
success


#------------------------------------------------------------------------------
#%% Build libvirt pool
#-----------------------------------------------------------------------------

title "Build libvirt pool"
info "name" "$name"
info "path" "$poolPath"
if [ -d "$poolPath" ]; then
    info "pool already built, skipping build"
else
    virsh pool-build "$name"
    chown "$projectUser:$projectGroup" "$poolPath"
fi
success


#------------------------------------------------------------------------------
#%% Start libvirt pool
#------------------------------------------------------------------------------

title "Start libvirt pool"
info "name" "$name"
info "path" "$poolPath"
poolInfo="$(virsh pool-info "$name" 2> /dev/null)"
if grep -q "^State:.*running" <<< "$poolInfo"; then
    info "already started, skipping start"
else
    virsh pool-start "$name"
fi
success
