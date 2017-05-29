#!/bin/bash
set -e -x

INSTANCE_NAME='mqtt-broker'

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
apt-get install jq awscli git make g++ --yes

# Tag instance
aws ec2 create-tags --resources $EC2_INSTANCE_ID --tags Key=Name,Value=ami-creator-$INSTANCE_NAME --region eu-west-1


# ---[ Install custom software ]------------------------------------------------
apt-add-repository ppa:mosquitto-dev/mosquitto-ppa
apt-get update
apt-get install mosquitto mosquitto-clients unzip --yes

curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
unzip awscli-bundle.zip
./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
mv /usr/bin/aws /usr/bin/aws.old
ln -s /usr/local/bin/aws /usr/bin/aws


cat > /etc/mosquitto/conf.d/bridge.conf <<'EOF'
# =================================================================
# Bridges to AWS IOT
# =================================================================

# AWS IoT endpoint, use AWS CLI 'aws iot describe-endpoint'
connection awsiot
address {{aws_iot_endpoint_address}}:8883

# Specifying which topics are bridged
topic awsiot_to_localgateway in 1
topic localgateway_to_awsiot out 1
topic both_directions both 1

# Setting protocol version explicitly
bridge_protocol_version mqttv311
bridge_insecure false

# Bridge connection name and MQTT client Id,
# enabling the connection automatically when the broker starts.
cleansession true
clientid bridgeawsiot
start_type automatic
notifications false
log_type all

# =================================================================
# Certificate based SSL/TLS support
# -----------------------------------------------------------------
# Path to the rootCA
bridge_cafile /etc/mosquitto/certs/rootCA.pem

# Path to the PEM encoded client certificate
bridge_certfile /etc/mosquitto/certs/cert.crt

# Path to the PEM encoded client private key
bridge_keyfile /etc/mosquitto/certs/private.key
EOF


cat > /etc/init/mosquitto.conf <<'EOF'
# ----------------------------------------------------------------------
# MQTT - broker instance
#
description "Mosquitto MQTT broker"
author "Sorenso <sorenso@gmail.com>"

start on (virtual-filesystems and net-device-up IFACE=eth0)
stop on runlevel [06]

respawn
respawn limit 10 5    # Die if respawn more than 10 times in 5 sec.

script
    exec /usr/sbin/mosquitto -c /etc/mosquitto/mosquitto.conf
end script

#-----[ HOWTO ]--------------------------------------------------
# sudo initctl start mosquitto
#
EOF

# Place yourself in Mosquitto directory
# And create certificates and keys, note the certificate ARN
cd /etc/mosquitto/certs/
aws iot create-keys-and-certificate --set-as-active --certificate-pem-outfile cert.crt --private-key-outfile private.key --public-key-outfile public.key  --region eu-west-1

# List the certificate and copy the ARN in the form of
# arn:aws:iot:eu-central-1:0123456789:cert/xyzxyz
aws_iot_arn=$(aws iot list-certificates --region eu-west-1 | jq -r '.certificates[0].certificateArn')

# Attach the policy to your certificate
aws_mqtt_broker_policy=$(aws iot list-policies --ascending-order --region eu-west-1 | jq -r '.policies[].policyName')
aws iot attach-principal-policy --policy-name ${aws_mqtt_broker_policy} --principal ${aws_iot_arn}  --region eu-west-1

# Add read permissions to private key and client cert
chmod 644 private.key
chmod 644 cert.crt

# Download root CA certificate
wget https://www.symantec.com/content/en/us/enterprise/verisign/roots/VeriSign-Class%203-Public-Primary-Certification-Authority-G5.pem -O rootCA.pem


# ---[ /Install custom software ]-----------------------------------------------


# Datadog
#DD_API_KEY=xxxxxyyyyzzzzz bash -c "$(curl -L https://raw.githubusercontent.com/DataDog/dd-agent/master/packaging/datadog-agent/source/install_agent.sh)"

# Cloudwatch logs
curl -k https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py -O
cat > /tmp/awslogs.conf <<'EOF'
[general]
state_file = /var/awslogs/state/agent-state
EOF
python ./awslogs-agent-setup.py -n --region eu-west-1 -c /tmp/awslogs.conf

# Logs to AWS Cloudwatch
cat > /var/awslogs/etc/awslogs.conf <<'EOF'
[general]
state_file = /var/awslogs/state/agent-state

[/var/log/mosquitto/mosquitto.log]
datetime_format = %Y-%m-%d %H:%M:%S
file = /var/log/mosquitto/mosquitto.log
buffer_duration = 5000
log_stream_name = {instance_id}
initial_position = start_of_file
log_group_name = mosquitto/mosquitto.log
EOF

# Restart logservice
service awslogs restart

# Set timedatectl
sudo timedatectl set-timezone Europe/Oslo
sudo timedatectl set-ntp on

IMAGE_NAME=`get_new_image_name ${INSTANCE_NAME}-ami`
aws ec2 create-image --instance-id $EC2_INSTANCE_ID --name $IMAGE_NAME --region eu-west-1
