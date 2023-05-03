#!/usr/bin/env bash
# For copyright and license terms, see LICENSE.txt (top level of repository)
# Repository: https://github.com/timegrid/debian-image-builder
#
#% Usage: ./start [OPTIONS]
#%
#%   Runs an apt-cacher-ng docker container in the background.
#%
#%   For statistics open `localhost:3142/acng-report.html`
#%   Server configuration via
#%   - Apt configuration in /etc/apt/apt.conf.d/00aptproxy:
#%       Acquire::http::Proxy "http://172.17.0.2:3142";
#%   - Server configuration via http_proxy envvar:
#%       ip="$(docker exec apt-cacher-ng sh -c "hostname --ip-address")"
#%       export http_proxy="http:/$ip:3142"
#%
#% Options:
#%   -H, --host=NAME       host (default: 0.0.0.0)
#%   -p, --port=NAME       port (detault: 3142)
#%   -u, --uid=UID         uid of apt-cacher-ng user
#%   -g, --gid=GID         gid of apt-cacher-ng group
#%
#%       --cache-dir=PATH  cache directory, default: './cache'
#%       --log-dir=PATH    log directory, default: './log'
#%
#%   -h, --help              display this help
#%       --colorless         omit colors

set -eu

# Project
scriptDir="$(dirname "$(readlink -vf "$0")")"
source "$scriptDir/.project.sh" \
       --short "H:p:u:g:" \
       --long  "host:,port:,uid:,gid:,\
                cache-dir:,log-dir:" \
       -- "$@"
aptcacherngDir="$aptcacherngDir"

# Options
host=0.0.0.0
port=3142
uid=${projectUser:-1000}
gid=${projectGroup:-1000}
cacheDir="$aptcacherngDir/cache"
logDir="$aptcacherngDir/log"
while true; do
    case "$1" in
       -H | --host)       host="$2"      ; shift 2 ;;
       -p | --port)       port="$2"      ; shift 2 ;;
       -u | --uid)        uid="$2"       ; shift 2 ;;
       -g | --gid)        gid="$2"       ; shift 2 ;;
            --cache-dir)  cacheDir="$2"  ; shift 2 ;;
            --log-dir)    logDir="$2"    ; shift 2 ;;

       --) shift; break ;;
       *)  usage "ERROR: unknown flag '$1'." 1 ;;
    esac
done

#------------------------------------------------------------------------------
#%% Build an apt-cacher-ng docker image
#------------------------------------------------------------------------------

$aptcacherngDir/build.sh


#------------------------------------------------------------------------------
#%% Start an apt-cacher-ng docker service
#------------------------------------------------------------------------------

title "Start an apt-cacher-ng docker service"
if [ ! -z "$(docker ps -f "name=apt-cacher-ng" -f "status=running" -q)" ]; then
    info "service already running"
else
    runArgs=(
        --name apt-cacher-ng
        --init
        --detach
        --restart=always
        --pull=never
        --publish "$host:$port":3142
        --env "UID=$uid"
        --env "GID=$gid"
        # --user "$user:$group"
        --volume "$cacheDir:/var/cache/apt-cacher-ng"
        --volume "$logDir:/var/log/apt-cacher-ng"
        apt-cacher-ng
    )
    docker run "${runArgs[@]}" 1> /dev/null
fi
success
