#!/usr/bin/env bash

# Run this script:
# $wget -O - https://raw.githubusercontent.com/<username>/<project>/<branch>/<path>/<file> | bash

function do_git() {
    cd
    if [ ! -d "bluetooth-repair" ]; then
        echo "Cloning bt-repair to $HOME/bluetooth-repair ..."
        git clone https://github.com/eberhab/bluetooth-repair.git
        cd "bluetooth-repair"
    else
        echo "Updating bt-repair in $HOME/bluetooth-repair ..."
        cd "bluetooth-repair"
        git pull
    fi
}

function do_config() {
    if [ ! -f "bt-repair.conf" ]; then
        echo
        echo "TODO: Adapt bt-repair.conf to your needs."
        cp bt-repair.conf.example bt-repair.conf
    fi
}

function do_devices() {
    if [[ $(wc -l <devices.txt) -le 1 ]]; then
        echo
        echo "TODO: Add your devices by MAC and name to devices.txt. Example:"
        cat devices.txt |awk '{ print "    " $0; }'
    fi
}

function do_cron() {
    echo
    if grep -q "bluetooth-repair" "/etc/crontab"; then
        echo "BT-repair already added to /etc/crontab:";
        cat /etc/crontab |grep bluetooth-repair |awk '{ print "    " $0; }'
    else
        echo "Adding the following line to your /etc/crontab for automatic device discovery on boot:"
        echo "   @reboot	$(whoami)	$HOME/bluetooth-repair/run_in_background.sh"
        echo "For debug purposes, consider adding the screen version:"
        echo "   @reboot	$(whoami)	$HOME/bluetooth-repair/run_in_screen.sh"
        sudo bash -c "echo \"@reboot	$(whoami)	$HOME/bluetooth-repair/run_in_background.sh\" >>/etc/crontab"
    fi
}

if [ $# -eq 0 ]; then
    do_git
    ./install.sh no-update
else
    do_config
    do_devices
    do_cron
    echo "Done. Reboot."
fi

