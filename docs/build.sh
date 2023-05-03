#!/usr/bin/env bash
# For copyright and license terms, see LICENSE.txt (top level of repository)
# Repository: https://github.com/timegrid/debian-image-builder
#
#% Usage: ./build.sh
#%
#%   Renders the README.rst to HTML, includes the usage output of scripts.

set -eu

# Project
scriptDir="$(dirname "$(readlink -vf "$0")")"
source "$scriptDir/.project.sh" \
       -- "$@"
debuerreotypeDir="$debuerreotypeDir"
debootstrapDir="$debootstrapDir"
aptcacherngDir="$aptcacherngDir"
dockerDir="$dockerDir"
libvirtDir="$dockerDir"

# Paths
docsDir="$(dirname "$(readlink -vf "$BASH_SOURCE")")"
projectDir="$(dirname "$scriptDir")"
usageRst="$docsDir/usages.rst"


#------------------------------------------------------------------------------
#%% Generate script usages
#------------------------------------------------------------------------------

scripts=(
    build.sh
    clean.sh

    scripts/apt-cacher-ng/build.sh
    scripts/apt-cacher-ng/start.sh
    scripts/apt-cacher-ng/stop.sh
    scripts/apt-cacher-ng/clean.sh

    scripts/debootstrap/build.sh
    scripts/debootstrap/clean.sh

    scripts/debuerreotype/bootstrap.sh
    scripts/debuerreotype/build.sh
    scripts/debuerreotype/clean.sh

    scripts/docker/build.sh
    scripts/docker/clean.sh

    scripts/libvirt/build.sh
    scripts/libvirt/create_domain.sh
    scripts/libvirt/create_image.sh
    scripts/libvirt/create_network.sh
    scripts/libvirt/create_pool.sh
    scripts/libvirt/create_volume.sh
    scripts/libvirt/clean.sh

    .project.sh
)
> "$usageRst"
for script in "${scripts[@]}"; do
    title=${script#scripts/}
    echo "$title" >> "$usageRst"
    printf "'%.0s" $(seq 1 ${#title}) >> "$usageRst"
    echo >> "$usageRst"
    echo >> "$usageRst"
    echo "::" >> "$usageRst"
    echo >> "$usageRst"
    readarray -t usage <<< "$("$projectDir/$script" --colorless --help)"
    for line in "${usage[@]}"; do
        echo "    $line" >> "$usageRst"
    done
    echo >> "$usageRst"
done


#------------------------------------------------------------------------------
#%% Generate docs
#------------------------------------------------------------------------------

rst2html --stylesheet="$docsDir/style.css" "$projectDir/README.rst" "$docsDir/README.html"
