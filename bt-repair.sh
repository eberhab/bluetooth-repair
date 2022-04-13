#!/usr/bin/env bash

# https://github.com/eberhab/bluetooth-repair/
# Benjamin Eberhardt, 12 April 2022

# Parse the output of bluetoothctl to get a hook on newly discovered devices.
# * If a paired device is seen, we try to connect.
# * This is possibly more elegant than trying to forcefully connect to
#   all ever paired devices every 10 seconds.
# * If we see a device we own, but it is not yet paired, then pair it.
# * If a device repeatedly fails to connect, delete and re-pair it.

# This script has been tested with bluetoothctl v5.50 under
# Retropie 4.8 - Raspbian GNU/Linux 10 (buster)

LOGFILE="bt-repair.log"
CONFILE="bt-repair.conf"
DEVFILE="devices.txt"
GREY='\033[0;37m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

function logger() {
    # write to stdout, logfile, and external handler
    echo -e "[${BLUE}BAT${NC}] $1" |xargs
    echo $(date) "$1" >> $LOGFILE
    if $NOTIFY_EXTERNAL; then
        if ! [[ "$NOTIFY_HANDLER" = /* ]]; then
            # Need an absolute path
            NOTIFY_HANDLER=$PWD/$NOTIFY_HANDLER
        fi
        $NOTIFY_HANDLER "$1" 2>/dev/null
    fi
}

function logconsole() {
    # log to console
    #printf "[BAT] $*\r\n"
    echo -e "[${BLUE}BAT${NC}] $*"
}

function get_device_name() {
    # Get device name from the list of managed and paired devices
    # Prefer the user provided name from the list of managed devices over
    # the physcial device name.
    if ! [ -z  "$1" ]; then
        #cat $DEVFILE |grep $1 |cut -d " " -f 2-
        echo "${ALLMACS[@]}" |grep $1 |head -n1 |xargs |cut -d " " -f 2-
    fi
}

function dn() {
    # short version of get_device_name()
    get_device_name $1
}

function get_connect_count() {
    # get connect retry counter for every device since last reboot
    logconsole "Connect retry counts:"
    #grep . /tmp/count_*
    for k in "${!CCT[@]}"; do printf '%s: %s\n' "$k" "${CCT[$k]}"; done
}

function save_connect_count() {
    # lets write down how many times we already tried to connect to a device
    # remove/ re-pair the device if count exceeded
    max_tries=$CONNECT_RETRIES_UNTIL_REPAIR
    
    if ! [[ -v CCT[@] ]]; then
        #unset CCT
        declare -gA CCT # global associative array
    fi
    
    #file="/tmp/count_$1"
    #file="/dev/null"
    #if [ -f "$file" ]; then
    if [[ "${!CCT[@]}" =~ "$1" ]]; then
        #current_count=$(cat $file)
        current_count=CCT[$1]
        count=$(($current_count + 1))
        if [[ $count -gt $((max_tries - 1)) ]] && $AUTO_PAIRING; then
            logconsole "We have tried to connect to $(dn $1) more than $max_tries times."
            logger "Device $(dn $1) exceeded connect retry count ($max_tries). Removing device, so it can be re-paired."
            get_connect_count
            bt-device --remove $1
            #echo 0 > $file
            CCT[$1]=0
        else
            logger "  Connection attempt $count for $(dn $1)"
            #echo $count > $file
            CCT[$1]=$count
        fi
    else
        #echo 1 > $file
        CCT[$1]=1
    fi
}

function log_device_status() {
    # Check and log if device is connected.
    # Only do this if the count file exists, indicating that we were doing a manual re-connection.
    # Remove connection retry counter if it is connected.

    #countfile="/tmp/count_$1"
    #if [ -f "$countfile" ]; then
    if [[ "${CCT[$1]}" -gt 0 ]]; then
        if is_connected $1; then
            logger "  Successfully connected to $(dn $1)"
            #rm -f "$countfile"
            CCT[$1]=0
        else
            logger "  Could not connect to $(dn $1)"
        fi
    fi
}

function lock() {
    # If lockfile exists return true
    # If lockfile does not exist create one and return false
    lockfile="/tmp/btconnect_$1"
    if [ -f "$lockfile" ]; then
        logconsole "  Already connecting to $(dn $1)"
        true
    else
        touch "$lockfile"
        false
    fi
}

function unlock() {
    # remove lockfile
    lockfile="/tmp/btconnect_$1"
    sleep 5
    rm "$lockfile"
}

function cleanlock() {
    rm -f /tmp/btconnect_*
}

function agent_action() {
    # Report to log what the agent has to say
    if [[ "$*" =~ "PIN" ]]; then
        PIN=$(echo $* |cut -d ":" -f 2)
        logger "!! Please Enter PIN:$PIN !!"
    fi
    if [[ "$*" =~ "No agent" ]]; then
        logger "Could not initialize agent."
        # Consider restarting bluetooth and this script
        # systemctl restart bluetooth
        # kill $$
    fi
}

function btpair_with_agent() {
    # Start pairing with agent, so we can do keyboard pairing
    # https://www.kynetics.com/docs/2018/pairing_agents_bluez/
    # agent {KeyboardOnly, DisplayOnly, DisplayYesNo, KeyboardDisplay, KeyboardOnly, NoInputNoOutput, off, on}
    # Use a coprocess? https://unix.stackexchange.com/questions/86270/how-do-you-use-the-command-coproc-in-various-shells
    
    # How many seconds does a human have to react to a pin paring request
    GRACETIME=25
    logger "Starting an agent to pair with $(dn $1), be prepared to enter a code within ${GRACETIME}s..."
    { sleep 3; printf "pair $1\n\n"; sleep $GRACETIME; printf "quit\n\n"; } | bluetoothctl |\
        #tee $DEBUG |\
        while read -r; do
            logconsole "${REPLY}"
            #[[ "${REPLY}" =~ "PIN" ]] && logger "Agent debug: ${REPLY}";
            [[ "${REPLY}" =~ agent ]] && agent_action ${REPLY} && continue;
        done
}

function btctl() {
    # Run bluetoothctl and parse output
    logconsole "$ bluetoothctl -- $1 $2"
    bluetoothctl -- $1 $2 |\
        #tee $DEBUG |\
        while read -r; do
            logconsole "${REPLY}"
            #[[ "${REPLY}" =~ "Paired: yes" ]] && paired_device_action ${REPLY} && continue;
            #[[ "${REPLY}" =~ CHG ]] && change_device_action ${REPLY} && continue;
        done
}

function do_pair() {
    # pair with given device
    if ! $AUTO_PAIRING; then logger "Auto-pair disabled. Not pairing with $(dn $1)"; return; fi
    if [[ "$(dn $1)" =~ "$AUTO_PAIRING_BLACKLIST" ]]; then logger "Auto-pair disabled for \"$AUTO_PAIRING_BLACKLIST\". Not pairing with $(dn $1)"; return; fi
    if lock $1; then return; fi
    logconsole "Pairing with $(dn $1)..."
    save_connect_count $1
    #set -x
    if [[ "$(dn $1)" =~ "$AUTO_PAIRING_AGENT" ]]; then
        btpair_with_agent $1
    else
        btctl pair $1
    fi
    sleep 2
    btctl trust $1
    btctl connect $1
    #set +x
    sleep 2
    btctl info $1
    log_device_status $1
    unlock $1
}

function do_connect() {
    # connect to given device
    if lock $1; then return; fi
    save_connect_count $1
    touch /tmp/$1
    logconsole "Connecting to $(dn $1)..."
    btctl connect $1
    sleep 2
    log_device_status $1
    unlock $1
}

function convert_to_bool() {
    # convert int to bool: {0: false, >1: true} 
    if [[ $1 -gt 0 ]]; then
        true
    else
        false
    fi
}

function compile_known_devices() {
    # Read the managed device list and the list of paired devices into an array.
    if ! [[ -v ALLMACS[@] ]]; then
        #mapfile ALLMACS < $DEVFILE
        mapfile ALLMACS < <(cat $DEVFILE; bluetoothctl paired-devices |cut -d " " -f 2-)
        #{ cat $DEVFILE; bluetoothctl paired-devices |cut -d " " -f 2-; } | mapfile ALLMACS
        m=$(cat $DEVFILE |wc -l)
        p=$(bluetoothctl paired-devices |wc -l)
        logger "Reading list of $(echo "${ALLMACS[@]}" |wc -l) devices ($m managed, $p paired)."
        #bluetoothctl paired-devices
        for i in "${!ALLMACS[@]}"; do printf '%d %s' "$i" "${ALLMACS[i]}"; done
    fi
}

function is_own_device() {
    # Check if the device is one of our own. 
    found=$(echo "${ALLMACS[@]}" |grep $1 |wc -l)
    convert_to_bool $found
}

function is_paired() {
    # check if device is already paired 
    found=$(bluetoothctl paired-devices |grep $1 |wc -l)
    convert_to_bool $found
}

function is_connected() {
    # check if device is already connected
    connected=$(bluetoothctl -- info $1 |grep Connected |grep yes |wc -l)
    convert_to_bool $connected
}

function new_device_action() {
    # bluetoothctl finds a new device. Check if it is one of ours and connect/ pair if needed
    dev=$3
    #logconsole "NEW: $dev"
    if is_own_device $dev; then
        name=$(get_device_name $dev)
        logger "Found a NEW device we own: $name"
        if is_paired $dev; then
            logger "Device $name already paired, trying to connect..."
            do_connect $dev #&
        else
            logger "Trying to PAIR with $name..."
            do_pair $dev #&
        fi
    else
        logconsole "Not our device: $dev"
    fi
}

function disconnected_device_action() {
    # bluetoothctl looses a new device. Nothing to do.
    dev=$3
    #logconsole "LOST: $dev"
    true
    #if is_own_device $dev; then
    #    logger "Device $(dn $dev) has not yet connected/ disconnected."
    #fi
}

function lost_device_action() {
    # bluetoothctl looses a new device. Nothing to do.
    dev=$3
    #logconsole "LOST: $dev"
    if is_own_device $dev; then
        logger "Device $(dn $dev) has been purged."
    fi
}

function paired_device_action() {
    # bluetoothctl reports a paired device. Nothing to do.
    dev=$3
    #TODO: fix next line(s)
    logconsole "PAIRED: $*"
    logger "Device $(dn $dev) has been PAIRED."
}

function change_device_action() {
    # bluetoothctl sees action from a device. Check if it is one of ours and connect/ pair if needed.
    # We trigger on "CHG" also, in case we missed the "NEW" event.
    #echo "ARGS: $(echo $* |xargs)"
    dev=$3
    #logconsole "CHG: $dev"
    if is_own_device $dev; then
        name=$(get_device_name $dev)
        if is_paired $dev; then
            if ! is_connected $dev; then
                logger "Device $name is paired and available. Connecting..."
                do_connect $dev #&
            else
                log_device_status $dev
            fi
        else
            logger "Trying to PAIR with $name..."
            do_pair $dev #&
        fi
    #else
    #logconsole "Not our device: $dev"
    fi
}

function ctrl_c() {
    # Kill the main process and the syslog tail if it exists
    arg="-u"
    logconsole "** Trapped CTRL-C"
    logconsole "Killing [$$] - $(ps -p $$ $arg 2>&1|grep $$ |xargs)"
    if ! [ -z ${TAILPID+x} ]; then
        logconsole "Killing [$TAILPID] - $(ps -p "$TAILPID" $arg 2>&1|grep "$TAILPID" |xargs)"
        kill $TAILPID
    fi
    set -x
    kill $$ # -s SIGINT
    set +x
}

function in_game() {
    # if we are in a game and $DO_NOT_SCAN_INGAME is true
    # then return true, else return false
    # This function is tailored to retropi's runcommand process
    RC=$(ps aux |grep runcommand |wc -l)
    if [[ $RC -gt 1 ]] && DO_NOT_SCAN_INGAME; then
        logconsole "We are in a game. Not scanning!"
        exit
        true
    else
        logconsole "Not in a game. Start scanning..."
        false
    fi
}

function get_syslog() {
    # Lets get some syslog from bluetooth and joycond along with autoconnect log.
    # Let's launch tail to background, we want its output, but non-blocking.
    # We use a trick to save the PID, so we can later kill it:
    # https://stackoverflow.com/questions/1652680/how-to-get-the-pid-of-a-process-that-is-piped-to-another-process-in-bash
    SGREY='\o033[0;37m'
    SNC='\o033[0m' # No Color
    if $SHOW_SYSLOG; then
        ( tail -n0 -F /var/log/syslog & echo $! >&3 ) 3>/tmp/pid |\
            grep --line-buffered "bluetooth\|joycond" |\
            stdbuf -oL cut -d " " -f 5- |\
            #sed --unbuffered "s/^/[${SGREY}LOG${SNC}] /" &
            sed --unbuffered "s/.*/${SGREY}[LOG] &${SNC}/" &
        #TAILPID=$!
        TAILPID=$(</tmp/pid)
    fi
}

function startup_check() {
    # need to find out if/ when bluetoothd is ready and available. Block until then
    logconsole "Starting up."
    if [ ! -f $DEVFILE ]; then
        echo "00:00:00:00:00:00 Example device please delete" > $DEVFILE
        logconsole "Creating a new sample managed devices file $DEVFILE."
    fi
    while true; do
        RESULT=$({ printf "scan on\n\n"; printf "quit\n\n"; } | bluetoothctl)
        if [[ "${RESULT}" =~ "No default controller available" ]]; then
            logconsole "Bluetooth not ready ($(awk '{print $1}' /proc/uptime)s)..."
            #echo "${RESULT}" | xargs
            sleep 5
        else
            #echo "${RESULT}" | xargs
            compile_known_devices
            break
        fi
    done
}

function shutdown_check() {
    while ! systemctl status bluetooth >/dev/null; do
        sudo systemctl start bluetooth
        sleep 60
    done
}

function run_main_loop() {
    # Run bluetoothctl in scan mode and parse its output line by line
    
    if $SHOW_BLUETOOTHCTL_OUTPUT; then
        DEBUG=/dev/stderr
    else
        DEBUG=/dev/null
    fi

    get_syslog    # get bluetooth and joycond info from syslog
    startup_check # Block until bluetoothd is ready
    logger "--- Running version $VERSION - $(hostname) - $(date) ---"
    cleanlock     # Clean orphaned lock files from previous run
    in_game       # Check if we are in a game
    
    # Run bluetoothctl in scan mode, disable stdout buffer
    stdbuf -oL bluetoothctl -- scan on |\
        #grep --line-buffered -v "RSSI" |\
        grep --line-buffered -E "NEW|DEL|CHG|agent" |\
        tee $DEBUG |\
        while read -r; do
            #logconsole "${REPLY}"
            [[ "${REPLY}" =~ "Connected: no" ]] && disconnected_device_action ${REPLY} && continue;
            [[ "${REPLY}" =~ "ServicesResolved: no" ]] && continue;
            [[ "${REPLY}" =~ "Paired: yes" ]] && paired_device_action ${REPLY} && continue;
            [[ "${REPLY}" =~ agent ]] && agent_action ${REPLY} && continue;
            [[ "${REPLY}" =~ DEL ]] && lost_device_action ${REPLY} && continue;
            [[ "${REPLY}" =~ NEW ]] && new_device_action ${REPLY} && continue;
            [[ "${REPLY}" =~ CHG ]] && change_device_action ${REPLY} && continue;
        done
        
    shutdown_check
}

##### Main #####

cd "$(dirname "$0")"
trap ctrl_c INT

if [ ! -f "$CONFILE" ]; then
    cp $CONFILE.example $CONFILE
    logger "Please adapt $CONFILE to your needs."
fi

source $CONFILE
run_main_loop
