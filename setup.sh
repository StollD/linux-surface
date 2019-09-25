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
    sudo cp -Rb root/$dir/* /$dir/
done

echo "Installing firmware files for IPTS..."
sudo cp -r firmware/* /lib/firmware/

echo "Making /lib/systemd/system-sleep/sleep executable..."
sudo chmod a+x /lib/systemd/system-sleep/sleep

echo "Enabling power management for Surface Go touchscreen..."
sudo systemctl enable -q surfacego-touchscreen

echo

if ask "Do you want to replace suspend with hibernate?" N; then
	echo "Using Hibernate instead of Suspend..."
	if [[ -f "/usr/lib/systemd/system/hibernate.target" ]]; then
		LIB="/usr/lib"
	else
		LIB="/lib"
	fi
	echo $LIB
	sudo ln -sfb $LIB/systemd/system/hibernate.target /etc/systemd/system/suspend.target
	sudo ln -sfb $LIB/systemd/system/systemd-hibernate.service /etc/systemd/system/systemd-suspend.service
else
	echo "Not touching Suspend..."
fi

echo

echo "This repo comes with example xorg and pulse audio configs."
echo "If you keep them, rename them and uncomment out what you'd like to keep!"
if ask "Do you want to remove the example Intel X.org config?" Y; then
	echo "Removing the example Intel X.org config..."
	sudo rm /etc/X11/xorg.conf.d/20-intel_example.conf
else
	echo "Not touching example Intel X.org config... (/etc/X11/xorg.conf.d/20-intel_example.conf)"
fi

if ask "Do you want to remove the example PulseAudio config files?" Y; then
	echo "Removing the example PulseAudio config files..."
	sudo rm /etc/pulse/daemon_example.conf
	sudo rm /etc/pulse/default_example.pa
else
	echo "Not touching example PulseAudio config files... (/etc/pulse/*_example.*)"
fi

echo

echo "Setting your clock to local time can fix issues with Windows dualboot."
if ask "Do you want to set your clock to local time instead of UTC?" N; then
	echo "Setting clock to local time..."
	sudo timedatectl set-local-rtc 1
	sudo hwclock --systohc --localtime
else
	echo "Not setting clock..."
fi

echo

# Debian
if [ -x "$(command -v apt)" ]; then
	echo "Patched libwacom packages are available to better support the pen."
	echo "If you plan to use the pen, it is recommended to install them!"
	if ask "Do you want to install the patched libwacom?" Y; then
		echo "Installing patched libwacom..."
		sudo dpkg -i packages/libwacom/*.deb
		sudo apt-mark hold libwacom
	else
		echo "Not touching libwacom..."
	fi

	echo

	if ask "Do you want to download and install the latest kernel?" Y; then
		echo "Downloading latest kernel..."
		urls=$(curl --silent "https://api.github.com/repos/qzed/linux-surface/releases/latest" \
			| tr ',' '\n' | grep '"browser_download_url":' \
			| sed -E 's/.*"([^"]+)".*/\1/' | grep '.deb$')
		wget -P tmp $urls

		echo

		echo "Installing latest kernel..."
		sudo dpkg -i tmp/*.deb
		rm -rf tmp
	else
		echo "Not downloading latest kernel..."
	fi

	echo
	echo "All done! Please reboot!"
	exit
fi

# Arch
if [ -x "$(command -v pacman)" ]; then
	echo "Patched libwacom packages are available to better support the pen."
	echo "If you plan to use the pen, it is recommended to install them!"
	if ask "Do you want to install the patched libwacom?" Y; then
		if [ -x "$(command -v yay)" ]; then
			yay -S libwacom-surface
		else
			echo "No AUR helper found! Please install it manually" \
			     "from https://aur.archlinux.org/packages/libwacom-surface"
		fi
	else
		echo "Not touching libwacom..."
	fi

	echo

	if ask "Do you want to download and install the latest kernel?" Y; then
		echo "Downloading latest kernel..."
		urls=$(curl --silent "https://api.github.com/repos/qzed/linux-surface/releases/latest" \
			| tr ',' '\n' | grep '"browser_download_url":' \
			| sed -E 's/.*"([^"]+)".*/\1/' | grep '.pkg.tar.xz$')
		wget -P tmp $urls

		echo

		echo "Installing latest kernel..."
		sudo dpkg -i tmp/*.pkg.tar.xz
		rm -rf tmp
	else
		echo "Not downloading latest kernel..."
	fi

	echo
	echo "All done! Please reboot!"
	exit
fi

# If no kernel repository is known, you have to compile it yourself
echo "For better hardware support, you have to install a patched kernel!"
echo "However, there doesn't seem to be a known repository for your distribution."
echo "For instructions on how to compile from source, please refer to the README.md file."
