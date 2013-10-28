#!/bin/bash

#
# This script expects to be run in the chef-bcpc directory
#

set -e

if [[ -f ./proxy_setup.sh ]]; then
	. ./proxy_setup.sh
fi

# needed within build_bins which we call
if [[ -z "$CURL" ]]; then
	echo "CURL is not defined"
	exit
fi

FRAGMENT_DIR='/etc/apt/sources.list.d'
OPSCODE_LIST='opscode.list'
if [[ ! -f "$FRAGMENT_DIR/$OPSCODE_LIST" ]]; then
	echo "Adjusting opscode deb URL"
	cp "$OPSCODE_LIST" "$FRAGMENT_DIR"
	sed -i -e 's/http:\/\//file:\/\/\/var\/spool\/apt-mirror\/mirror\//' "$FRAGMENT_DIR/$OPSCODE_LIST"
fi


# When rerunning a bootstrap, the 'apt-get update' gets very slow if
# the bootstrap node happens to be our apt mirror, so only do this if
# the package we're after is not installed at all
#
# See http://askubuntu.com/questions/44122/upgrade-a-single-package-with-apt-get
#
if dpkg -s opscode-keyring 2>/dev/null | grep -q Status.*installed; then
	echo opscode-keyring is installed
else 
	echo "installing opscode-keyring"
	$APTGET update || true
	$APTGET --allow-unauthenticated -y install opscode-keyring
	$APTGET update || true
fi

if dpkg -s chef 2>/dev/null | grep -q Status.*installed; then
	echo chef is installed
else
	echo "installing chef"
	DEBCONF_DB_FALLBACK=File{$(pwd)/debconf-chef.conf} DEBIAN_FRONTEND=noninteractive $APTGET -y --force-yes install chef
fi

if dpkg -s chef-server 2>/dev/null | grep -q Status.*installed; then
	echo chef-server is installed
else
	echo "installing chef-server"
	DEBCONF_DB_FALLBACK=File{$(pwd)/debconf-chef.conf} DEBIAN_FRONTEND=noninteractive $APTGET -y --force-yes install chef-server
fi


chmod +r /etc/chef/validation.pem
chmod +r /etc/chef/webui.pem

# copy our ssh-key to be authorized for root
if [[ -f $HOME/.ssh/authorized_keys && ! -f /root/.ssh/authorized_keys ]]; then
	if [[ ! -d /root/.ssh ]]; then
		mkdir /root/.ssh
	fi
	cp $HOME/.ssh/authorized_keys /root/.ssh/authorized_keys
fi

echo "about to build bins"
./cookbooks/bcpc/files/default/build_bins.sh
