#!/usr/bin/env bash
# For copyright and license terms, see LICENSE.txt (top level of repository)
# Repository: https://github.com/timegrid/debian-image-builder
#
#% Usage: ./clean
#%
#%   Cleans all apt-cacher-ng artifacts (except the cache) for a complete rebuild
#%
#% Options:
#%   -h, --help              display this help
#%       --colorless         omit colors

set -eu

# Project
scriptDir="$(dirname "$(readlink -vf "$0")")"
source "$scriptDir/.project.sh" \
       --confirm -- "$@"
aptcacherngDir="$aptcacherngDir"


#------------------------------------------------------------------------------
#%% Remove the apt-cacher-ng docker image
#------------------------------------------------------------------------------

title "Remove the apt-cacher-ng docker image"
docker stop apt-cacher-ng     &> /dev/null || true
docker remove apt-cacher-ng   &> /dev/null || true
docker image rm apt-cacher-ng &> /dev/null || true
success

#------------------------------------------------------------------------------
#%% Remove the log folder
#------------------------------------------------------------------------------

title "Remove the log folder"
rm -rf "$aptcacherngDir"/log
success
