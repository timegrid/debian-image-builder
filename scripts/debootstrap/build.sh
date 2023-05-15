#!/usr/bin/env bash
# For copyright and license terms, see LICENSE.txt (top level of repository)
# Repository: https://github.com/timegrid/debian-image-builder
#
#% Usage: ./build [OPTIONS] suite
#%
#%   Generates a Debian rootfs with debootstrap.
#%
#% Arguments:
#%   suite:                  codename of debian version, e.g. 'bookworm'
#%
#% Options:
#%   -a, --arch=ARCH         architecture to install, default: 'amd64'
#%   -v, --variant=VARIANT   use variant of the bootstrap scripts
#%                             (buildd, fakechroot, minbase; default: minbase)
#%
#%   -c, --checksum=ALG:SHA  keyring checksum to validate against
#%   -k, --keyring=FILE      keyring file to use instead of downloading
#%
#%   -i, --include=CSV       packaged to include
#%   -e, --exclude=CSV       packaged to exclude
#%
#%       --build-dir=PATH    build directory, default: './builds'
#%       --cache-dir=PATH    cache directory, default: './cache'
#%       --keyring-dir=PATH  keyring directory, default: './keyrings'
#%
#%   -h, --help              display this help
#%       --colorless         omit colors

set -eu

# Project
scriptDir="$(dirname "$(readlink -vf "$0")")"
source "$scriptDir/.project.sh" \
       --short "a:v:c:k:i:e:" \
       --long  "arch:,variant:,\
                checksum:,keyring:,\
                include:,exclude:,\
                build-dir:,cache-dir:,keyring-dir:" \
       --root -- "$@"
projectUser="$projectUser"
projectGroup="$projectGroup"
debootstrapDir="$debootstrapDir"
debianArch="$debianArch"

# Options
variant=minbase
checksum=
keyring=
include=
exclude=
buildDir="$debootstrapDir/builds"
cacheDir="$debootstrapDir/cache"
keyringDir="$debootstrapDir/keyrings"
while true; do
    case "$1" in
       -a | --arch)        debianArch="$2" ; shift 2 ;;
       -v | --variant)     variant="$2"    ; shift 2 ;;
       -c | --checksum)    checksum="$2"   ; shift 2 ;;
       -k | --keyring)     keyring="$2"    ; shift 2 ;;
       -i | --include)     include="$2"    ; shift 2 ;;
       -e | --exclude)     exclude="$2"    ; shift 2 ;;
            --build-dir)   buildDir="$2"   ; shift 2 ;;
            --cache-dir)   cacheDir="$2"   ; shift 2 ;;
            --keyring-dir) keyringDir="$2" ; shift 2 ;;

       --) shift; break ;;
       *)  usage "ERROR: unknown flag '$1'." 1 ;;
    esac
done

# Arguments
suite="${1:-}"; shift || usage "missing argument: suite" 1

# Keyring
keyringName=debian-archive-keyring
packageMirror=https://mirrors.kernel.org
packageApi=https://sources.debian.org/api

# Paths
rootfsDir="$buildDir/$suite/rootfs"
mkdir -p "$keyringDir" "$cacheDir" "$buildDir"


#------------------------------------------------------------------------------
#%% Generate keyring
#------------------------------------------------------------------------------

