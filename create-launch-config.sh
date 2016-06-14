#!/usr/bin/env bash


# Read command line input:
while [[ $# > 1 ]]; do
    key="$1"
    case $key in
        -h|--help)
            HELP="$2"
            shift # past argument
        ;;
        -c|--cloudwatch-monitoring)
            CLOUDWATCH_MONITORING="$2"
            shift # past argument
        ;;
        -e|--ebs-optimized)
            EBS_OPTIMIZED="$2"
            shift # past argument
        ;;
        -I|--ami-id)
            INSTANCE_ID="$2"
            shift # past argument
        ;;
        -i|--iam-profile)
            IAM_PROFILE="$2"
            shift # past argument
        ;;
        -k|--key-pair)
            KEY_PAIR="$2"
            shift # past argument
        ;;
        -n|--launch-config-name)
            LAUNCH_CONFIG_NAME="$2"
            shift # past argument
        ;;
        -s|--secret-user-data-file)
            SECRET_USER_DATA_FILE="$2"
            shift # past argument
        ;;
        -t|--instance-type)
            INSTANCE_TYPE="$2"
            shift # past argument
        ;;
        -g|--security-group)
            SECURITY_GROUP="$2"
            shift # past argument
        ;;
        -u|--user-data-file)
            USER_DATA_FILE="$2"
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
    echo "    [-c|--cloudwatch-monitoring <set to 1 if you want monitoring>]"
    echo "    [-e|--ebs-optimized <set to 1 if you want ebs optimized file system>]"
    echo "     -g|--security-group <id of security group>"
    echo "     -I|--ami-id <ami id>"
    echo "     -i|--iam-profile <iam profile for the servers>"
    echo "     -k|--key-pair <name of key-pair>"
    echo "     -n|--launch-config-name <name of launch configuration>"
    echo "    [-t|--instance-type <instance type>]"
    echo "     -u|--user-data-file <launch configuration file>"
    echo "    [-s|--secret-user-data-file <secret launch configuration file>]"
    echo "    [-r|--aws-region <awd region>]"
    echo "    [-p|--aws-profile <aws profile>]"
    echo ""
    echo "bash ${0}"
    echo "    -g <id of security group>"
    echo "    -I <ami id>"
    echo "    -i <iam role>"
    echo "    -k <name of key-pair>"
    echo "    -n <name of launch config>"
    echo "    -u <user data file>"
    echo "    -s <secret user data file>"
    echo ""
    exit 1;
fi

# Optional value
if [ ! -z "$EBS_OPTIMIZED" ]; then
    EBS_OPTIMIZED='ebs-optimized'
fi
if [ ! -z "$CLOUDWATCH_MONITORING" ]; then
    CLOUDWATCH_MONITORING='true'
fi
if [ ! -z "$AWS_PROFILE" ]; then
    AWS_PROFILE="--profile ${AWS_PROFILE}"
fi

# Default values
AWS_REGION=${AWS_REGION:-'eu-west-1'}
# Instance type. Default is fine.
EBS_OPTIMIZED=${EBS_OPTIMIZED:-'no-ebs-optimized'}
CLOUDWATCH_MONITORING=${CLOUDWATCH_MONITORING:-false}
INSTANCE_TYPE=${INSTANCE_TYPE:-'m3.medium'}

# Required values
if [ -z "$INSTANCE_ID" ]; then
    EXIT_MISSING=1
    echo ''
    echo '* Missing "ami instance id". Please set with:'
    echo '    -I|--ami-id <ami id>'
    echo '    Example usage:'
    echo '        -I ami-MyNodeAmi'
    echo '    Existing images:'
    aws ec2 describe-images --owners self $AWS_PROFILE | jq -c '.Images[] | { id: .ImageId, name: .Name }'
    echo ''
fi
if [ -z "$IAM_PROFILE" ]; then
    EXIT_MISSING=1
    echo ''
    echo '* Missing "iam profile". Please set with:'
    echo '    -i|--iam-profile <iam profile for the servers>'
    echo '    Example usage:'
    echo '        -i role-node-server'
    echo '    Existing roles:'
    aws iam list-roles $AWS_PROFILE | jq -c '.Roles[] | {name: .RoleName}'
    echo ''
