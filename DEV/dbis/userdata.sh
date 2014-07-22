#!/bin/bash

## ------ START:	Standard Config Elements ------ ##
export ENV='DEV'
export PROJECT_NAME='dbis'
export SCRIPT_NAME='release.sh'
export S3_DEPLOYMENT_KEY='AKIAJYDN74PFR2EBOQ3A'
# Rember that if this contains \ or / you need to escape that with \
export S3_DEPLOYMENT_SECRET='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'
# export S3_DEPLOYMENT_PASSPHRASE='wsims_lp_deployment_secret_dfsdljk123'
## ------ END:		Standard Config Elements ------ ##


## ------ START:	Standard Node AMI UserData Script ------ ##
sudo npm install -g grunt-cli
sudo npm install -g bower
sudo npm install -g cleverstack-cli

sed -i -r "s/(access_key *= *).*/\1$S3_DEPLOYMENT_KEY/" /home/ubuntu/.s3cfg
sed -i -r "s/(secret_key *= *).*/\1$S3_DEPLOYMENT_SECRET/" /home/ubuntu/.s3cfg
sed -i -r "s/(gpg_passphrase *= *).*/\1$S3_DEPLOYMENT_PASSPHRASE/" /home/ubuntu/.s3cfg

S3_APP_SCRIPT_PATH="s3://ite-devops/$ENV/$PROJECT_NAME/$SCRIPT_NAME"

# Store the launch script MD5 hash
s3cmd -f --config /home/ubuntu/.s3cfg ls $S3_APP_SCRIPT_PATH | md5sum | awk '{ print $1 }' > /tmp/releaseCurrentMd5.txt
chown ubuntu:ubuntu /tmp/releaseCurrentMd5.txt

# Fetch a copy of the launch script
s3cmd -f --config /home/ubuntu/.s3cfg get $S3_APP_SCRIPT_PATH /opt/$SCRIPT_NAME

# Ensure permissions of launch script are good
chmod o+x /opt/$SCRIPT_NAME
chown ubuntu:ubuntu /opt/$SCRIPT_NAME
mkdir /opt
chmod 777 /opt
chown ubuntu:ubuntu /opt

# Ubuntu cannot bind port 80, so we do this here in userdata as root so it redirects 80 to 8080 (where node is running)
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080

# Run the script for the first time
sudo -u ubuntu bash /opt/$SCRIPT_NAME >> /tmp/deploy.log
sudo chown ubuntu:ubuntu /tmp/deploy.log
## ------ END:		Standard Node AMI UserData Script ------ ##