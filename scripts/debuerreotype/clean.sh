#!/usr/bin/env bash
# For copyright and license terms, see LICENSE.txt (top level of repository)
# Repository: https://github.com/timegrid/debian-image-builder
#
#% Usage: ./clean
#%
#%   Cleans all debuerreotype artifacts (except the log) for a complete rebuild
#%
#% Options:
#%   -h, --help              display this help
#%       --colorless         omit colors

set -eu

# Project
scriptDir="$(dirname "$(readlink -vf "$0")")"
source "$scriptDir/.project.sh" \
       --confirm -- "$@"
debuerreotypeDir="$debuerreotypeDir"

# Images
baseImage="$(grep -Po "(?<=^FROM ).*$" "$debuerreotypeDir/upstream/Dockerfile")"
image="$("$debuerreotypeDir/upstream/.docker-image.sh")"


#------------------------------------------------------------------------------
#%% Remove builds
#------------------------------------------------------------------------------

title "Remove debuerreotype builds"
rm -rf "$debuerreotypeDir"/builds/docker
rm -rf "$debuerreotypeDir"/builds/libvirt
rm -rf "$debuerreotypeDir"/builds/debian.sh
success

#------------------------------------------------------------------------------
#%% Remove docker images
#------------------------------------------------------------------------------

title "Remove debuerreotype docker image"
info "image"    "$image"
docker stop     "$image" &> /dev/null || true
docker remove   "$image" &> /dev/null || true
docker image rm "$image" &> /dev/null || true
success

title "Remove debuerreotype docker base image"
info "image"    "$baseImage"
docker stop     "$baseImage" &> /dev/null || true
docker remove   "$baseImage" &> /dev/null || true
docker image rm "$baseImage" &> /dev/null || true
success
