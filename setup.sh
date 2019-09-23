#!/bin/sh

# https://gist.github.com/davejamesmiller/1965569
ask() {
    local prompt default reply

    if [ "${2:-}" = "Y" ]; then
        prompt="Y/n"
        default=Y
    elif [ "${2:-}" = "N" ]; then
        prompt="y/N"
        default=N
    else
        prompt="y/n"
        default=
    fi

    while true; do

        # Ask the question (not using "read -p" as it uses stderr not stdout)
        echo -n "$1 [$prompt]: "

        # Read the answer (use /dev/tty in case stdin is redirected from somewhere else)
        read reply </dev/tty

        # Default?
        if [ -z "$reply" ]; then
            reply=$default
        fi

        # Check if the reply is valid
        case "$reply" in
            Y*|y*) return 0 ;;
            N*|n*) return 1 ;;
        esac

    done
}

echo "Installing config files..."
for dir in $(ls root); do
    cp -Rb root/$dir/* /$dir/
done

echo "Installing firmware files for IPTS..."
cp -r firmware/* /lib/firmware/

echo "Making /lib/systemd/system-sleep/sleep executable..."
chmod a+x /lib/systemd/system-sleep/sleep

echo "Enabling power management for Surface Go touchscreen..."
systemctl enable -q surfacego-touchscreen

echo

if ask "Do you want to replace suspend with hibernate?" N; then
	echo "Using Hibernate instead of Suspend..."
	ln -sfb /usr/lib/systemd/system/hibernate.target /etc/systemd/system/suspend.target
	ln -sfb /usr/lib/systemd/system/systemd-hibernate.service /etc/systemd/system/systemd-suspend.service
else
	echo "Not touching Suspend..."
fi

echo

echo "This repo comes with example xorg and pulse audio configs."
echo "If you keep them, rename them and uncomment out what you'd like to keep!"
if ask "Do you want to remove the example Intel X.org config?" Y; then
	echo "Removing the example Intel X.org config..."
	rm /etc/X11/xorg.conf.d/20-intel_example.conf
else
	echo "Not touching example Intel X.org config... (/etc/X11/xorg.conf.d/20-intel_example.conf)"
fi

if ask "Do you want to remove the example PulseAudio config files?" Y; then
	echo "Removing the example PulseAudio config files..."
	rm /etc/pulse/daemon_example.conf
	rm /etc/pulse/default_example.pa
else
	echo "Not touching example PulseAudio config files... (/etc/pulse/*_example.*)"
fi

echo

echo "Setting your clock to local time can fix issues with Windows dualboot."
if ask "Do you want to set your clock to local time instead of UTC?" N; then
	echo "Setting clock to local time..."
	timedatectl set-local-rtc 1
	hwclock --systohc --localtime
else
	echo "Not setting clock..."
fi

echo

echo "Patched libwacom packages are available to better support the pen."
echo "If you plan to use the pen, it is recommended to install them!"
if ask "Do you want to install the patched libwacom?" Y; then
	echo "Installing patched libwacom..."
	dpkg -i packages/libwacom/*.deb
	apt-mark hold libwacom
else
	echo "Not touching libwacom..."
fi

echo

if ask "Do you want to download and install the latest kernel?" Y; then
	echo "Downloading latest kernel..."
	urls=$(curl --silent "https://api.github.com/repos/qzed/linux-surface/releases/latest" \
		| tr ',' '\n' | grep '"browser_download_url":' | sed -E 's/.*"([^"]+)".*/\1/'  \
		| grep '.deb$')
	wget -P tmp $urls

	echo

	echo "Installing latest kernel..."
	dpkg -i tmp/*.deb
	rm -rf tmp
else
	echo "Not downloading latest kernel..."
fi

echo

echo "All done! Please reboot!"
