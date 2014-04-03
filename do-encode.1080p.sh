#!/bin/bash

OUT=$(echo "$1"|sed -r -e 's/(\.(720p|1080p)\.mp4)?.ts$/.1080p.mp4/g')
/usr/bin/time -p ffmpeg -i "$1" -deinterlace -f mp4 -vcodec libx264 -vpre libx264-hq-ts -bufsize 20000k -maxrate 25000k -acodec libfaac -ac 2 -ar 48000 -ab 128k -threads 4 "$OUT"

