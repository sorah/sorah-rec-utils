#!/bin/bash
while true; do
  ruby $(dirname $0)/do-encode.rb $*
  retval=$?
  if [ "_$?" != "_72" ]; then
    exit $?
  fi
  echo "---"
done
