#!/bin/bash

export LC_ALL=en_US.UTF-8

# ELASTIC_IP_ALLOCATION_ID= "Fn::ImportValue" : "iotMqttBrokerElasticIpAllocationId"
# ELASTIC_IP="Fn::ImportValue" : "iotMqttBrokerElasticIp"

INSTANCE_ID=`curl http://169.254.169.254/latest/meta-data/instance-id`
if [ ! -z \"$ELASTIC_IP_ALLOCATION_ID\" ]; then
    # Associate Elastic IP with instance if not associated before.
    CURRENT_INSTANCE_ID=$(/usr/bin/aws ec2 describe-addresses --allocation-ids $ELASTIC_IP_ALLOCATION_ID --region eu-west-1 | jq -r '.Addresses[].InstanceId')
    if [[ $CURRENT_INSTANCE_ID == null ]] ; then
        /usr/bin/aws ec2 associate-address --instance-id $INSTANCE_ID --allocation-id $ELASTIC_IP_ALLOCATION_ID --allow-reassociation --region eu-west-1
    fi
fi

# Setup IoT endpoint for Mqtt Broker
AWS_IOT_ENDPOINT_ADDRESS=$(/usr/bin/aws iot describe-endpoint --region eu-west-1 | jq -r '.endpointAddress')

sed -i \"s/{{aws_iot_endpoint_address}}/${AWS_IOT_ENDPOINT_ADDRESS}/g\" /etc/mosquitto/conf.d/bridge.conf

# Run the MQTT Broker
service mosquitto restart
