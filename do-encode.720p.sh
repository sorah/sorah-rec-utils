#!/bin/bash

OUT=$(echo "$1"|sed -r -e 's/(\.(720p|1080p)\.mp4)?.ts$/.720p.mp4/g')
/usr/bin/time -p ffmpeg -i "$1" -f mp4 -vcodec libx264 -vpre libx264-hq-ts -aspect 16:9 -s 1280x720 -crf 24 -acodec libfaac -ac 2 -ar 48000 -ab 128k "$OUT"
