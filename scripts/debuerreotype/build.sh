#!/usr/bin/env bash
# For copyright and license terms, see LICENSE.txt (top level of repository)
# Repository: https://github.com/timegrid/debian-image-builder
#
#% Usage: ./build [OPTIONS] suite
#%
#%   Builds a debuerreotype debian rootfs for both docker and libvirt.
#%
#% Arguments:
#%   suite:                codename of debian version, e.g. 'bookworm'
#%
#% Options:
#%   -a, --arch=ARCH       architecture to install (default: 'amd64')
#%   -t, --timestamp=TS    timestamp of the debian snapshot
#%                           (default: 2023-04-26T00:00:00Z)
#%       --include=CSV     packages to include in the rootfs
#%       --exclude=CSV     packages to exclude in the rootfs
#%
#%       --docker          build only docker image
#%       --libvirt         build only libvirt image
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
       --short "a:t:i:e:" \
       --long  "arch:,timestamp:,include:,exclude:,docker,libvirt,build-dir:" \
       -- "$@"
projectUser="$projectUser"
projectGroup="$projectGroup"
debuerreotypeDir="$debuerreotypeDir"
aptcacherngDir="$aptcacherngDir"
debianArch="$debianArch"
debianTimestamp="$debianTimestamp"

# Options
buildDir="$debuerreotypeDir/builds"
include=
exclude=
docker=false
libvirt=false
while true; do
    case "$1" in
       -a | --arch)      debianArch="$2"      ; shift 2 ;;
       -t | --timestamp) debianTimestamp="$2" ; shift 2 ;;
       -i | --include)   include="$2"         ; shift 2 ;;
       -e | --exclude)   exclude="$2"         ; shift 2 ;;
            --docker)    docker=true          ; shift   ;;
            --libvirt)   libvirt=true         ; shift   ;;
            --build-dir) buildDir="$2"        ; shift 2 ;;

       --) shift; break ;;
       *)  usage "ERROR: unknown flag '$1'." 1 ;;
    esac
done
! $docker && ! $libvirt && docker=true libvirt=true

# Arguments
suite="${1:-}"; shift || usage "missing argument: suite" 1

