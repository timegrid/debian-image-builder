#!/usr/bin/env bash
# For copyright and license terms, see LICENSE.txt (top level of repository)
# Repository: https://github.com/timegrid/debian-image-builder
#
#% Usage: ./build [OPTIONS]
#%
#%   Builds an apt-cacher-ng docker image.
#%
#% Options:
#%   -b, --base-image=NAME  base image (default: debian:bullseye-slim)
#%
#%   -h, --help              display this help
#%       --colorless         omit colors

set -eu

# Project
scriptDir="$(dirname "$(readlink -vf "$0")")"
source "$scriptDir/.project.sh" \
       --short "b:" --long  "base-image:" -- "$@"
aptcacherngDir="$aptcacherngDir"

# Options
baseImage=debian:bullseye-slim
while true; do
    case "$1" in
       -b | --base-image)  baseImage="$2" ; shift 2 ;;

       --) shift; break ;;
       *)  usage "ERROR: unknown flag '$1'." 1 ;;
    esac
done


#------------------------------------------------------------------------------
#%% Build an apt-cacher-ng docker image
#------------------------------------------------------------------------------

title "Build an apt-cacher-ng docker image"
info "image" "apt-cacher-ng"
info "base image" "$baseImage"
buildArgs=(
    --tag apt-cacher-ng
    --build-arg BASE_IMAGE="$baseImage"
    --quiet
    "$aptcacherngDir"
)
docker build "${buildArgs[@]}" > /dev/null
checksum="$(sha256_docker_layer0 apt-cacher-ng)"
info "docker layer 0 shasum" "$checksum"
success
