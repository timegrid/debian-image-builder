#!/usr/bin/env bash
# For copyright and license terms, see LICENSE.txt (top level of repository)
# Repository: https://github.com/timegrid/debian-image-builder
#
#% Usage: ./clean
#%
#%   Removes all local debian images for a complete rebuild
#%
#% Options:
#%   -h, --help              display this help
#%       --colorless         omit colors

set -eu

# Project
scriptDir="$(dirname "$(readlink -vf "$0")")"
source "$scriptDir/.project.sh" \
       --confirm -- "$@"


#------------------------------------------------------------------------------
#%% Remove all debian docker images
#------------------------------------------------------------------------------

title "Remove all debian docker images"
images="$(docker images --filter=reference="debian:*" -q)"
[ "$images" ] && docker rmi $images > /dev/null || true
success