# Packages
libvirtInclude=(
    # --- debian:important
    # adduser
    apt-utils
    # cpio
    # cron
    # cron-daemon-common
    # debconf-i18n
    # dmidecode
    # fdisk
    ifupdown
    init
    iproute2
    iputils-ping
    isc-dhcp-client
    isc-dhcp-common
    kmod
    # less
    logrotate
    # nano
    netbase
    nftables
    # procps
    readline-common
    # sensible-utils
    systemd
    systemd-sysv
    # tasksel-data
    udev
    # vim-common
    # vim-tiny
    # whiptail

    # --- boot
    lvm2
    grub2
    linux-image-$debianArch

    # --- ansible
    openssh-server
    python3
    python-is-python3
    dbus

    # --- ansible initial check mode
    git
    python3-apt
    python3-setuptools
)
libvirtInclude+=(${include//,/ })
libvirtExclude=()
libvirtExclude+=(${exclude//,/ })
dockerInclude=()
dockerInclude+=(${include//,/ })
dockerExclude=()
dockerExclude+=(${exclude//,/ })

# Image
image="$("$debuerreotypeDir/upstream/.docker-image.sh")"

# Paths
buildLog="$buildDir/build.sha256.log"
serial="$(date --date "$debianTimestamp" +%Y%m%d)"
dockerSuiteDir="$buildDir/docker/$serial/$debianArch/$suite"
libvirtSuiteDir="$buildDir/libvirt/$serial/$debianArch/$suite"
mkdir -p "$buildDir/docker" "$buildDir/libvirt"
touch "$buildLog"
chown "$projectUser:$projectGroup" "$buildLog" "$buildDir" "$buildDir/docker" "$buildDir/libvirt"

# Patches
cp "$debuerreotypeDir/upstream/examples/debian.sh" "$buildDir/"
for patchfile in "$debuerreotypeDir"/patches/debian.sh.*.diff; do
    patch --directory "$buildDir" --input "$patchfile" --forward --quiet
done
chown "$projectUser:$projectGroup" "$buildDir/debian.sh"


#------------------------------------------------------------------------------
#%% Bootstrap a debuerreotype docker image
#------------------------------------------------------------------------------

if ! docker image inspect "$image" &> /dev/null; then
    "$debuerreotypeDir/bootstrap.sh"
fi

#------------------------------------------------------------------------------
#%% Run an apt-cacher-ng docker service
#------------------------------------------------------------------------------

$aptcacherngDir/start.sh
trap "$aptcacherngDir/stop.sh" EXIT
export http_proxy="http://$(docker exec apt-cacher-ng sh -c "hostname --ip-address"):3142"


#------------------------------------------------------------------------------
#%% Create a debuerreotype rootfs for docker images
#------------------------------------------------------------------------------

if $docker; then
    title "Create a debuerreotype rootfs for docker images"
    info "suite" "$suite"
    info "arch" "$debianArch"
    info "timestamp" "$debianTimestamp"
    info "path" "$dockerSuiteDir"
    if [ -f "$dockerSuiteDir/rootfs.tar.xz" ] && [ -f "$dockerSuiteDir/slim/rootfs.tar.xz" ]; then
        info "rootfs for docker already exists, skipping build"
    else
        # Build
        info "include" "${dockerInclude[@]-}"
        info "exclude" "${dockerExclude[@]-}"
        buildArgs=(
            --arch="$debianArch"
        )
        [ "${dockerInclude[*]}" ] && buildArgs+=("--include=$(join_by , "${dockerInclude[@]}")")
        [ "${dockerExclude[*]}" ] && buildArgs+=("--exclude=$(join_by , "${dockerExclude[@]}")")
        cd "$buildDir"
        "$debuerreotypeDir/upstream/docker-run.sh" --no-build sh -euxc \
            "./debian.sh ${buildArgs[*]} docker $suite $debianTimestamp"
        cd -
        dockerRootfsChecksum="$(shasum_tarxz_tar "$dockerSuiteDir/rootfs.tar.xz" 256)"
        dockerRootfsSlimChecksum="$(shasum_tarxz_tar "$dockerSuiteDir/slim/rootfs.tar.xz" 256)"
        info "rootfs shasum" "$dockerRootfsChecksum"
        info "rootfs slim shasum" "$dockerRootfsSlimChecksum"

        # Log
        dockerIncludeShasum=$( sha256_array "${dockerInclude[@]}" )
        dockerExcludeShasum=$( sha256_array "${dockerExclude[@]}" )
        logColumns=(
            "docker/$serial/$debianArch/$suite"
            "$dockerIncludeShasum"
            "$dockerExcludeShasum"
            "$dockerRootfsChecksum"
            "$dockerRootfsSlimChecksum"
        )
        echo $(join_by , "${logColumns[@]}") >> "$buildLog"
    fi
    success
fi


#------------------------------------------------------------------------------
#%% Create a debuerreotype rootfs for libvirt images
#------------------------------------------------------------------------------

if $libvirt; then
    title "Create a debuerreotype rootfs for libvirt images"
    info "suite" "$suite"
    info "arch" "$debianArch"
    info "timestamp" "$debianTimestamp"
    info "path" "$libvirtSuiteDir"
    if [ -f "$libvirtSuiteDir/rootfs.tar.xz" ] && [ -f "$libvirtSuiteDir/slim/rootfs.tar.xz" ]; then
        info "rootfs for libvirt already exists, skipping build"
    else
        # Build
        info "include" "${libvirtInclude[@]-}"
        info "exclude" "${libvirtExclude[@]-}"
        buildArgs=()
        [ "${libvirtInclude[*]}" ] && buildArgs+=("--include=$(join_by , "${libvirtInclude[@]}")")
        [ "${libvirtExclude[*]}" ] && buildArgs+=("--exclude=$(join_by , "${libvirtExclude[@]}")")
        cd "$buildDir"
        "$debuerreotypeDir/upstream/docker-run.sh" --no-build sh -euxc \
            "./debian.sh ${buildArgs[*]} libvirt $suite $debianTimestamp"
        cd -
        libvirtRootfsChecksum="$(shasum_tarxz_tar "$libvirtSuiteDir/rootfs.tar.xz" 256)"
        libvirtRootfsSlimChecksum="$(shasum_tarxz_tar "$libvirtSuiteDir/slim/rootfs.tar.xz" 256)"
        info "rootfs shasum" "$libvirtRootfsChecksum"
        info "rootfs slim shasum" "$libvirtRootfsSlimChecksum"

        # Log
        libvirtIncludeShasum=$( sha256_array "${libvirtInclude[@]}" )
        libvirtExcludeShasum=$( sha256_array "${libvirtExclude[@]}" )
        logColumns=(
            "libvirt/$serial/$debianArch/$suite"
            "$libvirtIncludeShasum"
            "$libvirtExcludeShasum"
            "$libvirtRootfsChecksum"
            "$libvirtRootfsSlimChecksum"
        )
        echo $(join_by , "${logColumns[@]}") >> "$buildLog"
    fi
    success
fi
