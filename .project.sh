#!/usr/bin/env bash
# For copyright and license terms, see LICENSE.txt (top level of repository)
# Repository: https://github.com/timegrid/debian-image-builder
#
#% Usage: source .project OPTIONS -- "$@"
#%
#%   Project configuration script to source across multiple bash modules.
#%   Provides:
#%   - a central spot for project scope variables/functions
#%   - a getopt parser, preparing the options for the target script
#%   - an usage function, which parses/prints the comments of the target script
#%   - several output functions for consistent, colored userfeedback
#%   - requirement flags for root user and user confirmation
#%
#% Source Options:
#%   --short=OPTIONS*        short option list for getopt, required
#%   --long=OPTIONS*         long option list for getopt, required
#%   --root                  require root user to run the script
#%   --confirm               require user confirmation before execution
#%
#% Target Options:
#%   -h, --help              print usage
#%   -y, --yes               autoconfim, if --confirm was requested
#%       --colorless         omit colors for CI usage
#%
#% Output Functions:
#%   usage()                 prints usage and exits
#%                             $1: message to print (default: none)
#%                             $2: exit code (default: 0)
#%                             $3: script to parse (default: sourcing script)
#%                             $4: usage text (default: parsed #% comments)
#%   title()                 prints a title
#%                             $1: content
#%   info()                  prints an info message
#%                             $1: content (e.g. info "infotext") OR
#%                             $1: label, $2: content
#%                                 (e.g. info "key" "$value") OR
#%                             $1: label, ${@:2}: list
#%                                 (e.g. info "key" "${values[@]-}")
#%   warning()               prints a warning message
#%                             $1: content
#%   success()               prints a success message (default: 'done')
#%                             $1: content
#%   error()                 prints an error message
#%                             $1: content (default: 'unkown error')
#%                             $2: exit code (default: 1)
#%   line()                  prints a full terminal width line
#%                             $1: char to print (default: '-')
#%                             $2: key in $color (default: 'dim')
#%
#% Auxiliary Functions:
#%   join_by()               joins its args with a separator
#%                             (e.g. join_by , "$array[@]")
#%                             $1: separator
#%                             $*: items
#%
#% Project Variables:
#%   projectDir              absolute path to the direcory of the .project.sh script
#%   projectName             name of the direcory of the .project.sh script
#%   projectUser             uid of the directory of the .project.sh file
#%   projectGroup            gid of the directory of the .project.sh file
#%
#% Application Variables:
#%   debootstrapDir          absolute path to the directory of debootstrap scripts
#%                             envvar: DEBOOTSTRAP_DIR
#%   debuerreotypeDir        absolute path to the directory of debuerreotype scripts
#%                             envvar: DEBUERREOTYPE_DIR
#%   aptcacherngDir          absolute path to the directory of apt-cacher-ng scripts
#%                             envvar: APTCACHERNG_DIR
#%   dockerDir               absolute path to the directory of docker scripts
#%                             envvar: DOCKER_DIR
#%   libvirtDir              absolute path to the directory of libvirt scripts
#%                             envvar: LIBVIRT_DIR
#%   ansibleDir              absolute path to the directory of ansible scripts
#%                             envvar: ANSIBLE_DIR
#%
#%   debianArch              architecture of debian builds (default: amd64)
#%                             envvar: DEBIAN_ARCH
#%   debianTimestamp         default timestamp for debian snapshots
#%                             (default: 2023-04-26T00:00:00Z)
#%                             envvar: DEBIAN_TIMESTAMP
#%   debianVersions          associative array of debian codenames to version
#%
#% Application Functions:
#%   shasum_file()           calculate shasum of a file (e.g. keyfile, rootfs.tar)
#%                             $1: path to file
#%                             $2: algorithm to use (default: 256)
#%                             $3: prefix (default: shaALG, "" to unset)
#%   shasum_folder_tar()     calculate shasum of a folder as tar (e.g. rootfs)
#%                             $1: path to folder
#%                             $2: algorithm to use (default: 256)
#%                             $3: prefix (default: shaALG, "" to unset)
#%   shasum_tarxz_tar()      calculate shasum of a tar.xz as tar (e.g. rootfs.tar.gz)
#%                             $1: path to tar.gz
#%                             $2: algorithm to use (default: 256)
#%                             $3: prefix (default: shaALG, "" to unset)
#%   sha256_docker_layer0()  fetches sha256sum of the first layer of a docker image
#%                             $1: image name
#%

