# bluetooth-repair
A bluetooth auto-repair daemon based on bluetoothctl

# What is this project and why can it be useful?
* TODO

# Installation

* Install with
```bash
$ wget -O - https://raw.githubusercontent.com/eberhab/bluetooth-repair/master/install.sh | bash
```
* Adapt `bt-repair.conf` to your needs, e.g.:
** Specify how many times bt-repair tries to connect to a paired devices before re-pairing it
** Add an external log handler (e.g. a letegram forwarder) to receive status messages and pairing codes (for e.g keyboards)

* Add your devices to `devices.txt`, e.g.:
```
E8:DA:20:F0:5E:97 Ben's Pro-Controller
```

# Todos
* Re-do this project in Python (over bash)
