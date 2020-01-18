#!/bin/bash -x
exec /usr/bin/time -p \
  ffmpeg -y \
  -i "$1" \
  -f mp4 \
  -movflags faststart \
  -vf bwdif=0:-1:1,scale=1280x720 \
  -c:v libx264 \
  -preset:v slow \
  -crf 22 \
  -c:a libfdk_aac \
  -b:a 192k \
  "$2"
