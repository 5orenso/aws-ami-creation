#!/usr/bin/env bash

# On your Mac: brew install coreutils
function gnudate() {
    if hash gdate 2>/dev/null; then
        gdate "$@"
    else
        date "$@"
    fi
}

# -- Color
BLACK=$(tput setaf 0)
RED=$(tput setaf 124)
GREEN=$(tput setaf 40)
YELLOW=$(tput setaf 136)
BLUE=$(tput setaf 69)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 37)
ORANGE=$(tput setaf 208)
PURPLE=$(tput setaf 92)
WHITE=$(tput setaf 15)
DARK_GRAY=$(tput setaf 240)

# -- Text mode
BOLD=$(tput bold)
ITALIC=$(tput sitm)
DIM=$(tput dim)
SMUL=$(tput smul)
RMUL=$(tput rmul)
REV=$(tput rev)
SMSO=$(tput smso)
RMSO=$(tput rmso)
# -- Reset
R=$(tput sgr0)

# -- Styling
ERROR_BULLET="${RED}>>${R}"
MISSING_KEYWORD="${ORANGE}${ITALIC}"
OPT="${BOLD}"
PH="${DARK_GRAY}"
BASH="${DARK_GRAY}"
SCRIPT="${BLUE}"

function printOutput() {
    if hash msee 2>/dev/null; then
        echo "$1" | msee
    else
        echo "$1"
    fi
}

