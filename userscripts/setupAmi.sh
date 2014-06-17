#!/bin/bash

echo "Add newrelic repo to sources list..."
# Add new relic repo to sources list
# echo deb http://apt.newrelic.com/debian/ newrelic non-free >> /etc/apt/sources.list.d/newrelic.list
# wget -O /etc/apt/sources.list.d/newrelic.list http://download.newrelic.com/debian/newrelic.list
# sudo apt-key adv --keyserver hkp://subkeys.pgp.net --recv-keys 548C16BF

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

echo "Adding in default s3cfg file..."
echo "[default]
access_key = key
bucket_location = EU
cloudfront_host = cloudfront.amazonaws.com
cloudfront_resource = /2010-07-15/distribution
default_mime_type = binary/octet-stream
delete_removed = False
dry_run = False
encoding = UTF-8
encrypt = False
follow_symlinks = False
force = True
get_continue = False
gpg_command = /usr/bin/gpg
gpg_decrypt = %(gpg_command)s -d --verbose --no-use-agent --batch --yes --passphrase-fd %(passphrase_fd)s -o %(output_file)s %(input_file)s
gpg_encrypt = %(gpg_command)s -c --verbose --no-use-agent --batch --yes --passphrase-fd %(passphrase_fd)s -o %(output_file)s %(input_file)s
gpg_passphrase = passphrase
guess_mime_type = True
host_base = s3.amazonaws.com
host_bucket = %(bucket)s.s3.amazonaws.com
human_readable_sizes = False
list_md5 = False
log_target_prefix =
preserve_attrs = True
progress_meter = True
proxy_host =
proxy_port = 0
recursive = False
recv_chunk = 4096
reduced_redundancy = False
secret_key = secret
send_chunk = 4096
simpledb_host = sdb.amazonaws.com
skip_existing = False
socket_timeout = 10
urlencoding_mode = normal
use_https = True
verbosity = WARNING
" > /home/ubuntu/.s3cfg

echo "Configure and start newrelic..."
# apt-get install -y newrelic-sysmond
# nrsysmond-config --set license_key=KEYHERE
# /etc/init.d/newrelic-sysmond start

echo "Installing node..."
apt-get install -y python-software-properties
apt-add-repository -y ppa:chris-lea/node.js
apt-get update
apt-get install -y nodejs

echo "Installing forever..."
npm install -g forever

# lets update the cache for locate
updatedb

echo "Complete."