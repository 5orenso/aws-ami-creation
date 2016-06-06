#!/usr/bin/env bash

# Read command line input:
while [[ $# > 1 ]]
do
key="$1"

case $key in
    -h|--help)
    HELP="$2"
    shift # past argument
    ;;
    -n|--auto-scaling-group-name)
    AUTO_SCALING_GROUP_NAME="$2"
    shift # past argument
    ;;
    -l|--launch-config-name)
    LAUNCH_CONFIG_NAME="$2"
    shift # past argument
    ;;
    -c|--cooldown)
    COOLDOWN="$2"
    shift # past argument
    ;;
    -m|--size-min)
    SIZE_MIN="$2"
    shift # past argument
    ;;
    -M|--size-max)
    SIZE_MAX="$2"
    shift # past argument
    ;;
    -d|--size-desired)
    SIZE_DESIRED="$2"
    shift # past argument
    ;;
    -h|--health-check-grace)
    HEALTH_CHECK_GRACE_PERIODE="$2"
    shift # past argument
    ;;
    -s|--subnet-list)
    SUBNET_LIST="$2"
    shift # past argument
    ;;
    -r|--aws-region)
    AWS_REGION="$2"
    shift # past argument
    ;;
    -p|--aws-profile)
    AWS_PROFILE="$2"
    shift # past argument
    ;;
    *)
    # unknown option
    ;;
esac
shift # past argument or value
done

if [ ! -z "$HELP" ]; then
    echo "bash ${0} "
    echo "    [-h|--help 1]"
    echo "    [-c|--cooldown <seconds to wait for another autoscaling action>]"
    echo "    [-d|--size-desired <desired servers now>]"
    echo "    [-h|--health-check-grace <seconds between health checks>]"
    echo "     -l|--launch-config-name <launch configuration name>"
    echo "    [-m|--size-min <min auto scaling group size>]"
    echo "    [-M|--size-max <max auto scaling group size>]"
    echo "     -n|--auto-scaling-group-name <auto scaling group name>"
    echo "     -s|--subnet-list <comma separated list of subnets>"
    echo "    [-r|--aws-region <awd region>]"
    echo "    [-p|--aws-profile <aws profile>]"
    echo ""
    echo "bash ${0}"
    echo "    -l <name of launch config>"
    echo "    -n <name of auto scaling group>"
    echo "    -s <comma separated list of subnets>"
    echo ""
    exit 1;
fi

# Default values
AWS_REGION=${AWS_REGION:-'eu-west-1'}
SIZE_MIN=${SIZE_MIN:-1}
SIZE_MAX=${SIZE_MAX:-1}
SIZE_DESIRED=${SIZE_DESIRED:-1}
COOLDOWN=${COOLDOWN:-600}
HEALTH_CHECK_GRACE_PERIODE=${HEALTH_CHECK_GRACE_PERIODE:-60}

# Optional value
if [ ! -z "$AWS_PROFILE" ]; then
    AWS_PROFILE="--profile ${AWS_PROFILE}"
fi

# Required values
if [ -z "$AUTO_SCALING_GROUP_NAME" ]; then
    EXIT_MISSING=1
    echo '* Missing "auto scaling group name". Please set with:'
    echo '    -n|--auto-scaling-group-name <name of autoscaling group>'
    echo '    Example usage:'
    echo '        -n ag-my-auto-scaling-group'
fi
if [ -z "$LAUNCH_CONFIG_NAME" ]; then
    EXIT_MISSING=1
    echo '* Missing "launch-config-name". Please set with:'
    echo '    -l|--launch-config-name <name of launch config>'
    echo '    Example usage:'
    echo '        -l lc-node-2016-06-01'
    echo '    Existing launch configurations:'
    aws autoscaling describe-launch-configurations $AWS_PROFILE | jq -c '.LaunchConfigurations[] | { name: .LaunchConfigurationName, profile: .IamInstanceProfile, date: .CreatedTime }'
    echo ''
fi
if [ -z "$SUBNET_LIST" ]; then
    EXIT_MISSING=1
    echo '* Missing "subnet-list". Please set with:'
    echo '    -s|--subnet-list <comma separated list of subnets>'
    echo '    Example usage:'
    echo '        -s subnet-xxxxxx1a,subnet-xxxxxx1b,subnet-xxxxxx1c'
    echo '    Existing subnets:'
    aws ec2 describe-subnets $AWS_PROFILE | jq -c '.Subnets[] | { id: .SubnetId, zone: .AvailabilityZone, vpc: .VpcId, ip: .CidrBlock, publicIP: .MapPublicIpOnLaunch, default: .DefaultForAz }'
    echo ''
fi
if [ ! -z "$EXIT_MISSING" ]; then
    echo ""
    echo "bash ${0}"
    echo "    -l <name of launch config>"
    echo "    -n <name of auto scaling group>"
    echo "    -s <comma separated list of subnets>"
    exit 1;
fi

echo "AUTO_SCALING_GROUP_NAME    : ${AUTO_SCALING_GROUP_NAME}"
echo "LAUNCH_CONFIG_NAME         : ${LAUNCH_CONFIG_NAME}"
echo "SUBNET_LIST                : ${SUBNET_LIST}"
echo "SIZE_MIN                   : ${SIZE_MIN}"
echo "SIZE_MAX                   : ${SIZE_MAX}"
echo "SIZE_DESIRED               : ${SIZE_DESIRED}"
echo "COOLDOWN                   : ${COOLDOWN}"
echo "HEALTH_CHECK_GRACE_PERIODE : ${HEALTH_CHECK_GRACE_PERIODE}"
echo ""
echo "Running aws autoscaling create-auto-scaling-group:"
echo "--------------------------------------------------"

AG_RUN_OUTPUT=$(aws autoscaling create-auto-scaling-group $AWS_PROFILE \
    --auto-scaling-group-name $AUTO_SCALING_GROUP_NAME \
    --launch-configuration-name $LAUNCH_CONFIG_NAME \
    --min-size $SIZE_MIN \
    --max-size $SIZE_MAX \
    --desired-capacity $SIZE_DESIRED \
    --default-cooldown $COOLDOWN \
    --vpc-zone-identifier $SUBNET_LIST \
    --termination-policies "OldestInstance" \
    --health-check-grace-period $HEALTH_CHECK_GRACE_PERIODE \
    --tags ResourceId=$AUTO_SCALING_GROUP_NAME,ResourceType=auto-scaling-group,Key=Role,Value=${LAUNCH_CONFIG_NAME},Key=Name,Value=AG-${AUTO_SCALING_GROUP_NAME})

echo $AG_RUN_OUTPUT
echo 'Done!'

echo ""
echo "Now jump to the EC2 console page to find your new Auto Scaling Group:"
echo "https://${AWS_REGION}.console.aws.amazon.com/ec2/autoscaling/home?region=${AWS_REGION}#AutoScalingGroups:view=details"
echo ""
