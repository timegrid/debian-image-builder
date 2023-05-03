#!/bin/bash
folders=(
    /run/apt-cacher-ng
    /var/cache/apt-cacher-ng
    /var/log/apt-cacher-ng
)
mkdir -p "${folders[@]}"
chmod -R 0755 "${folders[@]}"
chown -R $UID:$GID "${folders[@]}"
chown -R $UID:$GID /etc/apt-cacher-ng
usermod -u $UID apt-cacher-ng &> /dev/null
groupmod -g $GID apt-cacher-ng &> /dev/null

# allow arguments to be passed to apt-cacher-ng
if [[ ${1:0:1} = '-' ]]; then
  EXTRA_ARGS="$@"
  set --
elif [[ ${1} == apt-cacher-ng || ${1} == $(command -v apt-cacher-ng) ]]; then
  EXTRA_ARGS="${@:2}"
  set --
fi

# default behaviour is to launch apt-cacher-ng
if [[ -z ${1} ]]; then
  exec start-stop-daemon --start --chuid "$UID:$GID" \
      --exec "$(command -v apt-cacher-ng)" -- -c /etc/apt-cacher-ng ${EXTRA_ARGS}
else
  exec "$@"
fi
