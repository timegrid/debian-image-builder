#!/usr/bin/env bash
# For copyright and license terms, see LICENSE.txt (top level of repository)
# Repository: https://github.com/timegrid/debian-image-builder
#
#% Usage: ./create_image.sh [OPTIONS] rootfs name
#%
#%   Creates/Prepares a disk image with one partition from a debian rootfs.
#%
#% Arguments:
#%   rootfs:               path to the rootfs (folder/tar/tar.xz)
#%   name:                 name of the image
#%
#% Options:
#%   -f, --format=FORMAT   format of the disk file (default: 'qcow2')
#%   -s, --size=SIZE       size of the disk (default: '5G')
#%   -l, --lvmPath=PATH    path to lv, names vg/lv (default: '/dev/vg/root'),
#%                           no path means no lvm
#%   -t, --type=TYPE       type of the filesystem (default: 'ext4')
#%       --image-dir=PATH  path for created disks (default: './image')
#%
#%   -h, --help            display this help
#%       --colorless       omit colors

set -eu

# Project
scriptDir="$(dirname "$(readlink -vf "$0")")"
source "$scriptDir/.project.sh" \
       --short "f:s:l:t:" \
       --long  "format:,size:,lvm-path:,type:,image-dir:" \
       --root \
       -- "$@"
projectUser="$projectUser"
projectGroup="$projectGroup"
libvirtDir="$libvirtDir"

# Options
format=qcow2
size=5G
lvmPath=/dev/vg/root
type=ext4
imageDir="$libvirtDir/image"
while true; do
    case "$1" in
       -f | --format)    format="$2"   ; shift 2 ;;
       -s | --size)      size="$2"     ; shift 2 ;;
       -l | --lvm-path)  lvmPath="$2"  ; shift 2 ;;
       -t | --type)      type="$2"     ; shift 2 ;;
            --image-dir) imageDir="$2" ; shift 2 ;;

       --) shift; break ;;
       *)  usage "ERROR: unknown flag '$1'." 1 ;;
    esac
done

# Arguments
rootfs="${1:-}"; shift || usage "missing argument: rootfs" 1
rootfs="$(readlink -vf "$rootfs")"
[ -e "$rootfs" ] || error "rootfs $rootfs does not exist"
name="${1:-}"; shift || usage "missing argument: name" 1

# Paths
lvmLv="$(basename "$lvmPath")"
lvmVg="$(basename "$(dirname "$lvmPath")")"
rootPartition="${lvmPath:-/dev/sda1}"
image="$imageDir/$name.${lvmPath:+lvm.}$type.$format"
mkdir -p "$imageDir"
chown "$projectUser:$projectGroup" "$imageDir"

# Switches
created=false
[ -f "$image" ] && created=true


#------------------------------------------------------------------------------
#%% Prepare rootfs tar file
#------------------------------------------------------------------------------

title "Prepare rootfs tar file"
info "rootfs" "$rootfs"
case "$rootfs" in
    *.tar)    ;;
    *.tar.xz) rootfs=${rootfs%.xz}
              if [ -f "$rootfs" ]; then
                  info "rootfs tar file already exists, skipping decompression"
              else
                  info "decompress rootfs .."
                  xz --quiet --keep --force --decompress $rootfs.xz
              fi ;;
    # folder
    *)        rootfs="$rootfs.tar"
              if [ -f "$rootfs" ]; then
                  info "rootfs tar file already exists, skipping tar creation"
              else
                  info "create rootfs tarball .."
                  tar -cf "$rootfs" "${rootfs%.tar}"
              fi ;;
esac
success


#------------------------------------------------------------------------------
#%% Fetch OS information from tarball
#------------------------------------------------------------------------------

title "Fetch OS information from tarball"
if $created; then
    info "image already exists, skipping information gathering"
else
    info "rootfs" "$rootfs"
    osRelease="$(tar -axf $rootfs -O usr/lib/os-release)"
    osCodename="$(grep -Po "(?<=VERSION_CODENAME=).*" <<< $osRelease)"
    info "os codename" "$osCodename"
    osVersion=${debianVersions[$osCodename]-0}
    info "os version" "$osVersion"
