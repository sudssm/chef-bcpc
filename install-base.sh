#!/bin/bash
if [[ -f ./proxy_setup.sh ]]; then
  . ./proxy_setup.sh
fi

#sudo -E apt-mark hold tzdata

dpkg --list tzdata

# needed within build_bins which we call
if [[ -z "$CURL" ]]; then
	echo "CURL is not defined"
	exit
fi


if ! hash nfsstat; then
	echo "Installing NFS client"
	$APTGET update
	$APTGET -y install nfs-common
	if ! hash nfsstat; then
		echo $'can\'t install NFS client'
		exit
	fi
fi

dpkg --list tzdata

if [[ ! -d /var/spool/apt-mirror ]]; then
    echo "Mounting the apt mirror..."
	sudo echo '10.0.100.2:/apt /mnt nfs auto 0 0' >> /etc/fstab
	sudo mount -a
	sudo ln -s /mnt/apt-mirror /var/spool/apt-mirror
fi
export OUTFILE='/etc/apt/sources.list.d/extras.list'
if [[ ! -f "$OUTFILE" ]]; then
    echo "Adjusting the apt settings..."
	sed -e 's/http:\/\//file:\/\/\/var\/spool\/apt-mirror\/mirror\//' /etc/apt/sources.list > "$OUTFILE"
	sed -i -e 's/deb-src/\#deb-src/' "$OUTFILE"
#	sed -i -e's/\(^.*security.ubuntu.com.*$\)/\#\1/' "$OUTFILE"
	sed -i -e's/security.ubuntu.com/us.archive.ubuntu.com/' "$OUTFILE"
	sudo mv /etc/apt/sources.list /etc/apt/sources.listHIDE
	$APTGET update
fi
echo "installing some useful supporting tools"
$APTGET -y install sshpass isc-dhcp-server cobbler cobbler-web apache2 git fping ntp whois lynx firefox emacs23 