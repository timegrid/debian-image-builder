#!/usr/bin/env bash
# For copyright and license terms, see LICENSE.txt (top level of repository)
# Repository: https://github.com/timegrid/debian-image-builder
#
#% Usage: ./clean
#%
#%   Cleans all debootstrap artifacts (except the cache) for a complete rebuild
#%
#% Options:
#%   -h, --help              display this help
#%       --colorless         omit colors

set -eu

# Project
scriptDir="$(dirname "$(readlink -vf "$0")")"
source "$scriptDir/.project.sh" \
       --confirm -- "$@"
debootstrapDir="$debootstrapDir"


#------------------------------------------------------------------------------
#%% Remove builds
#------------------------------------------------------------------------------

title "Remove debootstrap builds"
rm -rf "$debootstrapDir"/builds
success

#------------------------------------------------------------------------------
#%% Remove keyrings
#------------------------------------------------------------------------------

title "Remove debootstrap keyrings"
rm -rf "$debootstrapDir"/keyrings/debian*keyring
rm -f "$debootstrapDir"/keyrings/*.tar.gz
rm -f "$debootstrapDir"/keyrings/*.json
success
