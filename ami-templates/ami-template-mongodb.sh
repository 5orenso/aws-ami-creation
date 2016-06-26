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
apt-get install jq awscli git make g++ htop itop dstat --yes

# Tag instance
aws ec2 create-tags --resources $EC2_INSTANCE_ID --tags Key=Name,Value=ami-creator-$INSTANCE_NAME --region eu-west-1

sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv EA312927
echo "deb http://repo.mongodb.org/apt/ubuntu "$(lsb_release -sc)"/mongodb-org/3.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.2.list
sudo apt-get update
sudo apt-get install -y mongodb-org

# Datadog
#DD_API_KEY=xxxxxyyyyzzzzz bash -c "$(curl -L https://raw.githubusercontent.com/DataDog/dd-agent/master/packaging/datadog-agent/source/install_agent.sh)"

# Cloudwatch logs
#curl https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py -O
#cat > /tmp/awslogs.conf <<'EOF'
#[general]
#state_file = /var/awslogs/state/agent-state
#EOF
#python ./awslogs-agent-setup.py -n --region eu-west-1 -c /tmp/awslogs.conf


# noatime for Mongodb performance.
mv /etc/fstab /etc/fstab.old
cat > /etc/fstab <<'EOF'
LABEL=cloudimg-rootfs   /        ext4   defaults,noatime,discard        0 0
/dev/xvdb               /mnt     auto   defaults,nobootwait,comment=cloudconfig 0       2
EOF

cat > /home/ubuntu/README.txt <<'EOF'
## Some instructions on how this is setup

A. Choose your lates AMI and launch a new instance:
       mongo0.flyfisheurope.com    eu-west-1c
       mongo1.flyfisheurope.com    eu-west-1b
       mongo2.flyfisheurope.com    eu-west-1a

Attach network interface when launcing instance:
       mongo0.flyfisheurope.com    mongodb-replicaset-0    eni-e9dca791
       mongo1.flyfisheurope.com    mongodb-replicaset-1    eni-5e821d02
       mongo2.flyfisheurope.com    mongodb-replicaset-2    eni-98fc10d5

--------------------------------------------------------------------------------

1. Edit /etc/hosts and set 127.0.0.1 to the correct hostname:
$ sudo vim /etc/hosts

2. Edit /etc/hostname and set the correct hostname:
$ sudo vim /etc/hostname

3. Set hostname with:
$ sudo hostname mongo0.flyfisheurope.com

4. On primary
4.1 Initiate ReplicaSet with only one member
$ mongo
> rs.initiate()

4.2 Fetch backups and restore
$ mkdir flyfish
$ aws s3 sync s3://ffe-mongodb-backups/ip-10-39-40-33/2016/06/25/flyfish/ ./flyfish/ --region eu-west-1
$ sudo mongorestore -d flyfish --drop ./flyfish/

4.3 Add more replicas to this replicaset:
$ mongo
> rs.add("mongo1.flyfisheurope.com:27017")
> rs.add("mongo2.flyfisheurope.com:27017",true)
> rs.config()

5. On replica
$ mongo
> db.setSlaveOk()


EOF


# Default setup of replica sets.
cat > /etc/hosts <<'EOF'
# MongoDB setup.
127.0.0.1           localhost mongo0.flyfisheurope.com
172.30.2.250        mongo0.flyfisheurope.com
172.30.1.250        mongo1.flyfisheurope.com
172.30.0.250        mongo2.flyfisheurope.com
EOF

hostname mongo0.flyfisheurope.com
cat > /etc/hostname <<'EOF'
mongo0.flyfisheurope.com
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
  #bindIp: 127.0.0.1 - Important to comment this line
  port: 27017

#processManagement:

#security:

#operationProfiling:

#replication:
replication:
   oplogSizeMB: 1
   replSetName: rs0

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
PARAM=" -o "

/bin/mkdir -p $DIR/$DATE

echo -e "-------------------------------------------------------------------------------\n" > $DIR/$DATE/output.log
echo -e "$0 $DATE\n" >> $DIR/$DATE/output.log
echo -e `/bin/date` >> $DIR/$DATE/output.log

$MONGODUMP $PARAM $DIR/$DATE >> $DIR/$DATE/output.log 2>&1

echo -e "\nDone" >> $DIR/$DATE/output.log
echo -e `/bin/date` >> $DIR/$DATE/output.log
echo -e "-------------------------------------------------------------------------------\n" >> $DIR/$DATE/output.log

/usr/bin/aws s3 sync /var/backups/mongodb/$HOSTNAME/ s3://ffe-mongodb-backups/$HOSTNAME/

EOF

# Turn of defrag option to speed up file system.
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

# Cron - from the repo
read -r -d '' ROOT_CRONTAB_LINES <<- EOM
# Cleanup old backups.
0 4 * * *   /usr/bin/find /var/backups/mongodb/ -type f -mtime +30 | xargs rm
EOM
(crontab -l; echo "$ROOT_CRONTAB_LINES" ) | crontab -u root -

# Create new image
IMAGE_NAME=`get_new_image_name ${INSTANCE_NAME}-ami`
aws ec2 create-image --instance-id $EC2_INSTANCE_ID --name $IMAGE_NAME --region eu-west-1
