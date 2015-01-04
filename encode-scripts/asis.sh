#!/bin/bash
/usr/bin/time -p ffmpeg -y -i "$1" -f mp4 -vcodec libx264 -crf 24 -acodec libfaac -ac 2 -ar 48000 -ab 128k "$2"
