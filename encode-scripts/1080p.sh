#!/bin/bash
/usr/bin/time -p ffmpeg -y -i "$1" -deinterlace -f mp4 -vcodec libx264 -vpre libx264-hq-ts -bufsize 20000k -maxrate 25000k -acodec libfaac -ac 2 -ar 48000 -ab 128k -threads 4 "$2"
