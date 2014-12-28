#!/bin/sh

if [ -e "$1" -a ! -d "$1" ]; then
  echo "abunai"
  exit 1
fi

if [ ! -e "$1" ]; then
  echo "creating directory"
  mkdir -p $1
  retval=$?
  if [ "_$retval" != "_0" ]; then
    echo "!?"
    exit $retval
  fi
fi

xargs -I __foo__ -- sh -c "ls -1 '__foo__'"|xargs mv -t "$1"
