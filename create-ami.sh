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
    -b|--base-image)
    BASE_IMAGE="$2"
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
    -s|--subnet)
    SUBNET="$2"
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
    echo "    [-b|--base-image <ami id>]"
    echo "    [-g|--security-group <id of security group>]"
    echo "     -i|--iam-profile <iam profile for image creation>"
    echo "     -k|--key-pair <name of key-pair>"
    echo "    [-s|--subnet <subnet id>]"
    echo "    [-t|--instance-type <instance type>]"
    echo "     -u|--user-data-file <ami template file>"
    echo "    [-r|--aws-region <awd region>]"
    echo "    [-p|--aws-profile <aws profile>]"
    echo ""
    echo "bash ${0} -i <iam profile> -k <name of key-pair> -u <user data file>"
    echo ""
    exit 1;
fi

# Default values
AWS_REGION=${AWS_REGION:-'eu-west-1'}
# This is the Ubuntu base image provided by AWS. No changes needed unless you want another version.
BASE_IMAGE=${BASE_IMAGE:-'ami-47a23a30'}
# Instance type. Default is fine.
INSTANCE_TYPE=${INSTANCE_TYPE:-'m3.medium'}

# Optional value
if [ ! -z "$SUBNET" ]; then
    SUBNET="--subnet-id ${SUBNET}"
fi
if [ ! -z "$SECURITY_GROUP" ]; then
    SECURITY_GROUP="--security-group-ids ${SECURITY_GROUP}"
fi
if [ ! -z "$AWS_PROFILE" ]; then
    AWS_PROFILE="--profile ${AWS_PROFILE}"
fi

# Required values
if [ -z "$IAM_PROFILE" ]; then
    EXIT_MISSING=1
    echo '* Missing "iam profile". Please set with:'
    echo '    -i|--iam-profile <iam profile>'
    echo '    Example usage:'
    echo '        -i role-ami-creator'
    echo '    Existing roles:'
    aws iam list-roles $AWS_PROFILE | jq -c '.Roles[] | {name: .RoleName}'
    echo ''
fi
if [ -z "$USER_DATA_FILE" ]; then
    EXIT_MISSING=1
    echo '* Missing "user data file". Please set with:'
    echo '    -u|--user-data-file <ami template file>'
    echo '    Example usage:'
    echo '        -u ami-templates/ami-template-node-ami.sh'
    echo '    Existing user data files:'
    ls ami-templates/*.sh | cat
    echo ''
fi
if [ -z "$KEY_PAIR" ]; then
    EXIT_MISSING=1
    echo '* Missing "key-pair". Please set with:'
    echo '    -k|--key-pair <name of key-pair>'
    echo '    Example usage:'
    echo '        -k my-key-pair'
    echo '    Existing key-pairs:'
    aws ec2 describe-key-pairs $AWS_PROFILE | jq -c '.KeyPairs[] | { name: .KeyName }'
    echo ''
fi
if [ ! -z "$EXIT_MISSING" ]; then
    echo ""
    echo "bash ${0} -i <iam profile> -k <name of key-pair> -u <user data file>"
    exit 1;
fi

echo "BASE_IMAGE      : ${BASE_IMAGE}"
echo "IAM_PROFILE     : ${IAM_PROFILE}"
echo "INSTANCE_TYPE   : ${INSTANCE_TYPE}"
echo "KEY_PAIR        : ${KEY_PAIR}"
echo "SUBNET          : ${SUBNET}"
echo "SECURITY_GROUP  : ${SECURITY_GROUP}"
echo ""
echo "Running aws ec2 run-instances:"
echo "------------------------------"

# Ubuntu Server 14.04 LTS (HVM), SSD Volume Type - ami-47a23a30
EC2_RUN_OUTPUT=$(aws ec2 run-instances $AWS_PROFILE \
    --region $AWS_REGION \
    --image-id ami-47a23a30 \
    --count 1 \
    --key-name $KEY_PAIR \
    --user-data file://$USER_DATA_FILE \
    $SUBNET \
    --iam-instance-profile Name=$IAM_PROFILE \
    $SECURITY_GROUP \
    --instance-type $INSTANCE_TYPE \
    --instance-initiated-shutdown-behavior terminate \
    --block-device-mappings file://block-device-mapping.json)

INSTANCE_ID=$(echo $EC2_RUN_OUTPUT | jq -r '.Instances[0].InstanceId')
INSTANCE_IP=$(echo $EC2_RUN_OUTPUT | jq -r '.Instances[0].PrivateIpAddress')

echo "INSTANCE_ID       : ${INSTANCE_ID}"
echo "INSTANCE_IP       : ${INSTANCE_IP}"
echo ""
echo "Now jump to the EC2 console page to find your instance:"
echo "https://${AWS_REGION}.console.aws.amazon.com/ec2/v2/home?region=${AWS_REGION}#Instances:search=${INSTANCE_ID};sort=desc:launchTime"
echo ""
echo "Your image should appear in at the top of this list after about 10-15 minutes:"
echo "https://${AWS_REGION}.console.aws.amazon.com/ec2/v2/home?region=${AWS_REGION}#Images:visibility=owned-by-me;sort=desc:creationDate"
echo ""
echo "Log into server:"
echo "$ ssh ubuntu@${INSTANCE_IP}"
echo ""
echo "View the cloud-init logfile:"
echo "$ tail -f /var/log/cloud-init-output.log"
echo ""
echo "REMEBER TO SHUTDOWN THE IMAGE AFTER AMI IS CREATED! (about 10-15 min)"
echo ""
