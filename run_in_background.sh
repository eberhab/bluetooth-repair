#!/usr/bin/env bash

# Start bluetooth-repair in a loop, so that it restarts if bluetoothctl crashes
# Assumes that bluetooth-repair is located in user's $HOME

cd ~/bluetooth-repair
while true; do
    ./bt-repair.sh >/dev/null 2>&1 &
    wait
    sleep 5
done



