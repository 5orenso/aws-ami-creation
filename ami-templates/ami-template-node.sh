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

# Instance metadata requires a session token (IMDSv2).
get_ec2_instance_id() {
    IMDS_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
    curl -s -H "X-aws-ec2-metadata-token: ${IMDS_TOKEN}" http://169.254.169.254/latest/meta-data/instance-id
}

export UCF_FORCE_CONFOLD=1
export DEBIAN_FRONTEND=noninteractive
EC2_INSTANCE_ID=`get_ec2_instance_id`

sudo apt-get update

sudo apt-get install -y \
    libnss3 \
    libatk1.0-0t64 \
    libatk-bridge2.0-0t64 \
    libx11-xcb1 \
    libdrm2 \
    libgbm1 \
    libxdamage1 \
    libxcomposite1 \
    libxext6 \
    libxfixes3 \
    libxrandr2 \
    libgtk-3-0t64 \
    libxshmfence1 \
    libxrender1 \
    libxcb1 \
    libxss1 \
    fonts-liberation \
    xdg-utils \
    ffmpeg \
    libasound2t64

# AWS tools and other software
sudo apt-get install jq git make g++ \
build-essential unzip \
--yes

# AWS CLI v2 (the awscli apt package is gone on Ubuntu 24.04)
cd /tmp
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip -q awscliv2.zip
sudo ./aws/install
cd -
#  \
# libreadline-gplv2-dev libncursesw5-dev libssl-dev \
# libsqlite3-dev tk-dev libgdbm-dev libc6-dev libbz2-dev \
# libgconf-2-4 libatk1.0-0 libatk-bridge2.0-0 libgdk-pixbuf2.0-0 libgtk-3-0 libgbm-dev libnss3-dev libxss-dev \
# sudo apt-get install --only-upgrade libstdc++6 --yes

# Tag instance
aws ec2 create-tags --resources $EC2_INSTANCE_ID --tags Key=Name,Value=ami-creator-$INSTANCE_NAME --region eu-west-1

sudo apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade --yes

NODE_VERSION="24.18.1"

sudo curl -o /usr/local/node-v$NODE_VERSION-linux-x64.tar.xz https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz
cd /usr/local && sudo tar xf /usr/local/node-v$NODE_VERSION-linux-x64.tar.xz
sudo ln -s /usr/local/node-v$NODE_VERSION-linux-x64/bin/node /usr/local/bin/node
sudo ln -s /usr/local/node-v$NODE_VERSION-linux-x64/bin/npm /usr/local/bin/npm

# Datadog
#DD_API_KEY=xxxxxyyyyzzzzz bash -c "$(curl -L https://raw.githubusercontent.com/DataDog/dd-agent/master/packaging/datadog-agent/source/install_agent.sh)"

# Telegraf
# cd /tmp/
# wget https://dl.influxdata.com/telegraf/releases/telegraf_1.2.1_amd64.deb
# dpkg -i telegraf_1.2.1_amd64.deb

# Set timedatectl
sudo timedatectl set-timezone Europe/Oslo
sudo timedatectl set-ntp on

# Disable CPU thief unattended-upgr
sudo cp  /usr/share/unattended-upgrades/20auto-upgrades-disabled  /etc/apt/apt.conf.d/

IMAGE_NAME=`get_new_image_name ${INSTANCE_NAME}-ami`
# --no-reboot keeps this script alive so it can wait for the image and shut the
# build server down (instance-initiated-shutdown-behavior is terminate).
IMAGE_ID=$(aws ec2 create-image --instance-id $EC2_INSTANCE_ID --name $IMAGE_NAME --region eu-west-1 --no-reboot | jq -r '.ImageId')
echo "Waiting for image ${IMAGE_ID} (${IMAGE_NAME}) to become available..."
WAIT_OK=""
for i in 1 2 3 4; do
    if aws ec2 wait image-available --image-ids $IMAGE_ID --region eu-west-1; then
        WAIT_OK=1
        break
    fi
done
if [ ! -z "$WAIT_OK" ]; then
    echo "Image ${IMAGE_ID} is available. Shutting down the build server."
    sudo shutdown -h now
else
    echo "Image ${IMAGE_ID} is still not available. Leaving the build server running - check the AMI console and terminate it manually."
fi
