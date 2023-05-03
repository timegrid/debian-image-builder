#!/usr/bin/env bash
# For copyright and license terms, see LICENSE.txt (top level of repository)
# Repository: https://github.com/timegrid/debian-image-builder
#
#% Usage: ./stop
#%
#%   Stops and removes the apt-cacher-ng docker container.
#%
#% Options:
#%   -h, --help              display this help
#%       --colorless         omit colors

set -eu

# Project
scriptDir="$(dirname "$(readlink -vf "$0")")"
source "$scriptDir/.project.sh" \
       -- "$@"


#------------------------------------------------------------------------------
#%% Stop the apt-cacher-ng docker service
#------------------------------------------------------------------------------

title "Stop the apt-cacher-ng docker service"
if [ -z "$(docker ps -f "name=apt-cacher-ng" -f "status=running" -q)" ]; then
    info "service not running"
else
    docker stop apt-cacher-ng > /dev/null
    docker remove apt-cacher-ng > /dev/null
fi
success
