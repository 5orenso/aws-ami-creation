#!/bin/bash
set -e -x

INSTANCE_NAME='mongodb-base'

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
apt-get install jq awscli git make g++ htop itop dstat unzip libwww-perl libdatetime-perl --yes

# Tag instance
aws ec2 create-tags --resources $EC2_INSTANCE_ID --tags Key=Name,Value=ami-creator-$INSTANCE_NAME --region eu-west-1


# Install MongoDB server: https://docs.mongodb.com/manual/tutorial/install-mongodb-on-ubuntu/
sudo apt-get install gnupg
wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
sudo apt-get update
sudo apt-get install -y mongodb-org


# Disk monitoring
cd /srv/
curl http://aws-cloudwatch.s3.amazonaws.com/downloads/CloudWatchMonitoringScripts-1.2.2.zip -O
unzip CloudWatchMonitoringScripts-1.2.2.zip
rm CloudWatchMonitoringScripts-1.2.2.zip

# Datadog
#DD_API_KEY=xxxxxyyyyzzzzz bash -c "$(curl -L https://raw.githubusercontent.com/DataDog/dd-agent/master/packaging/datadog-agent/source/install_agent.sh)"


# # Cloudwatch logs
# curl https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py -O
# cat > /tmp/awslogs.conf <<'EOF'
# [general]
# state_file = /var/awslogs/state/agent-state
# EOF
# python3 ./awslogs-agent-setup.py -n --region eu-west-1 -c /tmp/awslogs.conf


# noatime for Mongodb performance.
mv /etc/fstab /etc/fstab.old
cat > /etc/fstab <<'EOF'
LABEL=cloudimg-rootfs   /        ext4   defaults,noatime,discard        0 0
/dev/nvme1n1            /data    auto   defaults,nobootwait,comment=mongodb 0       2
EOF

cat > /home/ubuntu/README.txt <<'EOF'
## Some instructions on how this is setup

A. Choose your lates AMI and launch a new instance:
       mongo20.flyfisheurope.com   eu-west-1c / voter
       mongo21.flyfisheurope.com   eu-west-1a / primary
       mongo22.flyfisheurope.com   eu-west-1b / secondary
       mongo23.flyfisheurope.com   eu-west-1c / secondary

Attach network interface when launcing instance:
       mongo20.flyfisheurope.com   mongodb-replicaset-20    eni-069994e8ac6820f7d
       mongo21.flyfisheurope.com   mongodb-replicaset-21    eni-060679a827ac848d6
       mongo22.flyfisheurope.com   mongodb-replicaset-22    eni-0223aa9dbdc7a53f4
       mongo23.flyfisheurope.com   mongodb-replicaset-23    eni-0d62fa4f8cca319f1

Attach ebs disks when launching instance:
       mongo21.flyfisheurope.com   mongodb-replicaset-21    vol-0cd67d48705f6f157
       mongo22.flyfisheurope.com   mongodb-replicaset-22    vol-069fcace08919a6cb
       mongo23.flyfisheurope.com   mongodb-replicaset-23    vol-0ed7d6cac8c5ecdee

First time you should format the file systems:
$ sudo fdisk -l
$ sudo mkfs.xfs /dev/xvdf
$ mkdir /data
$ mount /dev/xvdf /var/lib/mongodb
$ df -T


--------------------------------------------------------------------------------
All servers:
--------------------------------------------------------------------------------
1. Edit /etc/hosts and set 127.0.0.1 to the correct hostname:
$ sudo vim /etc/hosts
127.0.0.1           localhost mongo21.flyfisheurope.com

1.2 Edit /etc/hostname and set the correct hostname:
$ sudo vim /etc/hostname
mongo21.flyfisheurope.com

2. Set hostname with:
$ sudo hostname mongo21.flyfisheurope.com

3. Edit mongod bindIp
$ sudo vim /etc/mongod.conf
net:
  bindIp: 172.30.0.221,127.0.0.1

3.1 Stop server
$ sudo service mongod stop

3.2 Start server again
$ sudo service mongod start


