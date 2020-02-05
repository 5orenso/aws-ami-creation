#!/bin/bash
set -e -x

INSTANCE_NAME='simple-blog-base'

# Function to get the next number.
# $* input
# Example: echo 1 | get_next_num
get_next_num() {
    re='^[0-9]+$'
    read num
    if ! [[ $num =~ $re ]] ; then
       echo 1
    else
       echo $((num+1))
    fi
}

# Get name of new AMI image based on existing images with similar base name.
# $1 = base name
get_new_image_name() {
    IMAGE_STAMP=`date +%Y-%m-%d`
    IMAGE_BASE_NAME=$1-${IMAGE_STAMP}
    IMAGE_NEXT_ID=$(aws ec2 describe-images --region eu-west-1 --owners self --filters "Name=name,Values=${IMAGE_BASE_NAME}*" \
        | jq -r '.Images[].Name' \
        | cut -d'_' -f2 \
        | get_next_num)

    echo ${IMAGE_BASE_NAME}_${IMAGE_NEXT_ID}
}

get_ec2_instance_id() {
    echo `curl http://169.254.169.254/latest/meta-data/instance-id`
}

DEBIAN_FRONTEND=noninteractive
EC2_INSTANCE_ID=`get_ec2_instance_id`

apt-get update

# AWS tools and other software
apt-get install jq awscli git make g++ imagemagick --yes

# Tag instance
aws ec2 create-tags --resources $EC2_INSTANCE_ID --tags Key=Name,Value=ami-creator-$INSTANCE_NAME --region eu-west-1

cat > /etc/init.d/dropbox <<'EOF'
#!/bin/sh
# dropbox service
# Replace with linux users you want to run Dropbox clients for

### BEGIN INIT INFO
# Provides: dropbox
# Required-Start: $local_fs $remote_fs $network $syslog $named
# Required-Stop: $local_fs $remote_fs $network $syslog $named
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# X-Interactive: false
# Short-Description: dropbox service
### END INIT INFO

DROPBOX_USERS="ubuntu"

DAEMON=.dropbox-dist/dropboxd
start() {
    echo "Starting dropbox..."
    for dbuser in $DROPBOX_USERS; do
        HOMEDIR=`getent passwd $dbuser | cut -d: -f6`
        if [ -x $HOMEDIR/$DAEMON ]; then
            HOME="$HOMEDIR" start-stop-daemon -b -o -c $dbuser -S -u $dbuser -x $HOMEDIR/$DAEMON
        fi
    done
}

stop() {
    echo "Stopping dropbox..."
    for dbuser in $DROPBOX_USERS; do
        HOMEDIR=`getent passwd $dbuser | cut -d: -f6`
        if [ -x $HOMEDIR/$DAEMON ]; then
            start-stop-daemon -o -c $dbuser -K -u $dbuser -x $HOMEDIR/$DAEMON
        fi
    done
}

status() {
    for dbuser in $DROPBOX_USERS; do
        dbpid=`pgrep -u $dbuser dropbox`
        if [ -z $dbpid ] ; then
            echo "dropboxd for USER $dbuser: not running."
        else
            echo "dropboxd for USER $dbuser: running (pid $dbpid)"
        fi
    done
}

case "$1" in
    start)
        start
    ;;
    stop)
        stop
    ;;
    restart|reload|force-reload)
        stop
        start
    ;;
    status)
        status
    ;;
    *)
    echo "Usage: /etc/init.d/dropbox {start|stop|reload|force-reload|restart|status}"
    exit 1
esac
exit 0
EOF

chmod +x /etc/init.d/dropbox
update-rc.d dropbox defaults
# Control the Dropbox client like any other Ubuntu service
# service dropbox start|stop|reload|force-reload|restart|status

sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
NODE_VERSION="8.6.0"
sudo curl -o /usr/local/node-v$NODE_VERSION-linux-x64.tar.xz https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz
cd /usr/local && sudo tar xf /usr/local/node-v$NODE_VERSION-linux-x64.tar.xz
sudo ln -s /usr/local/node-v$NODE_VERSION-linux-x64/bin/node /usr/local/bin/node
sudo ln -s /usr/local/node-v$NODE_VERSION-linux-x64/bin/npm /usr/local/bin/npm

IMAGE_NAME=`get_new_image_name ${INSTANCE_NAME}-ami`

cat <<EOF
-------------------------------------------------------------------------------
IMPORTANT! IT IS NOT POSSIBLE TO AUTOMATED INSTALLATION OF DROPBOX!
-------------------------------------------------------------------------------
Manual steps:
* SSH into the server as ubuntu.

* Download and install the Dropbox script:
    $ sudo curl -o /usr/local/bin/dropbox.py 'https://linux.dropbox.com/packages/dropbox.py'
    $ sudo chmod +x /usr/local/bin/dropbox.py

* Download and install the daemon:
    $ cd /home/ubuntu/ && wget -O - "https://www.dropbox.com/download?plat=lnx.x86_64" | tar xzf -

* Link this server to your Dropbox account:
    $ /home/ubuntu/.dropbox-dist/dropboxd

* Start the service:
    $ sudo service dropbox start
    $ sudo service dropbox status

* Exclude all files and folders. Must check and run several times to be sure
  everything is gone. It's so stupid that it has to sync everything to local
  disk before you can exclude it. I would have loved to talked to the programmer
  who came up with this insane idea.
    $ cd /home/ubuntu/Dropbox/
    $ dropbox.py exclude add *

* Include blog folders
    $ dropbox.py exclude remove websites
    $ dropbox.py exclude remove websites 'BLOG (2)'

* When everything is up to date:
    $ dropbox.py status
    Up to date

* Now it's time to Create your AMI
    $ aws ec2 create-image --instance-id ${EC2_INSTANCE_ID} --name ${IMAGE_NAME} --region eu-west-1

* When your AMI is created, terminate the server.
    $ sudo halt

EOF

# Set timedatectl
sudo timedatectl set-timezone Europe/Oslo
sudo timedatectl set-ntp on
