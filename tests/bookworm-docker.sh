#!/usr/bin/env bash
# For copyright and license terms, see LICENSE.txt (top level of repository)
# Repository: https://github.com/timegrid/debian-image-builder
#
#% Usage: ./test_docker.sh
#%
#%   Tests image build for docker, builds/imports the image and runs the container.

set -eu

# Project
scriptDir="$(dirname "$(readlink -vf "$0")")"
source "$scriptDir/.project.sh" \
       --root \
       -- "$@"
dockerDir="$dockerDir"

# Configuration
suite="bookworm"
image="debian:bookworm-slim"


#------------------------------------------------------------------------------
#%% Build the docker image
#------------------------------------------------------------------------------

if ! docker image inspect "$image" &> /dev/null; then
    "$dockerDir/build.sh" "$suite" "$image"
fi


#------------------------------------------------------------------------------
#%% Run the docker container
#------------------------------------------------------------------------------

title "Run the docker container"
info "image" "$image"
docker run --pull=never --rm -it $image bash
