#!/bin/bash -x
exec /usr/bin/time -p \
  ffmpeg -y \
  -i "$1" \
  -f mp4 \
  -movflags faststart \
  -c:v libx264 \
  -preset slower \
  -crf 22 \
  -c:a libfdk_aac \
  -b:a 228k \
  "$2"