--------------------------------------------------------------------------------
4. On PRIMARY
--------------------------------------------------------------------------------
4.1 Initiate ReplicaSet with only one member
$ mongo
> rs.initiate()

4.2 Fetch backups and restore
$ mkdir mongodb-backup
$ aws s3 sync s3://ffe-mongodb-backups/mongo12.flyfisheurope.com/2020/11/01/ ./mongodb-backup/ --region eu-west-1
$ sudo mongorestore -d flyfish --drop ./mongodb-backup/flyfish/

4.3 Add more replicas to this replicaset:
$ mongo
> rs.add("mongo20.flyfisheurope.com:27017", true)
> rs.add("mongo21.flyfisheurope.com:27017")
> rs.add("mongo22.flyfisheurope.com:27017")
> rs.config()

> rs.remove("mongo21.flyfisheurope.com:27017")
> rs.remove("mongo22.flyfisheurope.com:27017")
> rs.remove("mongo23.flyfisheurope.com:27017")
> rs.config({ force: true })

4.4 Set priority on one master:
$ mongo
> cfg = rs.conf();
> cfg.members[0].priority = 10;
> rs.reconfig(cfg);


--------------------------------------------------------------------------------
5. On SECONDARY
--------------------------------------------------------------------------------
$ mongo
> db.setSecondaryOk()

6. Disable mongo-scripts in /etc/cron.daily/mongodb-scripts
$ sudo rm /etc/cron.daily/mongodb-scripts
$ sudo rm /etc/cron.hourly/mongodb-scripts

7. Check log for replication primary and secondaries.
$ tail -f /var/log/mongodb/mongod.log

8. To run commands on secondaries
rs44:SECONDARY> rs.setSecondaryOk()
rs44:SECONDARY> show dbs
rs44:SECONDARY> use flyfish
rs44:SECONDARY> show collections


That's all folks!

EOF


# Default setup of replica sets.
cat > /etc/hosts <<'EOF'
# MongoDB setup.
127.0.0.1           localhost mongo21.flyfisheurope.com

172.30.2.200        mongo10.flyfisheurope.com
172.30.0.201        mongo11.flyfisheurope.com
172.30.1.201        mongo12.flyfisheurope.com

172.30.2.220        mongo20.flyfisheurope.com
172.30.0.221        mongo21.flyfisheurope.com
172.30.1.222        mongo22.flyfisheurope.com
172.30.2.223        mongo23.flyfisheurope.com

EOF

hostname mongo21.flyfisheurope.com
cat > /etc/hostname <<'EOF'
mongo21.flyfisheurope.com
EOF


cat > /etc/mongod.conf <<'EOF'
# mongod.conf
# for documentation of all options, see:
#   http://docs.mongodb.org/manual/reference/configuration-options/

# Where and how to store data.
storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true
#  engine:
#  mmapv1:
#  wiredTiger:

# where to write logging data.
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

# network interfaces
net:
  bindIp: 172.30.0.221,127.0.0.1
  port: 27017

#processManagement:

#security:

#operationProfiling:

#replication:
replication:
   oplogSizeMB: 1000
   replSetName: rs44

# replication.enableMajorityReadConcern: false

#sharding:

## Enterprise-Only Options:

#auditLog:

#snmp:
EOF

# MongoDB backup daily
cat > /etc/cron.daily/mongodb <<'EOF'
#!/bin/bash

DATE=`/bin/date '+%Y/%m/%d'`
DIR=/var/backups/mongodb/$HOSTNAME

MONGODUMP=/usr/bin/mongodump
PARAM="--gzip -o "

/bin/mkdir -p $DIR/$DATE

echo -e "-------------------------------------------------------------------------------\n" > $DIR/$DATE/output.log
echo -e "$0 $DATE\n" >> $DIR/$DATE/output.log
echo -e `/bin/date` >> $DIR/$DATE/output.log

$MONGODUMP $PARAM $DIR/$DATE >> $DIR/$DATE/output.log 2>&1

echo -e "\nDone" >> $DIR/$DATE/output.log
echo -e `/bin/date` >> $DIR/$DATE/output.log
echo -e "-------------------------------------------------------------------------------\n" >> $DIR/$DATE/output.log

