#!/usr/bin/env bash

# Read command line input:
while [[ $# > 1 ]]; do
    key="$1"
    case $key in
        -h|--help)
            HELP="$2"
            shift # past argument
        ;;
        -n|--role-name)
            AWS_ROLE="$2"
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
    echo "     -n|--role-name <role name>"
    echo "    [-r|--aws-region <awd region>]"
    echo "    [-p|--aws-profile <aws profile>]"
    echo ""
    echo "bash ${0} -n <role name>"
    echo ""
    exit 1;
fi

# Default values
AWS_REGION=${AWS_REGION:-'eu-west-1'}
AWS_ROLE=${AWS_ROLE:-'role-ami-creator'}

# Optional value
if [ ! -z "$AWS_PROFILE" ]; then
    AWS_PROFILE="--profile ${AWS_PROFILE}"
fi

CREATE_ROLE_RESULT=$(aws iam create-role $AWS_PROFILE --region $AWS_REGION --role-name $AWS_ROLE --assume-role-policy-document file://policies/role-ami-creator.json | jq -rc '.Role.RoleName')
echo "Role created : ${CREATE_ROLE_RESULT}"

echo "Attaching Amazon policy AmazonS3ReadOnlyAccess."
aws iam attach-role-policy $AWS_PROFILE --region $AWS_REGION --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess --role-name $AWS_ROLE
echo "Attaching Amazon policy AmazonEC2ReadOnlyAccess."
aws iam attach-role-policy $AWS_PROFILE --region $AWS_REGION --policy-arn arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess --role-name $AWS_ROLE

echo "Attaching inline policy amiCreatorCreateImage."
aws iam put-role-policy $AWS_PROFILE --region $AWS_REGION --role-name $AWS_ROLE --policy-name amiCreatorCreateImage --policy-document file://policies/policy-ec2-create-image.json
echo "Attaching inline policy amiCreatorCreateTags."
aws iam put-role-policy $AWS_PROFILE --region $AWS_REGION --role-name $AWS_ROLE --policy-name amiCreatorCreateTags --policy-document file://policies/policy-ec2-create-tags.json
echo "Attaching inline policy amiCreatorIoT."
aws iam put-role-policy $AWS_PROFILE --region $AWS_REGION --role-name $AWS_ROLE --policy-name amiCreatorCreateIot --policy-document file://policies/policy-iot-all.json
echo "Attaching inline policy amiCreatorIam."
aws iam put-role-policy $AWS_PROFILE --region $AWS_REGION --role-name $AWS_ROLE --policy-name amiCreatorCreateIam --policy-document file://policies/policy-iam.json

CREATE_PROFILE_RESULT=$(aws iam create-instance-profile $AWS_PROFILE --region $AWS_REGION --instance-profile-name $AWS_ROLE)
echo "Profile created : ${CREATE_PROFILE_RESULT}"

echo "Attaching role to instance-profile."
aws iam add-role-to-instance-profile $AWS_PROFILE --region $AWS_REGION --role-name $AWS_ROLE --instance-profile-name $AWS_ROLE

echo "Done."
