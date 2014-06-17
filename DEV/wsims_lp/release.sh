#!/bin/bash

## ------ START:	Standard Config Elements ------ ##
export NODE_ENV='DEV'
export PROJECT_NAME='wsims_lp'
export SCRIPT_NAME='release.sh'
export NODE_PATH='./lib/:./modules/'
export DEBUG=*
## ------ END:		Standard Config Elements ------ ##



## ------ START:	Locking mechanism ------ ##
SCRIPT_PID=$$
BASENAME=${0##*/}
PIDFILE_BASE=/tmp/$BASENAME
PIDFILE=$PIDFILE_BASE.$$

#Look for existing Lock files
PIDFILES=`ls $PIDFILE_BASE*`

if [ -n "$PIDFILES" ] ; then
    echo "PID:$SCRIPT_PID - $(date) | Lock files are present."
    for P in $PIDFILES ; do
        # Get the PID
        PID=`cat $P`
        if [ -f /proc/$PID/cmdline ] ; then
            CMD=`cat /proc/$PID/cmdline`
            if [ "${CMD//$BASENAME}" != "$CMD" ] ; then
                echo "PID:$SCRIPT_PID - $(date) | Lock acquisition failed, exited script."
                exit 1
            else
                echo "PID:$SCRIPT_PID - $(date) | Lock found was bogus, deleting it."
                rm -f $P
            fi
        else
            echo "PID:$SCRIPT_PID - $(date) | Lock found is dead, deleting it."
            rm -f $P
        fi
    done
fi

echo "PID:$SCRIPT_PID - $(date) | Lock acquired ($PIDFILE)"
echo $$ > $PIDFILE
## ------ END:		Locking mechanism ------ ##



## ------ START: 	Release script self updater ------ ##
RELEASE_VERSION_DIFF=0
RELEASE_MD5_CURRENT='/tmp/releaseCurrentMd5.txt'
RELEASE_MD5_NEW='/tmp/releaseNewMd5.txt'
touch $RELEASE_MD5_CURRENT

NEW_RELEASE_NOT_EMPTY=`s3cmd -f --config /home/ubuntu/.s3cfg ls s3://ite-devops/$NODE_ENV/$PROJECT_NAME/$SCRIPT_NAME | wc -l`
if [ $NEW_RELEASE_NOT_EMPTY -ne 0 ]; then

	# Get the latest hash
	s3cmd -f --config /home/ubuntu/.s3cfg ls s3://ite-devops/$NODE_ENV/$PROJECT_NAME/$SCRIPT_NAME | md5sum | awk '{ print $1 }' > $RELEASE_MD5_NEW
	
	RELEASE_VERSION_DIFF=`diff $RELEASE_MD5_NEW $RELEASE_MD5_CURRENT | wc -l`
	if [ $RELEASE_VERSION_DIFF -ne 0 ]
	then
		echo "PID:$SCRIPT_PID - $(date) | Release SCRIPT MD5 has changed, fetching a new copy of this release script..."
		s3cmd -f --config /home/ubuntu/.s3cfg get s3://ite-devops/$NODE_ENV/$PROJECT_NAME/$SCRIPT_NAME /opt/$SCRIPT_NAME

		echo "PID:$SCRIPT_PID - $(date) | Release SCRIPT was updated, updating RELEASE_MD5_CURRENT"
		cat $RELEASE_MD5_NEW > $RELEASE_MD5_CURRENT
	fi
fi
## ------ END:		Release script self updater ------ ##



## ------ START:	Standard Node AMI Release Script ------ ##

echo "PID:$SCRIPT_PID - $(date) | Updating crontab for user ubuntu..."

echo "* * * * * bash /opt/$SCRIPT_NAME 2>&1 >> /tmp/deploy.log
* * * * * sleep 10; bash /opt/$SCRIPT_NAME 2>&1 >> /tmp/deploy.log
* * * * * sleep 20; bash /opt/$SCRIPT_NAME 2>&1 >> /tmp/deploy.log
* * * * * sleep 30; bash /opt/$SCRIPT_NAME 2>&1 >> /tmp/deploy.log
* * * * * sleep 40; bash /opt/$SCRIPT_NAME 2>&1 >> /tmp/deploy.log
* * * * * sleep 50; bash /opt/$SCRIPT_NAME 2>&1 >> /tmp/deploy.log" > ~/ubuntu.crontab
crontab ~/ubuntu.crontab

S3_PATH="s3://ite-devops/$NODE_ENV/$PROJECT_NAME/$PROJECT_NAME.tgz"
RUNNING_LIST=`forever list | grep -c '\n'`
FOREVER_PID_FILE="/opt/$PROJECT_NAME.pid"
FOREVER_LOG_FILE="/opt/$PROJECT_NAME.log"

# Only do a release if we did not just get a new release script
if [ $RELEASE_VERSION_DIFF -eq 0 ]; then

	# MD5 Tracking hases for updating the applications code from S3
	MD5OLD='/tmp/oldMd5.txt'
	MD5NEW='/tmp/newMd5.txt'
	touch $MD5OLD
	s3cmd -f --config /home/ubuntu/.s3cfg ls $S3_PATH | md5sum | awk '{ print $1 }' > $MD5NEW
	VERSION_DIFF=`diff $MD5NEW $MD5OLD | wc -l`
	DEPLOYMENT_DIR="/opt/$PROJECT_NAME"
	CURRENTDIR="$DEPLOYMENT_DIR/current"

	if [ $VERSION_DIFF -ne 0 ]; then
		echo "PID:$SCRIPT_PID - $(date) | Release required (MD5 has changed), updating $PROJECT_NAME on $NODE_ENV..."

		if [ ! -d $DEPLOYMENT_DIR ]; then
			echo "PID:$SCRIPT_PID - $(date) | SETUP: the DEPLOYMENT_DIR and set owner as ubuntu..."
		    sudo mkdir $DEPLOYMENT_DIR
		    sudo chown ubuntu:ubuntu $DEPLOYMENT_DIR
		    sudo chmod 775 $DEPLOYMENT_DIR
		fi

		echo "PID:$SCRIPT_PID - $(date) | Changing to $DEPLOYMENT_DIR (DEPLOYMENT_DIR)..."
		cd $DEPLOYMENT_DIR

		echo "PID:$SCRIPT_PID - $(date) | Release starting download of new code release (S3)..."
		BUILDNUMBER=$(s3cmd -f -d --config /home/ubuntu/.s3cfg get $S3_PATH /opt/$PROJECT_NAME.tgz 2>&1 | tee | grep -Po "\'x-amz-meta-build_number\':.*?\'([^\']+)\'" | grep -Po "\'[^\']+\'$" | grep -Po "[^\']")
		BUILDDIR="$DEPLOYMENT_DIR/$BUILDNUMBER"

		if [ -d $BUILDDIR ]; then
			echo "PID:$SCRIPT_PID - $(date) | Deleting build directory for build $BUILDNUMBER..."
			sudo rm -rf $BUILDDIR
		fi

		echo "PID:$SCRIPT_PID - $(date) | Making build directory for build $BUILDNUMBER..."
		mkdir $BUILDDIR
		sudo chown ubuntu:ubuntu $BUILDDIR
		sudo chmod 775 $BUILDDIR
		
		echo "PID:$SCRIPT_PID - $(date) | Extracting build from tar..."
		cd $BUILDDIR
		tar -xzvf /opt/$PROJECT_NAME.tgz

		echo "PID:$SCRIPT_PID - $(date) | Running clever setup..."
		sudo clever setup
		sudo chown -R ubuntu:ubuntu $BUILDDIR/node_modules

		cd $DEPLOYMENT_DIR
		ln -f -n -s $BUILDDIR $CURRENTDIR

		cd $CURRENTDIR

		if [ $RUNNING_LIST -eq 3 ]; then # Node is running fine
			echo "PID:$SCRIPT_PID - $(date) | Forever is RESTARTING the $NODE_ENV application..."
			forever stopall
		elif [ $RUNNING_LIST -eq 1 ]; then # No node processes are running through forever
			echo "PID:$SCRIPT_PID - $(date) | Forever is STARTING the $NODE_ENV application because it was NOT running..."
		else
			echo "PID:$SCRIPT_PID - $(date) | Forever is running multiple processes, attempting to fix the problem..."
			forever stopall
		fi

		forever start --spinSleepTime 1000 --pidFile $FOREVER_PID_FILE -a -l $FOREVER_LOG_FILE app.js

		# Update the md5
		echo "PID:$SCRIPT_PID - $(date) | Release updating current MD5 to $MD5NEW"
		cat $MD5NEW > $MD5OLD

		echo "PID:$SCRIPT_PID - $(date) | Release finished!"
	else 

		cd $CURRENTDIR

		if [ $RUNNING_LIST -eq 1 ]; then # No node processes are running through forever
			echo "PID:$SCRIPT_PID - $(date) | Forever is STARTING the $NODE_ENV application because it was NOT running..."
			forever start --spinSleepTime 1000 --pidFile $FOREVER_PID_FILE -a -l $FOREVER_LOG_FILE app.js
		elif [ $RUNNING_LIST -ne 3 ]; then
			echo "PID:$SCRIPT_PID - $(date) | Forever is running multiple processes, attempting to fix the problem..."
			forever stopall
			forever start --spinSleepTime 1000 --pidFile $FOREVER_PID_FILE -a -l $FOREVER_LOG_FILE app.js
		fi

		echo "PID:$SCRIPT_PID - $(date) | Release not required, exiting"
	fi
fi
## ------ END:	Standard Node AMI Release Script ------ ##



## ------ START: Release Locking mechanism ------ ##
rm -f $PIDFILE
echo "PID:$SCRIPT_PID - $(date) | Lock released ($PIDFILE)"
exit 0
## ------ END: 	Release Locking mechanism ------ ##