#!/usr/bin/env bash
# For copyright and license terms, see LICENSE.txt (top level of repository)
# Repository: https://github.com/timegrid/debian-image-builder
#
#% Usage: ./build [OPTIONS] [suite] [image]
#%
#%   Builds a debian docker image from scratch.
#%
#% Arguments:
#%   suite:                codename of debian version, e.g. 'bookworm'
#%   image:                name of docker image, e.g. 'debian:bookworm-slim'
#%
#% Options:
#%   -a, --arch=ARCH       architecture to install (default: 'amd64')
#%   -t, --timestamp=TS    timestamp of the debian snapshot
#%                           (default: 2023-04-26T00:00:00Z)
#%       --include=CSV     packages to include in the rootfs
#%       --exclude=CSV     packages to exclude in the rootfs
#%
#%   -h, --help            display this help
#%       --colorless       omit colors

set -eu

# Project
scriptDir="$(dirname "$(readlink -vf "$0")")"
source "$scriptDir/.project.sh" \
       --short "a:t:i:e:" \
       --long  "arch:,timestamp:,include:,exclude:" \
       --root \
       -- "$@"
debuerreotypeDir="$debuerreotypeDir"
debianArch="$debianArch"
debianTimestamp="$debianTimestamp"

# Options
include=
exclude=
while true; do
    case "$1" in
       -a | --arch)      debianArch="$2"      ; shift 2 ;;
       -t | --timestamp) debianTimestamp="$2" ; shift 2 ;;
       -i | --include)   include="$2"         ; shift 2 ;;
       -e | --exclude)   exclude="$2"         ; shift 2 ;;

       --) shift; break ;;
       *)  usage "ERROR: unknown flag '$1'." 1 ;;
    esac
done

# Arguments
suite="${1:-}"; shift || usage "missing argument: suite" 1
image="${1:-}"; shift || usage "missing argument: image" 1

# Paths
serial="$(date --date "$debianTimestamp" +%Y%m%d)"
rootfs="$debuerreotypeDir/builds/docker/$serial/$debianArch/$suite/slim/rootfs.tar.xz"


#------------------------------------------------------------------------------
#%% Build debuerreotype rootfs
#------------------------------------------------------------------------------

if [ ! -f "$rootfs" ]; then
    buildArgs=(
        --arch "$debianArch"
        --timestamp "$debianTimestamp"
        --docker
    )
    [ "$include" ] && buildArgs+=( --include="$include" )
    [ "$exclude" ] && buildArgs+=( --exclude="$exclude" )
    "$debuerreotypeDir/build.sh" "${buildArgs[@]}" "$suite"
fi


#------------------------------------------------------------------------------
#%% Import debuerreotype rootfs into docker image
#------------------------------------------------------------------------------

title "Import debuerreotype rootfs into docker image"
info "image" "$image"
info "suite" "$suite"
info "rootfs" "$rootfs"
rootfsChecksum="$(shasum_tarxz_tar "$rootfs" 256)"
info "rootfs shasum" "$rootfsChecksum"
imageChecksum="$(sha256_docker_layer0 "$image")"
case $imageChecksum in
    "") xz -cd "$rootfs" | docker import - "$image" > /dev/null ;;
    "$rootfsChecksum") info "rootfs already imported, skipping import" ;;
    *) warning "existing docker image has an unknown rootfs, skipping import" ;;
esac
imageChecksum="$(sha256_docker_layer0 "$image")"
info "docker layer0 shasum" "$imageChecksum"
success
