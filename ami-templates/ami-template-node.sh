#!/bin/bash
set -e -x

INSTANCE_NAME='node-base'

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

export UCF_FORCE_CONFOLD=1
export DEBIAN_FRONTEND=noninteractive
EC2_INSTANCE_ID=`get_ec2_instance_id`

sudo add-apt-repository ppa:ubuntu-toolchain-r/test --yes
sudo apt-get update

# AWS tools and other software
sudo apt-get install jq awscli git make g++ \
build-essential checkinstall \
libreadline-gplv2-dev libncursesw5-dev libssl-dev \
libsqlite3-dev tk-dev libgdbm-dev libc6-dev libbz2-dev \
libgconf-2-4 libatk1.0-0 libatk-bridge2.0-0 libgdk-pixbuf2.0-0 libgtk-3-0 libgbm-dev libnss3-dev libxss-dev \
--yes

sudo apt-get install --only-upgrade libstdc++6 \
--yes

# Tag instance
aws ec2 create-tags --resources $EC2_INSTANCE_ID --tags Key=Name,Value=ami-creator-$INSTANCE_NAME --region eu-west-1

sudo apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade

NODE_VERSION="16.13.2"

sudo curl -o /usr/local/node-v$NODE_VERSION-linux-x64.tar.xz https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz
cd /usr/local && sudo tar xf /usr/local/node-v$NODE_VERSION-linux-x64.tar.xz
sudo ln -s /usr/local/node-v$NODE_VERSION-linux-x64/bin/node /usr/local/bin/node
sudo ln -s /usr/local/node-v$NODE_VERSION-linux-x64/bin/npm /usr/local/bin/npm

# Datadog
#DD_API_KEY=xxxxxyyyyzzzzz bash -c "$(curl -L https://raw.githubusercontent.com/DataDog/dd-agent/master/packaging/datadog-agent/source/install_agent.sh)"

# Telegraf
cd /tmp/
wget https://dl.influxdata.com/telegraf/releases/telegraf_1.2.1_amd64.deb
dpkg -i telegraf_1.2.1_amd64.deb

# Set timedatectl
sudo timedatectl set-timezone Europe/Oslo
sudo timedatectl set-ntp on

# Disable CPU thief unattended-upgr
sudo cp  /usr/share/unattended-upgrades/20auto-upgrades-disabled  /etc/apt/apt.conf.d/

IMAGE_NAME=`get_new_image_name ${INSTANCE_NAME}-ami`
aws ec2 create-image --instance-id $EC2_INSTANCE_ID --name $IMAGE_NAME --region eu-west-1
