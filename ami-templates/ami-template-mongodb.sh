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
wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
sudo apt-get update
sudo apt-get install -y mongodb-org

# noatime for Mongodb performance.
# mv /etc/fstab /etc/fstab.old
# cat > /etc/fstab <<'EOF'
# LABEL=cloudimg-rootfs   /        ext4   defaults,noatime,discard        0 0
# /dev/nvme1n1            /data    auto   defaults,nobootwait,comment=mongodb 0       2
# EOF


cat > /home/ubuntu/README.txt <<'EOF'
## Some instructions on how this is setup

# Create network interfaces and ebs disks in AWS console.

## Elastic IPs
mongodb-replicaset-20    xxx.xxx.xxx.xxx
mongodb-replicaset-21    xxx.xxx.xxx.xxx
mongodb-replicaset-22    xxx.xxx.xxx.xxx
mongodb-replicaset-23    xxx.xxx.xxx.xxx

## Network interfaces
mongodb-replicaset-20  base-subnet-a  10.1.16.220
mongodb-replicaset-21  base-subnet-a  10.1.16.221
mongodb-replicaset-22  base-subnet-b  10.1.32.222
mongodb-replicaset-23  base-subnet-c  10.1.0.223

## EBS disks
mongodb-replicaset-21  100 GiB  100 iops  io1  /dev/nvme1n1
mongodb-replicaset-22  100 GiB  100 iops  io1  /dev/nvme1n1
mongodb-replicaset-23  100 GiB  100 iops  io1  /dev/nvme1n1



A. Choose your lates AMI and launch a new instance:
       mongo20.raskepoter.no   eu-west-1a / voter
       mongo21.raskepoter.no   eu-west-1a / primary
       mongo22.raskepoter.no   eu-west-1b / secondary
       mongo23.raskepoter.no   eu-west-1c / secondary

Attach network interface when launcing instance:
       mongo20.raskepoter.no   mongodb-replicaset-20    eni-0838fae723897e065
       mongo21.raskepoter.no   mongodb-replicaset-21    eni-0a4b4492a2e639ed0
       mongo22.raskepoter.no   mongodb-replicaset-22    eni-050655c420ba476e7
       mongo23.raskepoter.no   mongodb-replicaset-23    eni-0b7ca7a3fe030cc78

Attach ebs disks when launching instance:
       mongo21.raskepoter.no   mongodb-replicaset-21    vol-0cd67d48705f6f157
       mongo22.raskepoter.no   mongodb-replicaset-22    vol-069fcace08919a6cb
       mongo23.raskepoter.no   mongodb-replicaset-23    vol-0ed7d6cac8c5ecdee


First time you should format the file systems:
$ sudo fdisk -l
$ sudo mkfs.xfs /dev/nvme1n1
$ sudo mkdir /data
$ sudo mount /dev/nvme1n1 /data
$ df -h

$ sudo vim /etc/fstab
# /dev/nvme1n1   xfs      167690240 1202920 166487320   1% /data

# lsblk - list block devices
# mount - mount a filesystem (used for general mount info too):
$ findmnt /


--------------------------------------------------------------------------------
All servers:
--------------------------------------------------------------------------------
1. Edit /etc/hosts and set 127.0.0.1 to the correct hostname:
$ sudo vim /etc/hosts
127.0.0.1           localhost mongo21.raskepoter.no

10.1.16.220     mongo20.raskepoter.no
10.1.16.221     mongo21.raskepoter.no
10.1.32.222     mongo22.raskepoter.no
10.1.0.223      mongo23.raskepoter.no


1.2 Edit /etc/hostname and set the correct hostname:
$ sudo vim /etc/hostname
mongo21.raskepoter.no

2. Set hostname with:
$ sudo hostname mongo21.raskepoter.no

3. Edit mongod bindIp
$ ip a
$ sudo vim /etc/mongod.conf
# Where and how to store data.
storage:
  dbPath: /data/mongodb

# network interfaces
net:
  bindIp: 10.1.16.221,127.0.0.1


3.0.1 Create email file
$ sudo vim /home/ubuntu/email-on-restart.sh
#!/bin/bash

FROM="mongo21@litt.no"
TO="sorenso@gmail.com"
SUBJECT="Mongodb service mogno21 restarted"
BODY="You should check it out if it happens to often."

aws ses send-email \
  --from "$FROM" \
  --destination "ToAddresses=$TO" \
  --message "Subject={Data=$SUBJECT,Charset=utf8},Body={Text={Data=$BODY,Charset=utf8}}"

$ sudo chmod 755 /home/ubuntu/email-on-restart.sh


3.0.2 Edit systemd service file
$ sudo vim /lib/systemd/system/mongod.service
# Add Restart=always to service file
[Service]
...
Restart=always
ExecStartPost=/home/ubuntu/email-on-restart.sh
...

$ sudo systemctl daemon-reload
$ sudo systemctl restart mongod

