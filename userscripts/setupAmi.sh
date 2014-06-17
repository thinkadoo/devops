#!/bin/bash

# Add new relic repo to sources list
wget -O /etc/apt/sources.list.d/newrelic.list http://download.newrelic.com/debian/newrelic.list
apt-key adv --keyserver hkp://subkeys.pgp.net --recv-keys 548C16BF

echo "Running update & upgrade..."
apt-get update
apt-get upgrade -y

echo "Installing default packages..."
apt-get install -y sendmail
apt-get install -y upstart
apt-get install -y s3cmd
apt-get install -y screen
apt-get install -y build-essential
apt-get install -y rsyslog
apt-get install -y git

echo "Configure and start newrelic..."
apt-get install newrelic-sysmond
# nrsysmond-config --set license_key=KEYHERE
# /etc/init.d/newrelic-sysmond start

echo "Installing node..."
apt-get install -y python-software-properties
apt-add-repository -y ppa:chris-lea/node.js
apt-get update
apt-get install -y nodejs npm

echo "Installing forever..."
npm install -g forever

# lets update the cache for locate
updatedb

echo "Complete."