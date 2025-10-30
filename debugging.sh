#!/usr/bin/env bash
printf 'Welcome.\nThis script will ask you for sudo password, which is necessary to extract required information.\n'

# Get current username before escalating permissions
user=$USER

# Get board name
board="$(cat /sys/class/dmi/id/product_name)"

# Get current date and time
date="$(date +"%Y-%m-%d_%Hh%Mm")"

# Specify where to store logs
logdir="debug-logs-$board-$date"
logarchive="debug-logs-$board-$date.tar.gz"

# Create directory to store logs
mkdir -p $logdir
cd $logdir

# Download cbmem and mark it as executable
wget https://mrchromebox.tech/files/util/cbmem.tar.gz &> /dev/null
tar -xf cbmem.tar.gz
rm cbmem.tar.gz
chmod +x cbmem

# Grab logs necessary for debugging audio
if [ ! -z '$(pgrep pulseaudio)' ]
then
	# Get logs from pipewire
	systemctl --user stop pipewire.{socket,service}
	systemctl --user stop pipewire-pulse.{socket,service}

	if [ -z "$(which spa-acp-tool)" ]
	then
		printf 'spa-acp-tool not found. On distros using apt, install pipewire-bin\n'
		touch no-spaacptool
	fi

	for card in $(grep '\[' /proc/asound/cards | awk '{print $1}')
	do
		echo "Pipewire card $card log:" >> audio-debug.log
		spa-acp-tool -c $card -vvvv info &>> audio-debug.log
	done

	systemctl --user start pipewire.service
	systemctl --user start pipewire-pulse.service
else
	# Get logs from pulseaudio
	systemctl --user stop pulseaudio.{socket,service}

	echo "Pulseaudio log:" >> audio-debug.log
	pulseaudio -v &>> audio-debug.log & sleep 5
	killall pulseaudio

	systemctl --user start pulseaudio.service
fi

# UCM logs
skip_ucm=0

if [ -z "$(which alsaucm)" ]
then
	printf 'alsaucm not found. Please install alsa-utils.\n'
	touch no-alsautils
	skip_ucm=1
fi
if [ -z "$(which strace)" ]
then
	printf 'strace not found. Please install strace.\n'
	touch no-strace
	skip_ucm=1    
fi

if [ "$skip_ucm" = "0" ]
then
	for card in $(grep '\[' /proc/asound/cards | awk '{print $1}')
	do
		echo "Alsa card $card UCM log:" >> alsa-ucm.log
		strace alsaucm -c hw:$card reload &>> alsa-ucm.log
	done
fi

lsmod > loaded-modules.log
find /lib/firmware > firmware.log

# grab journal on systemd distros
if [ ! -z "$(which journalctl)" ]
then
	journalctl -b 0 > journal.log
fi

# grab a copy of /etc/os-release
cd /etc/os-release .

# Priviledge escalation [!!!]
{
	sudo su <<EOF

# Grab logs and redirect output to files instead of stdout
dmesg >> dmesg.log

if [ -z "$(which lspci)" ]
then
	printf 'lspci not found. Please install pciutils.\n'
	touch no-lspci
else
	lspci -vvvnn >> lspci.log
fi

if [ -z "$(which lsusb)" ]
then 
	printf 'lsusb not found. Please install usbutils.\n'
	touch no-lsusb
else
	lsusb -v >> lsusb.log
fi

if [ -z "$(which dmidecode)" ]
then
	printf 'Dmidecode not found. Please install it.\n'
	touch no-dmidecode
else
	dmidecode >> dmidecode.log
fi

if [ -z "$(which libinput)" ]
then
	printf 'libinput not found. Please install libinput utils.\n'
	touch no-libinput
else
	libinput list-devices >> libinput.log
fi

## Copy ACPI tables
mkdir acpi
cp /sys/firmware/acpi/tables/DSDT ./acpi/
cp /sys/firmware/acpi/tables/SSDT* ./acpi/

# Grab coreboot logs
./cbmem -c > cbmem.log

# Set file permissions for regular user
chown -R $user:$user *
chmod -R 755 *

EOF
} || {
	echo "Error: Unable to gain root permission. Log archive will be incomplete!"
	touch no-root
}


# Remove cbmem binary
rm cbmem

# Pack logs into archive and remove temporary folder that stores them
cd ..
tar -caf "$logarchive" "$logdir"
rm -r "$logdir"

printf "Log collection done.\nPlease upload ${logarchive} for analysis.\n"
