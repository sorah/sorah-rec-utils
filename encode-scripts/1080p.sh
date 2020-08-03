#!/bin/bash -x
exec /usr/bin/time -p \
  ffmpeg -y \
  -threads $("$(dirname $0)/../ffmpeg-nproc.sh") \
  -i "$1" \
  -f mp4 \
  -movflags faststart \
  -vf bwdif=0:-1:1,scale=1920x1080 \
  -c:v libx264 \
  -preset:v slow \
  -crf 22 \
  -c:a libfdk_aac \
  -b:a 228k \
  "$2"
