#!/bin/bash

export LC_ALL=en_US.UTF-8

if [ ! -z "$ELASTIC_IP_ALLOCATION_ID" ]; then
    # Associate Elastic IP with instance if not associated before.
    INSTANCE_ID=`curl http://169.254.169.254/latest/meta-data/instance-id`
    CURRENT_INSTANCE_ID=$(/usr/bin/aws ec2 describe-addresses --allocation-ids $ELASTIC_IP_ALLOCATION_ID --region eu-west-1 | jq -r '.Addresses[].InstanceId')
    if [[ $CURRENT_INSTANCE_ID == null ]] ; then
        /usr/bin/aws ec2 associate-address --instance-id $INSTANCE_ID --allocation-id $ELASTIC_IP_ALLOCATION_ID --allow-reassociation --region eu-west-1
    fi
fi

aws_iot_endpoint_address=$(aws iot describe-endpoint | jq -rc '.endpointAddress')

sed -i "s/{{aws_iot_endpoint_address}}/${aws_iot_endpoint_address}/g" /etc/mosquitto/conf.d/bridge.conf

# Run the MQTT Broker
service mosquitto start
