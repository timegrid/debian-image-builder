#!/usr/bin/env bash
# For copyright and license terms, see LICENSE.txt (top level of repository)
# Repository: https://github.com/timegrid/debian-image-builder
#
#% Usage: ./clean.sh
#%
#%   Cleans all artifacts (except caches/buildlogs) for a complete rebuild

set -eu

# Project
scriptDir="$(dirname "$(readlink -vf "$0")")"
source "$scriptDir/.project.sh" \
       --confirm -- "$@"
debuerreotypeDir="$debuerreotypeDir"
debootstrapDir="$debootstrapDir"
aptcacherngDir="$aptcacherngDir"
dockerDir="$dockerDir"
libvirtDir="$libvirtDir"


#------------------------------------------------------------------------------
#%% Run libvirt clean script
#------------------------------------------------------------------------------

"$libvirtDir"/clean.sh --yes


#------------------------------------------------------------------------------
#%% Run docker clean script
#------------------------------------------------------------------------------

"$dockerDir"/clean.sh --yes


#------------------------------------------------------------------------------
#%% Run debuerreotype clean script
#------------------------------------------------------------------------------

"$debuerreotypeDir"/clean.sh --yes


#------------------------------------------------------------------------------
#%% Run debootstrap clean script
#------------------------------------------------------------------------------

"$debootstrapDir"/clean.sh --yes