/usr/bin/aws --region eu-west-1 s3 sync /var/backups/mongodb/$HOSTNAME/ s3://ffe-mongodb-backups/$HOSTNAME/

EOF
chmod 755 /etc/cron.daily/mongodb

# MongoDB cron-daily scripts
mkdir /home/ubuntu/mongodb-cron-daily/
chmod 755 /home/ubuntu/mongodb-cron-daily/

cat > /etc/cron.daily/mongodb-scripts <<'EOF'
#!/bin/bash

SCRIPTS=/home/ubuntu/mongodb-cron-daily/

/usr/bin/aws --region eu-west-1 s3 sync s3://ffe-mongodb-cron-daily/ $SCRIPTS

for i in `find $SCRIPTS -name '*.js'` ; do
    /usr/bin/mongo flyfish $i;
done

EOF
chmod 755 /etc/cron.daily/mongodb-scripts

# MongoDB cron-hourly scripts
mkdir /home/ubuntu/mongodb-cron-hourly/
chmod 755 /home/ubuntu/mongodb-cron-hourly/

cat > /etc/cron.hourly/mongodb-scripts <<'EOF'
#!/bin/bash

SCRIPTS=/home/ubuntu/mongodb-cron-hourly/

/usr/bin/aws --region eu-west-1 s3 sync s3://ffe-mongodb-cron-hourly/ $SCRIPTS

for i in `find $SCRIPTS -name '*.js'` ; do
    /usr/bin/mongo flyfish $i;
done

EOF
chmod 755 /etc/cron.hourly/mongodb-scripts

# Turn off defrag option to speed up file system.
cat > /etc/init.d/disable-transparent-hugepages <<'EOF'
#!/bin/sh
### BEGIN INIT INFO
# Provides:          disable-transparent-hugepages
# Required-Start:    $local_fs
# Required-Stop:
# X-Start-Before:    mongod mongodb-mms-automation-agent
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Disable Linux transparent huge pages
# Description:       Disable Linux transparent huge pages, to improve
#                    database performance.
### END INIT INFO

case $1 in
  start)
    if [ -d /sys/kernel/mm/transparent_hugepage ]; then
      thp_path=/sys/kernel/mm/transparent_hugepage
    elif [ -d /sys/kernel/mm/redhat_transparent_hugepage ]; then
      thp_path=/sys/kernel/mm/redhat_transparent_hugepage
    else
      return 0
    fi

    echo 'never' > ${thp_path}/enabled
    echo 'never' > ${thp_path}/defrag

    unset thp_path
    ;;
esac
EOF

sudo chmod 755 /etc/init.d/disable-transparent-hugepages
sudo update-rc.d disable-transparent-hugepages defaults

sudo timedatectl set-timezone Europe/Oslo
sudo timedatectl set-ntp on

# Crontab for root
cat > /tmp/crontab.root <<'EOF'
# Cleanup old backups.
0 4 * * *   /usr/bin/find /var/backups/mongodb/ -type f -mtime +15 | xargs rm

# Send disk warnings
*/5 * * * * /srv/aws-scripts-mon/mon-put-instance-data.pl --mem-util --mem-used-incl-cache-buff --mem-used --mem-avail --disk-space-util --disk-path / --disk-space-used --disk-space-avail

EOF
echo "Adding to crontab for root from file /tmp/crontab.root"
crontab /tmp/crontab.root

# Enable ENA
# sudo apt-get update && sudo apt-get upgrade -y linux-aws
# aws ec2 modify-instance-attribute --instance-id instance_id --ena-support
# aws ec2 modify-instance-attribute --region eu-west-1 --instance-id $EC2_INSTANCE_ID --ena-support

# Create new image
IMAGE_NAME=`get_new_image_name ${INSTANCE_NAME}-ami`
echo "Instance-id: ${EC2_INSTANCE_ID}"
echo "New image name: ${IMAGE_NAME}"
aws ec2 create-image --instance-id ${EC2_INSTANCE_ID} --name ${IMAGE_NAME} --region eu-west-1
