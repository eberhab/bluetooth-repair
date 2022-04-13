# bluetooth-repair

A bluetooth auto-re-pair daemon based on bluetoothctl

Bt-repair continously monitors bluetoothctl for owned devices within range. Owned devices are defined based on a simple, user managed text file. If an owned devices is seen, bt-repair tries to connect a given number of times. If connect repeatedly fails, it will then delete the bluetooth device and attempt to pair it again.

This can be useful in different circumstances:
* Game controllers which are being used with more than one device might need to be re-paired after they had been connected to a different console. In my case this would be Nintendo Pro Controllers being alternatingly used with a Retropie and a Switch.
1. * "Have you tried turning it off an on again?". Sometimes bluetooth just repeatedly fails to connect to a paired device for unknown reason(s). Instead of having to delete the device by hand and pair it again manually, bt-repair can do it for you. This is especially helpful if e.g. the BT device/ controller in question is the only input device available/ to be used with the console.

# Features

* Auto connect to paired bluetooth devices once they are seen
* Automatically delete and re-pair owned bluetooth devices if auto connect fails repeatedly
* Forward pairing agent messages to an external handler, to e.g. receive a keyboard pairing code on a phone

# Installation

* Install with
```bash
$ wget -O - https://raw.githubusercontent.com/eberhab/bluetooth-repair/master/install.sh | bash
```
1) Adapt `bt-repair.conf` to your needs, e.g.:
* Specify how many times bt-repair tries to connect to a paired device before deleting and re-pairing it
* Add an external log handler (e.g. a telegram forwarder) to receive status messages and pairing codes (e.g keyboard pin)

2) Add your devices MAC to `devices.txt` and assign a name, one device per line e.g.:
```
E8:DA:20:F0:5E:97 Ben's Pro-Controller
```

# More than you ever wanted to know about this project
In late 2021 I set up a retropie, which was really fun and quick and easy to do. Instead of getting new controllers, the plan was to use four already existing Nintendo Pro-Cons and Joy-Cons with it via bluetooth. And this is where the problems really started. Based on this experience, I feel like bluetooth on linux tries to kind of do everything, but ends up doing none of it really well. If you run into problems, it's almost impossible to find consistent documentation to understand what is happening or help solve your problem. Debian has multiple tools to manage bluetooth, most of them are buggy (e.g. while running a bt-scan `bt-device -l` sometimes shows all detected devices as paired, subsequently the retropie autoconnect daemon tries to connect to all of them). So far I haven't been able to fully figure out which tool to use for what. For me the most consistent results for pairing and connecting devices, I had with the `bluetoothctl` tool.

Retropie then also already comes with multiple tools of it's own to auto-connect to paired bluetooth devices, but none of those work really consistently either. Somethimes the paired game-controller connects, sometimes it doesn't, sometimes it disconnects during game and does not re-connect. This was happening annoyingly often and with only a TV and a game-pad connected to the Pi, it is really hard to debug. From what I learned about Raspberry Pis and Pro controllers during that time is that there is multiple error modes:
* The game-pad had been connected to a different console (e.g. a switch) in the meantime, then it needs to be re-paired
* The game-pad does not connect for unknown reasons, but re-pairing it usually helps

So the process for me to solve these connection problems was to log into the Pi via SSH, delete the controller from bluetooth, pair it again. Finally I started scripting the process of deleting and re-pairing based on the output of the `bluetoothctl` tool. This works so far 100% of the time. `bluetoothctl`'s output is a pain to parse with a script and definitely not meant to be used this way, but it was giving me the most consistent results.

If anyone has a better idea of which tool to use (or e.g. a reliable python module) I'd be happy to hear.

# Todos
* Re-do this project in Python (over bash)
