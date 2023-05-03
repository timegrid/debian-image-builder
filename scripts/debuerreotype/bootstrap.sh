#!/usr/bin/env bash
# For copyright and license terms, see LICENSE.txt (top level of repository)
# Repository: https://github.com/timegrid/debian-image-builder
#
#% Usage: ./bootstrap [OPTIONS]
#%
#%   Bootstraps a debuerreotype docker image (debuerreotype/debuerreotype:<version>).
#%
#%   Note: The build directory is mounted into the debuerreotype container.
#%
#% Options:
#%   -a, --arch=ARCH       architecture to install (default: 'amd64')
#%   -t, --timestamp=TS    timestamp of the debian snapshot
#%                           (default: 2023-04-26T00:00:00Z)
#%
#%       --build-dir=PATH  build directory (default: './builds')
#%                           note: build dir is mounted into debuerreotype container
#%
#%   -h, --help            display this help
#%       --colorless       omit colors

set -eu

# Project
scriptDir="$(dirname "$(readlink -vf "$0")")"
source "$scriptDir/.project.sh" \
       --root --short "a:t:" --long  "arch:,timestamp:,build-dir:" -- "$@"
projectUser="$projectUser"
projectGroup="$projectGroup"
debuerreotypeDir="$debuerreotypeDir"
aptcacherngDir="$aptcacherngDir"
debianArch="$debianArch"
debianTimestamp="$debianTimestamp"

# Options
buildDir="$debuerreotypeDir/builds"
while true; do
    case "$1" in
       -a | --arch)      debianArch="$2"      ; shift 2 ;;
       -t | --timestamp) debianTimestamp="$2" ; shift 2 ;;
            --build-dir) buildDir="$2"        ; shift 2 ;;

       --) shift; break ;;
       *)  usage "ERROR: unknown flag '$1'." 1 ;;
    esac
done

# Image
baseImage="$(grep -Po "(?<=^FROM ).*$" "$debuerreotypeDir/upstream/Dockerfile")"
baseSuite="$(grep -Po "(?<=:)(.*?)(?=-)" <<< "$baseImage")"
image="$("$debuerreotypeDir/upstream/.docker-image.sh")"

# Paths
debootstrapRootfs="$debootstrapDir/builds/$baseSuite/rootfs"
serial="$(date --date "$debianTimestamp" +%Y%m%d)"
rootfs="$buildDir/docker/$serial/$debianArch/$baseSuite/slim/rootfs.tar.xz"
mkdir -p "$buildDir"
chown "$projectUser:$projectGroup" "$buildDir"


#------------------------------------------------------------------------------
#%% Create debootstrap rootfs for docker base images
#------------------------------------------------------------------------------

"$debootstrapDir/build.sh" "$baseSuite" "$debianArch"


#------------------------------------------------------------------------------
#%% Import debootstrap rootfs into debuerreotype docker base image (big size)
#------------------------------------------------------------------------------

title "Import debootstrap rootfs into debuerreotype docker base image (big size)"
info "docker base image" "$baseImage"
debootstrapChecksum="$(shasum_folder_tar "$debootstrapRootfs" 256)"
info "debootstrap rootfs shasum" "$debootstrapChecksum"
debuerreotypeChecksum="$(shasum_tarxz_tar "$rootfs" 256)"
info "debuerreotype rootfs shasum" "$debuerreotypeChecksum"
baseImageChecksum="$(sha256_docker_layer0 "$baseImage")"
case $baseImageChecksum in
    "") tar -cC "$debootstrapRootfs" . | docker import - "$baseImage" > /dev/null ;;
    "$debootstrapChecksum") info "debootstrap rootfs already imported, skipping import" ;;
    "$debuerreotypeChecksum") info "debuerreotype rootfs imported, skipping import" ;;
    *) warning "existing docker base image has an unknown rootfs, skipping import" ;;
esac
baseImageChecksum="$(sha256_docker_layer0 "$baseImage")"
info "docker base image layer 0 shasum" "$baseImageChecksum"
success


#------------------------------------------------------------------------------
#%% Build debuerreotype docker image based on debootstrap rootfs
#------------------------------------------------------------------------------

title "Build debuerreotype docker image based on debootstrap rootfs"
info "image" "$image"
docker build --quiet --tag "$image" "$debuerreotypeDir/upstream" > /dev/null
imageChecksum="$(sha256_docker_layer0 "$image")"
info "docker image layer 0 shasum" "$imageChecksum"
success


#------------------------------------------------------------------------------
#%% Build and run apt-cacher-ng docker image based on debootstrap rootfs (big size)
#------------------------------------------------------------------------------

"$aptcacherngDir/start.sh"
trap "$aptcacherngDir/stop.sh" EXIT
export http_proxy="http://$(docker exec apt-cacher-ng sh -c "hostname --ip-address"):3142"


#------------------------------------------------------------------------------
#%% Create optimized debuerreotype rootfs for docker base images
#------------------------------------------------------------------------------

"$debuerreotypeDir/build.sh" "$baseSuite" --docker


#------------------------------------------------------------------------------
#%% Import debuerreotype rootfs into debuerreotype docker base image (small size)
#------------------------------------------------------------------------------

title "Import debuerreotype rootfs into debuerreotype docker base image (small size)"
info "docker base image" "$baseImage"
debootstrapChecksum="$(shasum_folder_tar "$debootstrapRootfs" 256)"
info "debootstrap rootfs shasum" "$debootstrapChecksum"
debuerreotypeChecksum="$(shasum_tarxz_tar "$rootfs" 256)"
info "debuerreotype rootfs shasum" "$debuerreotypeChecksum"
baseImageChecksum="$(sha256_docker_layer0 "$baseImage")"
case $baseImageChecksum in
    "" | "$debootstrapChecksum") xz -cd "$rootfs" | docker import - "$baseImage" > /dev/null ;;
    "$debuerreotypeChecksum") info "debuerreotype rootfs already imported, skipping import" ;;
    *) warning "existing docker base image has an unknown rootfs, skipping import" ;;
esac
baseImageChecksum="$(sha256_docker_layer0 "$baseImage")"
info "docker base image layer 0 shasum" "$baseImageChecksum"
success


#------------------------------------------------------------------------------
#%% Rebuild debuerreotype docker image based on debuerrotype rootfs
#------------------------------------------------------------------------------

title "Rebuild debuerreotype docker image based on debuerrotype rootfs"
info "image" "$image"
docker build --quiet --tag "$image" "$debuerreotypeDir/upstream" > /dev/null
imageChecksum="$(sha256_docker_layer0 "$image")"
info "docker image layer 0 shasum" "$imageChecksum"
success

#------------------------------------------------------------------------------
#%% Rebuild apt-cacher-ng docker image based on debuerreotype rootfs
#------------------------------------------------------------------------------

"$aptcacherngDir/build.sh" "$baseImage"
