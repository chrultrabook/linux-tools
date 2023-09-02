#!/usr/bin/env bash

printf 'Welcome.\nThis script will ask you for sudo password, which is necessary to extract required information.\n'

# Get current username before escalating permissions
user=$USER

# Create directory to store logs
mkdir -p ~/Desktop/debug-logs/
cd ~/Desktop/debug-logs

# Download cbmem and mark it as executable
wget https://mrchromebox.tech/files/util/cbmem.tar.gz
tar -xf cbmem.tar.gz;rm cbmem.tar.gz;chmod +x cbmem
chmod +x cbmem

# Grab logs necessary for debugging audio
if [ ! -z '$(pgrep pulseaudio)' ]
then
	systemctl --user stop pipewire.socket
	systemctl --user stop pipewire.service

	for card in $(grep '\[' /proc/asound/cards | awk '{print $1}')
do
	echo "Pipewire card $card log:" >> audio-debug.log
	spa-acp-tool -c $card -vvvv info &>> audio-debug.log

	systemctl --user start pipewire.socket
	systemctl --user start pipewire.service
    done
else
	systemctl --user stop pulseaudio.socket
	systemctl --user stop pulseaudio.service

	echo "Pulseaudio log:" >> audio-debug.log
	pulseaudio -v &>> audio-debug.log & sleep 5
	killall pulseaudio

	systemctl --user start pulseaudio.service
fi

# Priviledge escalation [!!!]
sudo su <<EOF

# Grab logs and redirect output to files instead of stdout
dmesg >> dmesg.log

if [ ! -f /sbin/lspci ]
then
	printf 'lspci not found. Please install pciutils.\n'
else
	lspci -vvvnn >> lspci.log
fi

if [ ! -f /bin/lsusb ]
then 
	printf 'lsusb not found. Please install usbutils.\n'
else
	lsusb -v >> lsusb.log
fi

if [ ! -f /sbin/dmidecode ]
then
	printf 'Dmidecode not found. Please install it.\n'
else
	dmidecode > dmidecode.log
fi

## Copy ACPI tables
mkdir acpi
cp /sys/firmware/acpi/tables/DSDT ./acpi/
cp /sys/firmware/acpi/tables/SSDT* ./acpi/

# Grab coreboot logs and remove binary as it's no longer needed
./cbmem -c > cbmem.log
rm cbmem

# Set file permissions for regular user
chown -R $user:$user *
chmod -R 755 *

EOF

# Pack logs into archive and remove temporary folder that stores them
cd ..
tar -czf debug-logs.tar.gz debug-logs
rm -r debug-logs

printf 'Log collection done.\nPlease upload "debug-logs.tar.gz" for analysis.\n'