set -eu

#------------------------------------------------------------------------------
#%% Define project variables
#------------------------------------------------------------------------------

# Project
projectDir="$(dirname "$(readlink -vf "$BASH_SOURCE")")"
projectName="$(basename "$projectDir")"
projectUser="$(stat --format '%u' "$projectDir")"
projectGroup="$(stat --format '%g' "$projectDir")"


#------------------------------------------------------------------------------
#%% Define application specific variables/functions
#------------------------------------------------------------------------------

# Paths
debootstrapDir="${DEBOOTSTRAP_DIR:-"$projectDir/scripts/debootstrap"}"
debuerreotypeDir="${DEBUERREOTYPE_DIR:-"$projectDir/scripts/debuerreotype"}"
aptcacherngDir="${APTCACHERNG_DIR:-"$projectDir/scripts/apt-cacher-ng"}"
dockerDir="${DOCKER_DIR:-"$projectDir/scripts/docker"}"
libvirtDir="${LIBVIRT_DIR:-"$projectDir/scripts/libvirt"}"
ansibleDir="${ANSIBLE_DIR:-"$projectDir/scripts/ansible"}"

# Application
debianArch="${DEBIAN_ARCH:-amd64}"
debianTimestamp="${DEBIAN_TIMESTAMP:-2023-06-20T00:00:00Z}"
declare -A debianVersions=(
    [woody]=3
    [etch]=4
    [lenny]=5
    [squeeze]=6
    [wheezy]=7
    [jessie]=8
    [stretch]=9
    [buster]=10
    [bullseye]=11
    [bookworm]=12
)

# Calculate shasum of stdin input
shasum_stdin() {
    local algorithm=${1:-256} prefix= shasum=
    prefix="${2-"sha$algorithm:"}"
    shasum="$(shasum -a "$algorithm" - < /dev/stdin | cut -d' ' -f1)"
    [ "$shasum" ] && echo "$prefix$shasum" || echo
}

# Calculate shasum of an array (e.g. shasum_args "${array[@]}")
sha256_array() {
    local shasum= sorted=
    IFS=$'\n' sorted="$(sort <<< "$*")"; unset IFS
    echo "$sorted" | shasum_stdin 256
}

# Calculate shasum of a file (e.g. keyfile, rootfs.tar)
shasum_file() {
    local path="$1" algorithm=${2:-256} prefix= shasum=
    prefix="${3-"sha$algorithm:"}"
    [ -f "$path" ] && shasum="$(shasum -a "$algorithm" "$path" | cut -d' ' -f1)"
    [ "$shasum" ] && echo "$prefix$shasum" || echo
}

# Calculate shasum of a folder as tar (e.g. debootstrap rootfs)
shasum_folder_tar() {
    local path="$1" algorithm=${2:-256} prefix= shasum=
    prefix="${3-"sha$algorithm:"}"
    [ -d "$path" ] && shasum="$(tar -cC "$path" . | shasum -a "$algorithm" - | cut -d' ' -f1)"
    [ "$shasum" ] && echo "$prefix$shasum" || echo
}

# Calculate shasum of a tar.xz as tar (e.g. rootfs.tar.xz)
shasum_tarxz_tar() {
    local path="$1" algorithm=${2:-256} prefix= shasum=
    prefix="${3-"sha$algorithm:"}"
    [ -f "$path" ] && shasum="$(xz -cd "$path" | shasum -a "$algorithm" - | cut -d' ' -f1)"
    [ "$shasum" ] && echo "$prefix$shasum" || echo
}

