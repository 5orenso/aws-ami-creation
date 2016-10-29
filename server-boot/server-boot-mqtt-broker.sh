#!/bin/bash

export LC_ALL=en_US.UTF-8

# ----------------------------------------------------------------
# Get the application you want to run on this server:

# Create an IAM policy for the bridge
aws iot create-policy --policy-name mqtt-bridge --policy-document '{"Version": "2012-10-17","Statement": [{"Effect": "Allow","Action": "iot:*","Resource": "*"}]}'

# Place yourself in Mosquitto directory
# And create certificates and keys, note the certificate ARN
cd /etc/mosquitto/certs/
aws iot create-keys-and-certificate --set-as-active --certificate-pem-outfile cert.crt --private-key-outfile private.key --public-key-outfile public.key

# List the certificate and copy the ARN in the form of
# arn:aws:iot:eu-central-1:0123456789:cert/xyzxyz
aws_iot_arn=$(aws iot list-certificates | jq -rc '.certificates[0].certificateArn')

# Attach the policy to your certificate
aws iot attach-principal-policy --policy-name mqtt-bridge --principal ${aws_iot_arn}

# Add read permissions to private key and client cert
chmod 644 private.key
chmod 644 cert.crt

# Download root CA certificate
wget https://www.symantec.com/content/en/us/enterprise/verisign/roots/VeriSign-Class%203-Public-Primary-Certification-Authority-G5.pem -O rootCA.pem

aws_iot_endpoint_address=$(aws iot describe-endpoint | jq -rc '.endpointAddress')

# TODO: Parse AWS IoT endpoint from API.
cat > /etc/mosquitto/conf.d/bridge.conf <<'EOF'
# =================================================================
# Bridges to AWS IOT
# =================================================================

# AWS IoT endpoint, use AWS CLI 'aws iot describe-endpoint'
connection awsiot
address ${aws_iot_endpoint_address}:8883

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
description “Mosquitto MQTT broker”
author “Sorenso <sorenso@gmail.com>”

start on (virtual-filesystems and net-device-up IFACE=eth0)
stop on runlevel [06]

respawn
respawn limit 10 5    # Die if respawn more than 10 times in 5 sec.

script
    exec /usr/local/sbin/mosquitto -c /etc/mosquitto/mosquitto.conf
end script

#-----[ HOWTO ]--------------------------------------------------
# sudo initctl start mosquitto
#
EOF

# Run the MQTT Broker
service mosquitto start

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
