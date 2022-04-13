#!/usr/bin/env bash

# Start bluetooth-repair in a loop, so that it restarts if bluetoothctl crashes
# Assumes that bluetooth-repair is located in user's $HOME

cd ~/bluetooth-repair
while true; do
    ./bluetooth-repair.sh >/dev/null 2>&1
    sleep 5
done



