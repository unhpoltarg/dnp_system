#!/bin/sh
#
# Run the cryosys application...
# to run with release 1.0.8 and later

# Set the necessary environment variables
export QWS_SIZE=480x272
export QWS_MOUSE_PROTO="Tslib:/dev/input/event1"
export TSDIR=/usr/lib/ts
export TSLIB_CALIBRATE=/etc/pointercal
export TSLIB_CONFFILE=/etc/ts.conf
export TSLIB_PLUGINDIR=/usr/lib/ts
export TSLIB_TSDEVICE=/dev/input/event1

# Update the system if update OR regression directories are available.
if [ ! -d /mnt/usb/ ];
then mkdir /mnt/usb
fi

cd /opt/OxfordInstruments/cryosys
chmod 677 usb.sh
sh update.sh

# Run cryosys
if [ -f cryosys ]
then       
		chmod a+x cryosys
        ./cryosys -graphicssystem openvg &
else
        exit 1
fi

exit 0
#

