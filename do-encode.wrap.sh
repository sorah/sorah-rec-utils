#!/bin/bash
while true; do
  ruby $(dirname $0)/do-encode.rb $*
  retval=$?
  if [ "_${retval}" != "_72" ]; then
    exit $retval
  fi
  echo "---"
done