# Calculate sha256sum of a qcow2 filesystem as tar (e.g. libvirt image)
# Applies the same deterministic tarball generation as debuerreotype,
# see ./scripts/debuerreotype/upstream/scripts/debuerreotype-tar.sh
shasum_qcow2_tar() {
    local path="$1" algorithm=${2:-256} shasum=
    prefix="${3-"sha$algorithm:"}"

    # Create a temporary directory
    local tmpDir="$(mktemp --directory --tmpdir "$projectName.qcow2_tar_sha256.XXXXXXXXXX")"
    trap "$(printf 'rm -rf %q' "$tmpDir")" EXIT

    # Create a rootfs folder with correct timestamp
    local epoch="$(date -r "$1" +%s)"
    mkdir "$tmpDir/rootfs"
    touch --no-dereference --date="@$epoch" "$tmpDir/rootfs"

    # Export/Extract filesystem from qcow2 and create a deterministic tarball
    virt-tar-out -a "$path" / "$tmpDir/rootfs.indeterministic.tar"
    tar --extract --file "$tmpDir/rootfs.indeterministic.tar" --directory "$tmpDir/rootfs"
    tar --create --file "$tmpDir/rootfs.deterministic.tar" --auto-compress \
        --directory "$tmpDir/rootfs" --exclude "lost+found" --numeric-owner \
        --transform 's,^./,,' --sort name .

    # Calculate shasum
    shasum="$(shasum -a "$algorithm" "$tmpDir/rootfs.deterministic.tar" | cut -d' ' -f1)"
    [ "$shasum" ] && echo "$prefix$shasum"
}

# Calculate shasum of the first layer of a docker image
sha256_docker_layer0() {
    docker image inspect --format "{{index (.RootFS.Layers) 0}}" "$1" 2> /dev/null | cat
}


#------------------------------------------------------------------------------
#%% Define output functions
#------------------------------------------------------------------------------

declare -A color=(
    [reset]="\033[0m"
    [bold]="\033[1m"
    [dim]="\033[2m"
    [underline]="\033[4m"
    [blink]="\033[5m"
    [invert]="\033[7m"

    [title]="\033[33m"
    [subtitle]="\033[35m"
    [label]="\033[94m"
    [info]="\033[37m"
    [success]="\033[32m"
    [warning]="\033[33m"
    [error]="\033[91m"
)

# Parse the script and outputs all lines starting with `#%`. On exit code 0,
# append "Process:" and all lines starting with `#%%` as bullet list.
# Works with intendation as well.
usage() {
    local message="${1-}" exit="${2:-0}" script="${3:-"$0"}" omit="${4-}"
    local comments="$(sed -n '/^ *#%/,/^$/s/^\( *\)#% \{0,1\}/\1/p' "$script")"
    [ "$message" ] && echo -e "$0: $message\n"
    [ ! "$omit" ] && sed -n "/^ *%/!p" <<< $comments && echo
    if [ $exit -le 0 ]; then
        echo -ne "${color[dim]-}"
        [ ! "$omit"] && echo -e "Process:"
        sed -n "s/^\( *\)% \{0,1\}/\1- /p" <<< $comments
        echo -ne "${color[reset]-}"
    fi
    if [ $exit -ge 0 ]; then exit $exit; fi
} 2>/dev/null
[ "$0" = "$BASH_SOURCE" ] && usage "" 0 "$BASH_SOURCE"