# Read command line input:
while [[ $# > 1 ]]; do
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
    output=$(cat <<EOM
# Help!
This script will generate an AMI based on your input.
This AMI can be found on your __AMI page__ inside your AWS account when it is done.
Just follow the instructions inside this file to get started.

# tl;dr

    bash ${0}

# Usage

    bash ${0}
        [-h|--help 1]
        [-b|--base-image <ami id>]
        [-g|--security-group <id of security group>]
         -i|--iam-profile <iam profile for image creation>
         -k|--key-pair <name of key-pair>
        [-s|--subnet <subnet id>]
        [-t|--instance-type <instance type>]
         -u|--user-data-file <ami template file>
        [-r|--aws-region <awd region>]
        [-p|--aws-profile <aws profile>]

    bash ${0} -i <iam profile> -k <name of key-pair> -u <user data file>
EOM
)
    printOutput "$output"
    exit 1;
fi

# Default values
AWS_REGION=${AWS_REGION:-'eu-west-1'}

# This is the Ubuntu base image provided by AWS. No changes needed unless you want another version.
# Locate your base ami here: https://cloud-images.ubuntu.com/locator/ec2/
BASE_IMAGE=${BASE_IMAGE:-'ami-0905a3c97561e0b69'} # Ubuntu Server 22.04 LTS hvm:ebs-ssd
# Instance type. Default is fine.
INSTANCE_TYPE=${INSTANCE_TYPE:-'m4.large'}

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
if [ -z "$KEY_PAIR" ]; then
    EXIT_MISSING=1
    cat <<EOM
${ERROR_BULLET} Missing "${MISSING_KEYWORD}key-pair${R}". Please set with:
        ${OPT}-k${R}|${OPT}--key-pair${R} <${PH}name of key-pair${R}>
    Example usage:
        -k my-key-pair
    Existing key-pairs:
EOM
    aws ec2 describe-key-pairs $AWS_PROFILE | jq -c '.KeyPairs[] | { name: .KeyName }'
    echo ""
fi
if [ -z "$IAM_PROFILE" ]; then
    EXIT_MISSING=1
    cat <<EOM
${ERROR_BULLET} Missing "${MISSING_KEYWORD}iam profile${R}". Please set with:
      ${OPT}-i${R}|${OPT}--iam-profile${R} <${PH}iam profile${R}>
  Example usage:
      -i role-ami-creator
  Existing roles:
EOM
    aws iam list-roles $AWS_PROFILE | jq -c '.Roles[] | {name: .RoleName}'
    echo ""
fi
if [ -z "$USER_DATA_FILE" ]; then
    EXIT_MISSING=1
    cat <<EOM
${ERROR_BULLET} Missing "${MISSING_KEYWORD}user data file${R}". Please set with:
        ${OPT}-u${R}|${OPT}--user-data-file${R} <${PH}ami template file${R}>
    Example usage:
        -u ami-templates/ami-template-node.sh
    Existing user data files:
EOM
    ls ami-templates/*.sh | cat
    echo ""
fi
if [ -z "$SUBNET" ]; then
    EXIT_MISSING=1
    echo '* Missing "subnet-list". Please set with:'
    echo '        -s|--subnet <subnet id>'
    echo '    Example usage:'
    echo '        -s subnet-xxxxxx1a'
    echo '    Existing subnets:'
    aws ec2 describe-subnets $AWS_PROFILE | jq -c '.Subnets[] | { id: .SubnetId, zone: .AvailabilityZone, vpc: .VpcId, ip: .CidrBlock, publicIP: .MapPublicIpOnLaunch, default: .DefaultForAz }'
    echo ''
fi
if [ ! -z "$EXIT_MISSING" ]; then
    echo ""
    echo "${BASH}bash${R} ${SCRIPT}${0}${R} -i ${IAM_PROFILE:-"<${PH}iam profile${R}>"} -k ${KEY_PAIR:-"<${PH}name of key-pair${R}>"} -u ${USER_DATA_FILE:-"<${PH}user data file${R}>"}"
    exit 1;
fi

echo "AWS_PROFILE     : ${AWS_PROFILE:-'default'}"
echo "BASE_IMAGE      : ${BASE_IMAGE}"
echo "IAM_PROFILE     : ${IAM_PROFILE}"
echo "INSTANCE_TYPE   : ${INSTANCE_TYPE}"
echo "KEY_PAIR        : ${KEY_PAIR}"
echo "SUBNET          : ${SUBNET}"
echo "SECURITY_GROUP  : ${SECURITY_GROUP}"
echo ""
echo "Running aws ec2 run-instances:"
echo "------------------------------"

# Ubuntu Server 22.04 LTS (HVM), SSD Volume Type - ami-47a23a30
EC2_RUN_OUTPUT=$(aws ec2 run-instances $AWS_PROFILE \
    --region $AWS_REGION \
    --image-id $BASE_IMAGE \
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

echo "INSTANCE_ID       : ${BLUE}${INSTANCE_ID}${R}"
echo "INSTANCE_IP       : ${BLUE}${INSTANCE_IP}${R}"
echo ""
echo "Now jump to the EC2 console page to find your instance:"
echo "${GREEN}https://${AWS_REGION}.console.aws.amazon.com/ec2/v2/home?region=${AWS_REGION}#Instances:search=${INSTANCE_ID};sort=desc:launchTime${R}"
echo ""
echo "Your image should appear in at the top of this list after about 10-15 minutes:"
echo "${GREEN}https://${AWS_REGION}.console.aws.amazon.com/ec2/v2/home?region=${AWS_REGION}#Images:visibility=owned-by-me;sort=desc:creationDate${R}"
echo ""
echo "Log into server:"
echo "$ ssh ubuntu@${INSTANCE_IP}"
echo ""
echo "View the cloud-init logfile:"
echo "$ tail -f /var/log/cloud-init-output.log"
echo ""
echo "REMEBER TO SHUTDOWN THE AMI CREATOR SERVER (${INSTANCE_ID}) AFTER AMI IS CREATED! (about 10-15 min)"
echo ""

# Propose launch config name:
TODAY=$(gdate -d "today 13:00 " "+%Y-%m-%d")
LC_NAME=${USER_DATA_FILE//ami-templates\/ami-template-/}
LC_BASE_NAME=${LC_NAME//.sh}
LC_NAME="lc-${LC_BASE_NAME}-${TODAY}"
if [ ! -z "$AWS_PROFILE" ];then
    LC_PROFILE="-p ${AWS_PROFILE//--profile /} "
fi
if [ ! -z "$KEY_PAIR" ];then
    LC_KEY_PAIR="-k ${KEY_PAIR} "
fi
echo ""
echo "--------------------------------------------------------------------"
echo "Next you should run create-launch-config.sh:"
echo "Usage:"
echo "    $ bash ./create-launch-config.sh ${LC_PROFILE}${LC_KEY_PAIR}"
echo "        -I <your new AMI>"
echo "        -i <server role>"
echo "        -g <security group>"
echo "        -t <instance type>"
echo "        -u launch-configurations/launch-config-${LC_BASE_NAME}.sh"
echo "        -s launch-configurations/secret-user-data-${LC_BASE_NAME}.sh"
echo "        -n ${LC_NAME}"
echo ""
echo "You can just run this and it will guide you through the rest:"
echo "    $ bash ./create-launch-config.sh ${LC_PROFILE}${LC_KEY_PAIR}-t t2.micro -u launch-configurations/launch-config-${LC_BASE_NAME}.sh -s launch-configurations/secret-user-data-${LC_BASE_NAME}.sh -n ${LC_NAME}"
echo ""
