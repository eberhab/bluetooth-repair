#!/usr/bin/env bash

# Start bluetooth-repair in a loop, so that it restarts if bluetoothctl crashes
# Assumes that bluetooth-repair is located in user's $HOME
# Start bluetooth-repair in a screen named "bluetooth", so that we can have a look at what it is doing in case we need to.

if ! screen -list | grep -q "bluetooth"; then
  screen -a -A -d -m -S bluetooth -t bash bash
  screen -S bluetooth -X screen -t syslog tail -F /var/log/syslog
  screen -S bluetooth -X screen -t bt-log tail -F ~/bluetooth-repair/bluetooth-repair.log
  screen -S bluetooth -X screen -t bt-repair bash
  screen -S bluetooth -p bt-repair -X stuff $'cd ~/bluetooth-repair\nwhile true; do ./bt-repair.sh; sleep 5; done\n\n'
fi
screen -S bluetooth -rd

