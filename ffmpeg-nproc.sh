#!/bin/bash
if [[ -z $ENCODE_THREADS ]]; then
  expr "$(nproc)" / 2 + "$(nproc)"
else
  echo $ENCODE_THREADS
fi