3.1 Stop server
$ sudo service mongod stop
$ sudo mkdir /data/mongodb
$ sudo chown mongodb.mongodb /data/mongodb

3.2 Start server again
$ sudo service mongod start
$ sudo service mongod status


--------------------------------------------------------------------------------
4. On PRIMARY
--------------------------------------------------------------------------------
4.1 Initiate ReplicaSet with only one member
$ mongosh
> rs.initiate()
> db.adminCommand({
  setDefaultRWConcern: 1,
  defaultWriteConcern: { w: "majority" }
});

> rs.reconfig(
  {
    _id: "rs44",
    members: [
      { _id: 0, host: "mongo21.raskepoter.no:27017", priority: 1 },
      { _id: 1, host: "mongo22.raskepoter.no:27017", priority: 0.5 },
      // Ensure _id values are unique for each member
      { _id: 2, host: "mongo23.raskepoter.no:27017", priority: 0.5 }, // Corrected _id from 1 to 2 for uniqueness
      { _id: 3, host: "mongo20.raskepoter.no:27017", arbiterOnly: true }
    ]
  },
  { force: true }
);

4.2 Fetch backups and restore
$ mkdir mongodb-backup
$ aws s3 sync s3://ffe-mongodb-backups/mongo12.raskepoter.no/2020/11/01/ ./mongodb-backup/ --region eu-west-1
$ sudo mongorestore -d flyfish --gzip --drop ./mongodb-backup/flyfish/

4.3 Add more replicas to this replicaset:
$ mongosh
> rs.add("mongo20.raskepoter.no:27017", true)
> rs.add("mongo21.raskepoter.no:27017")
> rs.add("mongo22.raskepoter.no:27017")
> rs.add("mongo23.raskepoter.no:27017")
> rs.config()

> rs.remove("mongo20.raskepoter.no:27017")
> rs.remove("mongo21.raskepoter.no:27017")
> rs.remove("mongo22.raskepoter.no:27017")
> rs.remove("mongo23.raskepoter.no:27017")
> rs.config({ force: true })

4.4 Set priority on one master:
$ mongo
> cfg = rs.conf();
> cfg.members[0].priority = 10;
> rs.reconfig(cfg);


--------------------------------------------------------------------------------
5. On SECONDARY
--------------------------------------------------------------------------------
$ mongosh
> db.getMongo().setReadPref("primaryPreferred")

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
127.0.0.1           localhost mongo21.raskepoter.no

10.1.16.220     mongo20.raskepoter.no
10.1.16.221     mongo21.raskepoter.no
10.1.32.222     mongo22.raskepoter.no
10.1.0.223      mongo23.raskepoter.no

EOF

hostname mongo21.raskepoter.no
cat > /etc/hostname <<'EOF'
mongo21.raskepoter.no
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
  bindIp: 172.31.0.221,127.0.0.1
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

MONGODUMP=/usr/bin/mongoshdump
PARAM="--gzip -o "

/usr/bin/find /var/backups/mongodb/ -type f | xargs rm

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
    /usr/bin/mongosh flyfish $i;
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
    /usr/bin/mongosh flyfish $i;
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
0 4 * * *   /usr/bin/find /var/backups/mongodb/ -type f -mtime 1 | xargs rm

# Send disk warnings
*/5 * * * * /srv/aws-scripts-mon/mon-put-instance-data.pl --mem-util --mem-used-incl-cache-buff --mem-used --mem-avail --disk-space-util --disk-path / --disk-space-used --disk-space-avail

EOF
echo "Adding to crontab for root from file /tmp/crontab.root"
crontab /tmp/crontab.root

# Watch script

cat > /home/ubuntu/email-on-restart.sh <<'EOF'
#!/bin/bash

FROM="mongo21@litt.no"
TO="sorenso@gmail.com"
SUBJECT="Mongodb service mogno21 restarted"
BODY="You should check it out if it happens to often."

aws ses send-email \
  --from "$FROM" \
  --destination "ToAddresses=$TO" \
  --message "Subject={Data=$SUBJECT,Charset=utf8},Body={Text={Data=$BODY,Charset=utf8}}"
EOF

sudo chmod 755 /home/ubuntu/email-on-restart.sh



# Enable ENA
# sudo apt-get update && sudo apt-get upgrade -y linux-aws
# aws ec2 modify-instance-attribute --instance-id instance_id --ena-support
# aws ec2 modify-instance-attribute --region eu-west-1 --instance-id $EC2_INSTANCE_ID --ena-support

# Create new image
IMAGE_NAME=`get_new_image_name ${INSTANCE_NAME}-ami`
echo "Instance-id: ${EC2_INSTANCE_ID}"
echo "New image name: ${IMAGE_NAME}"
aws ec2 create-image --instance-id ${EC2_INSTANCE_ID} --name ${IMAGE_NAME} --region eu-west-1


