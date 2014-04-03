#!/bin/sh

if [ ! -d "$1" ]; then
  echo "abunai"
  exit 1
fi
xargs -I __foo__ -- sh -c 'ls -1 __foo__*'|xargs -I __bar__ mv __bar__ "$1"
