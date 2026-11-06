#!/usr/bin/env bash

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
        -c|--cloudwatch-monitoring)
            CLOUDWATCH_MONITORING="$2"
            shift # past argument
        ;;
        -e|--ebs-optimized)
            EBS_OPTIMIZED="$2"
            shift # past argument
        ;;
        -I|--ami-id)
            AMI_ID="$2"
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
        -n|--launch-template-name)
            LAUNCH_TEMPLATE_NAME="$2"
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
    echo "     -n|--launch-template-name <name of launch template>"
    echo "    [-t|--instance-type <instance type>]"
    echo "     -u|--user-data-file <server boot file>"
    echo "    [-s|--secret-user-data-file <secret user data file>]"
    echo "    [-r|--aws-region <awd region>]"
    echo "    [-p|--aws-profile <aws profile>]"
    echo ""
    echo "The server boot file is embedded into the launch template user data,"
    echo "so the servers no longer fetch anything from GitHub at boot."
    echo "If the launch template already exists a new version is created."
    echo ""
    echo "bash ${0}"
    echo "    -g <id of security group>"
    echo "    -I <ami id>"
    echo "    -i <iam role>"
    echo "    -k <name of key-pair>"
    echo "    -n <name of launch template>"
    echo "    -u <server boot file>"
    echo "    -s <secret user data file>"
    echo ""
    exit 1;
fi

# Optional value
if [ ! -z "$EBS_OPTIMIZED" ]; then
    EBS_OPTIMIZED='true'
fi
if [ ! -z "$CLOUDWATCH_MONITORING" ]; then
    CLOUDWATCH_MONITORING='true'
fi
if [ ! -z "$AWS_PROFILE" ]; then
    AWS_PROFILE="--profile ${AWS_PROFILE}"
fi

# Default values
AWS_REGION=${AWS_REGION:-'eu-west-1'}
EBS_OPTIMIZED=${EBS_OPTIMIZED:-false}
CLOUDWATCH_MONITORING=${CLOUDWATCH_MONITORING:-false}
INSTANCE_TYPE=${INSTANCE_TYPE:-'t3.small'}