fi
success


#------------------------------------------------------------------------------
#%% Convert rootfs to disk image
#------------------------------------------------------------------------------

title "Convert rootfs to image"
info "image" "$image"
info "rootfs" "$rootfs"
if $created; then
    info "image already exists, skipping convertion"
else
    mkfsFeatures=
    if [ $osVersion -le 11 ]; then
        mkfsFeatures=()
        # see https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1031622
        cat /etc/mke2fs.conf | grep -q orphan_file \
            && mkfsFeatures+=( ^orphan_file )
        # see https://wiki.archlinux.org/title/GRUB#error:_unknown_filesystem
        cat /etc/mke2fs.conf | grep -q metadata_csum_seed \
            && mkfsFeatures+=( ^metadata_csum_seed )
        mkfsFeatures="features:$(join_by , "${mkfsFeatures[@]}")"
    fi
    if [ "$lvmPath" ]; then
        guestfish                                 \
          disk_create "$image" "$format" "$size"  \
        : add "$image"                            \
        : run                                     \
        : part-disk /dev/sda mbr                  \
        : pvcreate /dev/sda1                      \
        : vgcreate "$lvmVg" /dev/sda1             \
        : lvcreate-free "$lvmLv" "$lvmVg" 100     \
        : mkfs "$type" "$lvmPath" $mkfsFeatures   \
        : mount "$lvmPath" /                      \
        : tar-in "$rootfs" / xattrs:true
    else
        guestfish                                 \
          disk_create "$image" "$format" "$size"  \
        : add "$image"                            \
        : run                                     \
        : part-disk /dev/sda mbr                  \
        : mkfs "$type" /dev/sda1 $mkfsFeatures    \
        : mount /dev/sda1 /                       \
        : tar-in "$rootfs" / xattrs:true
    fi
    if [ -f "$image" ]; then
        chown "$projectUser:$projectGroup" "$image"
    fi
    rootfsChecksum="$(shasum_file "$rootfs" 256)"
    info "rootfs shasum" "$rootfsChecksum"
    imageChecksum="$(shasum_qcow2_tar "$image" 256)"
    info "image shasum" "$imageChecksum"
    [ "$imageChecksum" = "$rootfsChecksum" ] || error "image checksum verification failed"
fi
success


#------------------------------------------------------------------------------
#%% Prepare disk image
#------------------------------------------------------------------------------

title "Prepare disk image"
info "image" "$image"
if $created; then
    info "image already exists, skipping preparations"
else
    info "customize" "Remove docker specific files" \
                     "Write fstab" \
                     "Install bootloader" \
                     "Enable serial console"
    info "root partition" "$rootPartition"
    # Customize install
    gettyTarget="/lib/systemd/system/serial-getty@.service"
    gettyLink="/etc/systemd/system/getty.target.wants/serial-getty@ttyS0.service"
    customizeArgs=(
        # Remove docker specific files
        --delete "/usr/sbin/policy-rc.d"
        --delete "/etc/dpkg/dpkg.cfg.d/docker-apt-speedup"
        --delete "/etc/apt/apt.conf.d/docker-autoremove-suggests"
        --delete "/etc/apt/apt.conf.d/docker-clean"
        --delete "/etc/apt/apt.conf.d/docker-gzip-indexes"
        --delete "/etc/apt/apt.conf.d/docker-no-languages"
        --delete "/etc/dpkg/dpkg.cfg.d/docker"
        # Write fstab
        --write "/etc/fstab:$rootPartition / $type rw,relatime,data=ordered 1 1"
        # Install bootloader
        --run-command "echo 'grub-pc grub-pc/install_devices multiselect /dev/vda' \
                       | debconf-set-selections"
        --run-command "grub-install /dev/sda"
        --run-command "update-grub2"
        # Enable serial console
        --link "$gettyTarget:$gettyLink"
    )
    virt-customize -a "$image" "${customizeArgs[@]}"
fi
success