fi
if [ -z "$KEY_PAIR" ]; then
    EXIT_MISSING=1
    echo ''
    echo '* Missing "key-pair". Please set with:'
    echo '    -k|--key-pair <name of key-pair>'
    echo '    Example usage:'
    echo '        -k my-key-pair'
    echo '    Existing key-pairs:'
    aws ec2 describe-key-pairs $AWS_PROFILE | jq -c '.KeyPairs[] | { name: .KeyName }'
    echo ''
fi
if [ -z "$LAUNCH_CONFIG_NAME" ]; then
    EXIT_MISSING=1
    echo ''
    echo '* Missing "launch-config-name". Please set with:'
    echo '    -n|--launch-config-name <name of launch config>'
    echo '    Example usage:'
    echo '        -n lc-node-2016-06-01'
fi
if [ -z "$SECURITY_GROUP" ]; then
    EXIT_MISSING=1
    echo ''
    echo '* Missing "security-group". Please set with:'
    echo '    -g|--security-group <id of security group>'
    echo '    Example usage:'
    echo '        -g sg-12345678'
    echo '    Existing security groups:'
    aws ec2 describe-security-groups $AWS_PROFILE | jq -c '.SecurityGroups[] | {id: .GroupId, name: .GroupName, desc: .Description}'
    echo ''
fi
if [ -z "$USER_DATA_FILE" ]; then
    EXIT_MISSING=1
    echo ''
    echo '* Missing "user data file". Please set with:'
    echo '    -u|--user-data-file <launch configuration file>'
    echo '    Example usage:'
    echo '        -u launch-configuration/launch-config-node-ami.sh'
    echo '    Existing user data files:'
    ls launch-configurations/*.sh | cat
    echo ''
fi
if [ ! -z "$EXIT_MISSING" ]; then
    echo ""
    echo "bash ${0}"
    echo "    -g <id of security group>"
    echo "    -I <ami id>"
    echo "    -i <iam profile for the servers>"
    echo "    -k <name of key-pair>"
    echo "    -n <name of launch config>"
    echo "    -u <user data file>"
    echo "    -s <secret user data file>"
    echo ""
    exit 1;
fi

if [ ! -z "$SECRET_USER_DATA_FILE" ]; then
    cat $SECRET_USER_DATA_FILE $USER_DATA_FILE > /tmp/$LAUNCH_CONFIG_NAME
    USER_DATA_FILE="/tmp/${LAUNCH_CONFIG_NAME}"
fi

echo "CLOUDWATCH_MONITORING : ${CLOUDWATCH_MONITORING}"
echo "EBS_OPTIMIZED         : ${EBS_OPTIMIZED}"
echo "IAM_PROFILE           : ${IAM_PROFILE}"
echo "INSTANCE_ID           : ${INSTANCE_ID}"
echo "INSTANCE_TYPE         : ${INSTANCE_TYPE}"
echo "KEY_PAIR              : ${KEY_PAIR}"
echo "LAUNCH_CONFIG_NAME    : ${LAUNCH_CONFIG_NAME}"
echo "SECURITY_GROUP        : ${SECURITY_GROUP}"
echo ""
echo "Running aws autoscaling create-launch-configuration:"
echo "----------------------------------------------------"

LC_RUN_OUTPUT=$(aws autoscaling create-launch-configuration $AWS_PROFILE \
    --region $AWS_REGION \
    --launch-configuration-name $LAUNCH_CONFIG_NAME \
    --key-name $KEY_PAIR \
    --image-id $INSTANCE_ID \
    --security-groups $SECURITY_GROUP \
    --instance-type $INSTANCE_TYPE \
    --user-data file://$USER_DATA_FILE \
    --instance-monitoring Enabled=$CLOUDWATCH_MONITORING \
    --$EBS_OPTIMIZED \
    --iam-instance-profile $IAM_PROFILE \
    --block-device-mappings file://block-device-mapping.json)

echo $LC_RUN_OUTPUT
echo 'Done!'

echo ""
echo "Now jump to the EC2 console page to find your new Launch Configuration:"
echo "https://${AWS_REGION}.console.aws.amazon.com/ec2/autoscaling/home?region=${AWS_REGION}#LaunchConfigurations:"
echo ""
