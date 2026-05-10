#!/usr/bin/env bash
session_id=$(ls -t ~/.augment/sessions | head -n 1| sed 's/.json//;s/ *//')
echo "AUGGIE_SESSION_ID=${session_id}"