if [ -z $keyring ]; then
    cd "$keyringDir"

    #%% Fetch keyring version
    title "Fetch keyring version"
    request="$packageApi/src/$keyringName/?suite=$suite"
    response="$keyringDir/$keyringName.$suite.sources.json"
    info "suite" "$suite"
    info "request" "$request"
    if [ -f "$response" ]; then
        info "package already fetched"
    else
        wget -qO "$response" "$request"
    fi
    version=$(cat "$response" | grep -oP '(?<="version":").*?(?=")' | head -1)
    if [ -z "$version" ]; then
        [ -f "$response" ] && cat "$response" && rm "$response"
        error "no package version. retry first (service might be down)"
    fi
    package="${keyringName}_$version"
    packageTar="$package.tar.xz"
    packageTarUrl="$packageMirror/debian/pool/main/d/$keyringName/$packageTar"
    packageDsc="$package.dsc"
    packageDscUrl="$packageMirror/debian/pool/main/d/$keyringName/$packageDsc"
    packageDir="$keyringDir/${package//_/-}"
    keyring="$packageDir/keyrings/$keyringName.gpg"
    info "version" "$version"
    success

    #%% Download keyring package and dsc
    title "Download keyring package and dsc"
    info "package" "$package"
    info "package tar.xz url" "$packageTarUrl"
    if [ -f "$packageTar" ]; then
        info "tar already downloaded"
    else
        wget -q "$packageTarUrl"
    fi
    info "package dsc url" "$packageDscUrl"
    if [ -f "$packageDsc" ]; then
        info "dsc already downloaded"
    else
        wget -q "$packageDscUrl"
    fi
    success

    #%% Verify package shasum (pinned shasum)
    title "Veryify package shasum (pinned shasum)"
    algorithm=512
    if [ ! -z "$checksum" ]; then
        algorithm="$(sed "s/sha\([0-9]*\):.*/\1/" <<< $checksum)"
    else
        checksum="sha512:$(cat "$keyringDir/$packageTar.sha512" | cut -d' ' -f1)"
    fi
    shasum="$(shasum_file "$packageTar" "$algorithm")"
    info "package shasum" "$shasum"
    info "pinned shasum" "$checksum"
    [ "$shasum" = "$checksum" ] || error "keyring package verification failed"
    success

    #%% Verify package dsc signature (pinned gpg key)
    title "Veryify package dsc signature (pinned gpg key)"
    if [ -d "$packageDir" ]; then
        info "package already extracted, skipping check"
    else
        tmpDir="$(mktemp --directory --tmpdir "$projectName.gpg_home.XXXXXXXXXX")"
        trap "$(printf 'rm -rf %q' "$tmpDir")" EXIT
        gnupghome="${GNUPGHOME:-}"; export GNUPGHOME=$tmpDir
        gpg --import "$keyringDir/$package.gpg"
        gpg --verify "$keyringDir/$package.dsc" \
            || error "keyring package signature verification failed"
        [ -z "$gnupghome" ] && unset GNUPGHOME || export GNUPGHOME="$gnupghome"
    fi
    success

    #%% Verify package shasum (dsc sha256sum)
    title "Veryify package shasum (dsc sha256sum)"
    shasum="$(shasum_file "$packageTar" 256)"
    checksum="sha256:$(grep -zoP "(?<=Sha256:\n ).*?(?= )" "$packageDsc" | head --bytes=-1)"
    info "package shasum" "$shasum"
    info "dsc shasum" "$checksum"
    [ "$shasum" = "$checksum" ] || error "keyring package verification failed"
    success

    #%% Extract keyring package
    title "Extract keyring package"
    info "path" "$packageDir"
    if [ -d "$packageDir"  ]; then
        info "package already extracted"
    else
        tar -xf "$package.tar.xz"
        if [ -d "$keyringDir/debian-archive-keyring" ]; then
            mv "$keyringDir/debian-archive-keyring" $packageDir
        fi
    fi
    success

    #-%% Verify keyring signature (remote sha256sum)
    ### api not stable
    # title "Veryify keyring signature (remote sha256sum)"
    # checksum="$(shasum_file "$keyring.asc" 256 "")"
    # request="$packageApi/sha256/?checksum=$checksum&package=$keyringName"
    # response="$packageDir.$keyringName.asc.sha256.json"
    # info "signature file" "$keyring.asc"
    # info "api request" "$request"
    # if [ -f "$response" ]; then
    #     info "sha256sum already fetched"
    # else
    #     wget -qO "$response" "$request"
    # fi
    # responseCount=$(grep -oP '(?<="count":).*?(?=,)' "$response" | head -1)
    # responseVersions=($(grep -oP '(?<="version":").*?(?=")' "$response"))
    # info "api results" "$responseCount"
    # if [ "$responseCount" -eq 0 ]; then
    #     [ -f "$response" ] && cat "$response" && rm "$response"
    #     error "keyring signature file not found"
    # fi
    # info "api versions" "${responseVersions[@]}"
    # grep -q "$version" <<< "${responseVersions[*]}" \
    #     || error "keyring signature verification failed"
    # success

    #%% Generate keyring (implies signature tests of package)
    title "Generate keyring"
    info "path" "$keyring"
    if [ -f "$keyring"  ]; then
        info "keyring already generated"
    else
        make --silent --directory="$packageDir" -j1
    fi
    success

    cd "$debootstrapDir"
fi


#------------------------------------------------------------------------------
#%% Generate rootfs
#------------------------------------------------------------------------------

title "Generate debootstrap rootfs"
info "path" "$rootfsDir"
if [ -d "$rootfsDir"  ]; then
    info "rootfs already generated"
else
    buildArgs=(
        --arch="$debianArch"
        --keyring="$keyring"
        --force-check-gpg
        --cache-dir="$cacheDir"
    )
    [ $variant ] && buildArgs+=( --variant="$variant" )
    [ $include ] && buildArgs+=( --include="$include" )
    [ $exclude ] && buildArgs+=( --exclude="$exclude" )
    "$debootstrapDir/upstream/debootstrap" "${buildArgs[@]}" "$suite" "$rootfsDir"
fi
rootfsChecksum="$(shasum_folder_tar "$rootfsDir" 256)"
info "rootfs shasum" "$rootfsChecksum"
success


#------------------------------------------------------------------------------
#%% Change ownership of artifacts
#------------------------------------------------------------------------------

title "Change ownership of artifacts"
paths=( "$keyringDir" "$cacheDir" "$buildDir" )
info "paths" "${paths[@]}"
info "uid" "$projectUser"
info "gid" "$projectGroup"
chown -R "$projectUser:$projectGroup" "${paths[@]}"
success