# Required values
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
if [ -z "$AMI_ID" ]; then
    EXIT_MISSING=1
    echo ''
    echo '* Missing "ami id". Please set with:'
    echo '    -I|--ami-id <ami id>'
    echo '    Example usage:'
    echo '        -I ami-MyNodeAmi'
    echo '    Existing images:'
    aws ec2 describe-images --owners self $AWS_PROFILE | jq -c '.Images[] | { id: .ImageId, name: .Name }'
    echo ''
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
    echo '    -u|--user-data-file <server boot file>'
    echo '    Example usage:'
    echo '        -u server-boot/server-boot-node.sh'
    echo '    Existing server boot files:'
    ls server-boot/*.sh | cat
    echo ''
fi
if [ -z "$LAUNCH_TEMPLATE_NAME" ]; then
    EXIT_MISSING=1
    echo ''
    echo '* Missing "launch-template-name". Please set with:'
    echo '    -n|--launch-template-name <name of launch template>'
    echo '    Example usage:'
    echo '        -n lt-node'
    echo '    Existing launch templates:'
    aws ec2 describe-launch-templates $AWS_PROFILE --region $AWS_REGION | jq -c '.LaunchTemplates[] | { name: .LaunchTemplateName, latestVersion: .LatestVersionNumber }'
    echo ''
fi
if [ ! -z "$EXIT_MISSING" ]; then
    echo ""
    echo "bash ${0}"
    echo "    -g <id of security group>"
    echo "    -I <ami id>"
    echo "    -i <iam profile for the servers>"
    echo "    -k <name of key-pair>"
    echo "    -n <name of launch template>"
    echo "    -u <server boot file>"
    echo "    -s <secret user data file>"
    echo ""
    exit 1;
fi

# Embed the server boot file (with optional secrets prepended) as user data.
USER_DATA_TMP="/tmp/${LAUNCH_TEMPLATE_NAME}-user-data.sh"
if [ ! -z "$SECRET_USER_DATA_FILE" ]; then
    cat $SECRET_USER_DATA_FILE $USER_DATA_FILE > $USER_DATA_TMP
else
    cat $USER_DATA_FILE > $USER_DATA_TMP
fi
# Launch templates need the user data base64 encoded up front.
USER_DATA_B64=$(base64 < $USER_DATA_TMP | tr -d '\n')
rm $USER_DATA_TMP

LAUNCH_TEMPLATE_DATA=$(jq -n \
    --arg ami "$AMI_ID" \
    --arg instanceType "$INSTANCE_TYPE" \
    --arg keyPair "$KEY_PAIR" \
    --arg iamProfile "$IAM_PROFILE" \
    --arg securityGroup "$SECURITY_GROUP" \
    --arg userData "$USER_DATA_B64" \
    --argjson monitoring "$CLOUDWATCH_MONITORING" \
    --argjson ebsOptimized "$EBS_OPTIMIZED" \
    --slurpfile bdm block-device-mapping.json \
    '{
        ImageId: $ami,
        InstanceType: $instanceType,
        KeyName: $keyPair,
        IamInstanceProfile: { Name: $iamProfile },
        UserData: $userData,
        Monitoring: { Enabled: $monitoring },
        EbsOptimized: $ebsOptimized,
        BlockDeviceMappings: $bdm[0],
        NetworkInterfaces: [ { DeviceIndex: 0, AssociatePublicIpAddress: true, Groups: [ $securityGroup ] } ]
    }')

echo "CLOUDWATCH_MONITORING : ${CLOUDWATCH_MONITORING}"
echo "EBS_OPTIMIZED         : ${EBS_OPTIMIZED}"
echo "IAM_PROFILE           : ${IAM_PROFILE}"
echo "AMI_ID                : ${AMI_ID}"
echo "INSTANCE_TYPE         : ${INSTANCE_TYPE}"
echo "KEY_PAIR              : ${KEY_PAIR}"
echo "LAUNCH_TEMPLATE_NAME  : ${LAUNCH_TEMPLATE_NAME}"
echo "SECURITY_GROUP        : ${SECURITY_GROUP}"
echo ""

VERSION_DESCRIPTION="${AMI_ID} $(date +%Y-%m-%d)"

# Create the launch template, or a new version if it already exists.
EXISTING_TEMPLATE=$(aws ec2 describe-launch-templates $AWS_PROFILE --region $AWS_REGION \
    --launch-template-names $LAUNCH_TEMPLATE_NAME 2>/dev/null | jq -r '.LaunchTemplates[0].LaunchTemplateName')

if [ "$EXISTING_TEMPLATE" == "$LAUNCH_TEMPLATE_NAME" ]; then
    echo "Running aws ec2 create-launch-template-version:"
    echo "-----------------------------------------------"
    LT_RUN_OUTPUT=$(aws ec2 create-launch-template-version $AWS_PROFILE \
        --region $AWS_REGION \
        --launch-template-name $LAUNCH_TEMPLATE_NAME \
        --version-description "$VERSION_DESCRIPTION" \
        --launch-template-data "$LAUNCH_TEMPLATE_DATA")
    NEW_VERSION=$(echo $LT_RUN_OUTPUT | jq -r '.LaunchTemplateVersion.VersionNumber')
    echo "New version ${GREEN}${NEW_VERSION}${R} of launch template ${GREEN}${LAUNCH_TEMPLATE_NAME}${R} created."
    echo ""
    echo "Auto Scaling Groups using this template with version '\$Latest' will use it for all new servers."
    echo "To replace the running servers with new ones right away:"
    echo "    $ aws autoscaling start-instance-refresh ${AWS_PROFILE} --region ${AWS_REGION} --auto-scaling-group-name <your auto scaling group>"
else
    echo "Running aws ec2 create-launch-template:"
    echo "---------------------------------------"
    LT_RUN_OUTPUT=$(aws ec2 create-launch-template $AWS_PROFILE \
        --region $AWS_REGION \
        --launch-template-name $LAUNCH_TEMPLATE_NAME \
        --version-description "$VERSION_DESCRIPTION" \
        --launch-template-data "$LAUNCH_TEMPLATE_DATA")
    echo $LT_RUN_OUTPUT | jq -c '.LaunchTemplate'
fi
echo 'Done!'

echo ""
echo "Now jump to the EC2 console page to find your Launch Template:"
echo "https://${AWS_REGION}.console.aws.amazon.com/ec2/home?region=${AWS_REGION}#LaunchTemplates:"
echo ""

# Propose auto scaling group name:
AG_BASE_NAME=${LAUNCH_TEMPLATE_NAME//lt-/}
AG_NAME="ag-${AG_BASE_NAME}"
if [ ! -z "$AWS_PROFILE" ];then
    LT_PROFILE="-p ${AWS_PROFILE//--profile /} "
fi
echo ""
echo "--------------------------------------------------------------------"
echo "If you don't have an Auto Scaling Group yet, run create-auto-scaling-group.sh:"
echo "Usage:"
echo "    $ bash ./create-auto-scaling-group.sh ${LT_PROFILE}"
echo "        -s <comma separated list of subnets>"
echo "        -l ${LAUNCH_TEMPLATE_NAME}"
echo "        -n ${AG_NAME}"
echo ""
echo "You can just run this and it will guide you through the rest:"
echo "    $ bash ./create-auto-scaling-group.sh ${LT_PROFILE}-l ${LAUNCH_TEMPLATE_NAME} -n ${AG_NAME}"
echo ""
