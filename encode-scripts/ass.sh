#!/bin/bash
set -e
set -x

assdumper "$1" > "$2".raw

du -b "$2".raw
if [ ! -s "$2".raw ]; then
  rm "$2".raw
  ln -sv /dev/null "$2"
  exit 0
fi

rm -fv "$2"
"$(dirname $0)/assadjust.rb" "$1" "$2".raw > "$2"
rm -v "$2".raw

