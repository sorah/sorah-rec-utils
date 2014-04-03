#!/bin/bash

# /usr/bin/time -p ffmpeg -i "$1" -f mp4 -vcodec libx264 -vpre libx264-hq-ts -aspect 16:9 -s 1280x720 -acodec libfaac -ac 2 -ar 48000 -ab 128k -threads 2 $1.720p.2.mp4 2>&1|tee 720p.log

# original 2446MB

# 720p - 2.085430 313MB
OUT=$(echo "$1"|sed -r -e 's/(\.(720p|1080p)\.mp4)?.ts$/.1080p.mp4/g')
#/usr/bin/time -p ffmpeg -i "$1" -f mp4 -vcodec libx264 -vpre libx264-hq-ts -aspect 16:9 -s 1280x720 -crf 24 -acodec libfaac -ac 2 -ar 48000 -ab 128k "$OUT"

# 1080p - 4.094855556 (728MB)
/usr/bin/time -p ffmpeg -i "$1" -f mp4 -vcodec libx264 -vpre libx264-hq-ts -bufsize 20000k -maxrate 25000k -acodec libfaac -ac 2 -ar 48000 -ab 128k -threads 2 "$OUT"

####

# 720p - 2.3 350MB
# /usr/bin/time -p ffmpeg -i "$1" -f mp4 \
#   -vcodec libx264 -vpre libx264-hq-ts \
#   -aspect 16:9 -s 1280x720 \
#   -bufsize 20000k -maxrate 25000k \
#   -acodec libfaac -ac 2 -ar 48000 -ab 128k \
#   -threads 2 $1.720p.2.mp4 2>&1|tee 720p.log

# 720p - 2.085430 313MB
# /usr/bin/time -p ffmpeg -i "$1" -f mp4 -vcodec libx264 -vpre libx264-hq-ts -aspect 16:9 -s 1280x720 -crf 24 -acodec libfaac -ac 2 -ar 48000 -ab 128k $1.720p.2.mp4 2>&1|tee 720p.log

# 720p - 2.210030556 (313MB)
# /usr/bin/time -p ffmpeg -i "$1" -f mp4 -vcodec libx264 -vpre libx264-hq-ts -aspect 16:9 -s 1280x720 -crf 24 -acodec libfaac -ac 2 -ar 48000 -ab 128k -threads 2 $1.720p.mp4 2>&1|tee -a 720p.log

