#!/usr/bin/env bash

# Run this script:
# $ wget -O - https://raw.githubusercontent.com/eberhab/bluetooth-repair/master/install.sh | bash

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
    echo
    if [[ $(wc -l <devices.txt) -le 1 ]]; then
        echo "TODO: Add your devices by MAC and name to devices.txt. Example:"
    else
        echo "Done. You have $(wc -l <devices.txt) registered devices:"
    fi
    cat devices.txt |awk '{ print "    " $0; }'
}

function do_cron() {
    echo
    if grep -q "bluetooth-repair" "/etc/crontab"; then
        echo "Done. BT-repair already added to /etc/crontab:";
        cat /etc/crontab |grep bluetooth-repair |awk '{ print "    " $0; }'
    else
        echo "Adding the following line to your /etc/crontab for automatic device discovery on boot:"
        echo "    @reboot	$(whoami)	$HOME/bluetooth-repair/run_in_background.sh"
        echo "For debug purposes, consider adding the screen version:"
        echo "    @reboot	$(whoami)	$HOME/bluetooth-repair/run_in_screen.sh"
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
    echo
    echo "Done. After adjusting the config files please reboot to start bt-repair via cron."
fi