# Output
title() {
    local content="$1" path="$(readlink -vf "$0" | rev | cut -d'/' -f-2 | rev)"
    echo
    line
    echo -ne "${color[bold]-}${color[title]-}>${color[reset]-} "
    echo -e  "${color[title]-}$content ...${color[reset]-}"
    echo -e  "${color[subtitle]-}${color[dim]-}  ./$path${color[reset]-}"
}
info() {
    local content= label=
    case $# in
        1) content="$1"                          ;;
        2) content="$2" label="$1"               ;;
        *) label="$1"
           printf -v content "\n  - %s" "${@:2}" ;;
    esac
    echo -n "  "
    [ "$label" ] && echo -ne "${color[label]-}$label${color[reset]-}: ${color[dim]-}"
    echo -ne "${color[info]-}$content${color[reset]-}"
    [ ! "$label" ] && echo -n "."
    echo
}
warning() {
    local content="$1"
    echo -n "  "
    echo -ne "${color[bold]-}${color[warning]-}warning:${color[reset]-} "
    echo -e "${color[warning]-}$content.${color[reset]-}"
}
success() {
    local content="${1:-done}"
    echo -n "  "
    echo -e "${color[success]-}$content.${color[reset]-}"
}
error() {
    local content="${1:-"unkown error"}" exit="${2:-1}"
    echo -n "  "
    echo -ne "${color[bold]-}${color[error]-}ERROR:${color[reset]-} "
    echo -e "${color[error]-}$content.${color[reset]-}"
    if [ $exit -ge 0 ]; then exit $exit; fi
}
line() {
    local char="${1:--}" colorkey="${2:-dim}"
    echo -ne "${color[$colorkey]-}"
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' "$char"
    echo -ne "${color[reset]-}"
}


#------------------------------------------------------------------------------
#%% Define auxiliary functions
#------------------------------------------------------------------------------

# Join arguments with a separator
join_by() {
    local d=${1-} f=${2-}
    if shift 2; then
        printf %s "$f" "${@/#/$d}"
    fi
}


#------------------------------------------------------------------------------
#%% Parse options
#------------------------------------------------------------------------------

# Parse the source options first, including the short/long options for
# getopt of the target script and a root flag options to ensure a root user
# running the target script. Then parse the target script, handle the
# `--help` flag and set the getopt options for the target script.
options="$(getopt -n "$BASH_SOURCE" -o "+" -l 'short:,long:,root,confirm' -- "$@")" \
        || usage "" 1 "$BASH_SOURCE"
options() {
    #%% Source options
    eval "set -- $options"
    local short= long= root=false confirm=false
    while true; do
        case "$1" in
            --short)     short+="$2"  ; shift 2 ;;
            --long)      long+="$2"   ; shift 2 ;;
            --root)      root=true    ; shift   ;;
            --confirm)   confirm=true
                         short+="y"
                         long+=",yes" ; shift   ;;
            --) shift; break ;;
            *)  usage "ERROR - unkown flag '$1'." 1 "$BASH_SOURCE" ;;
        esac
    done
    shift $((OPTIND-1))
    #%% Target options
    local arguments=()
    for argument in "$@"; do
        case "$argument" in
                --colorless) color=()      ;;
           -y | --yes)       confirm=false ;;
           *) arguments+=( "$argument" )   ;;
        esac
    done
    for argument in "$@"; do
        case "$argument" in
           -h | --help)      usage         ;;
           *) ;;
        esac
    done
    options="$(getopt -n "$0" -o "$short" -l "$long" -- "${arguments[@]}")" || usage "" 1
    #%% Ensure root on --root flag
    if $root && [ $UID -ne 0 ]; then
        echo "Please run this script as root."
        exit 1
    fi
    #%% Ask to continue on --ask flag
    if $confirm; then
        local path="$(readlink -vf "$0" | rev | cut -d'/' -f-2 | rev)"
        echo
        line ">"
        echo -e "${color[underline]-}${color[title]-}./$path${color[reset]-} "
        usage "" -1 "$0" 1
        line ">"
        read -p "Continue (Y/n)?" confirmation
        case "$confirmation" in
          n|N ) echo "$0: aborted."; exit 1; ;;
        esac
    fi
}
options; eval "set -- $options"; unset options; unset -f options
