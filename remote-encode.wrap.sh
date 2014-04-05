#!/bin/bash
export BUNDLE_GEMFILE="$(dirname $0)/Gemfile"
while true; do
  bundle exec ruby $(dirname $0)/remote-encode.rb $*
  retval=$?
  if [ "_${retval}" != "_72" ]; then
    exit $retval
  fi
  echo "---"
done
