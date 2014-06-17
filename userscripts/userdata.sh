#!/bin/bash

## ------ START:	Standard Config Elements ------ ##
export ENV='$ENTER_ENV_NAME_HERE'
export SCRIPT_NAME='$REPO_NAME.sh'
export S3_DEPLOYMENT_KEY='$S3_IAM_KEY'
export S3_DEPLOYMENT_SECRET='S3_IAM_SECRET'
export S3_DEPLOYMENT_PASSPHRASE='S3_IAM_PASSPHRASE'
## ------ END:		Standard Config Elements ------ ##


## ------ START:	Standard Node AMI UserData Script ------ ##
sudo sed -i -r "s/(access_key *= *).*/\1$S3_DEPLOYMENT_KEY/" /home/ec2-user/.s3cfg
sudo sed -i -r "s/(secret_key *= *).*/\1$S3_DEPLOYMENT_SECRET/" /home/ec2-user/.s3cfg
sudo sed -i -r "s/(gpg_passphrase *= *).*/\1$S3_DEPLOYMENT_PASSPHRASE/" /home/ec2-user/.s3cfg

S3_APP_SCRIPT_PATH="s3://ite-devops/$ENV/$SCRIPT_NAME"

# Store the launch script MD5 hash
s3cmd -f --config /home/ec2-user/.s3cfg ls $S3_APP_SCRIPT_PATH | md5sum | awk '{ print $1 }' > /tmp/releaseCurrentMd5.txt
chown ec2-user:ec2-user /tmp/releaseCurrentMd5.txt

# Fetch a copy of the launch script
s3cmd -f --config /home/ec2-user/.s3cfg get $S3_APP_SCRIPT_PATH /opt/$SCRIPT_NAME

# Ensure permissions of launch script are good
chmod o+x /opt/$SCRIPT_NAME
chown ec2-user:ec2-user /opt/$SCRIPT_NAME
mkdir /opt
chmod 777 /opt
chown ec2-user:ec2-user /opt

# Ubuntu cannot bind port 80, so we do this here in userdata as root so it redirects 80 to 8080 (where node is running)
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080

# Run the script for the first time
sudo -u ec2-user bash /opt/$SCRIPT_NAME >> /tmp/deploy.log
sudo chown ec2-user:ec2-user /tmp/deploy.log
## ------ END:		Standard Node AMI UserData Script ------ ##