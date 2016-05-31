#!/usr/bin/env bash

# Read command line input:
while [[ $# > 1 ]]
do
key="$1"

case $key in
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

# Default values
AWS_REGION=${AWS_REGION:-'eu-west-1'}
AWS_ROLE=${AWS_ROLE:-'role-ami-creator'}

# Optional value
if [ ! -z "$AWS_PROFILE" ]; then
    AWS_PROFILE="--profile ${AWS_PROFILE}"
fi

CREATE_ROLE_RESULT=$(aws iam create-role $AWS_PROFILE --role-name $AWS_ROLE --assume-role-policy-document file://role-ami-creator.json | jq -rc '.Role.RoleName')
echo "Role created : ${CREATE_ROLE_RESULT}"

echo "Attaching Amazon policy AmazonS3ReadOnlyAccess."
aws iam attach-role-policy $AWS_PROFILE --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess --role-name $AWS_ROLE
echo "Attaching Amazon policy AmazonEC2ReadOnlyAccess."
aws iam attach-role-policy $AWS_PROFILE --policy-arn arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess --role-name $AWS_ROLE

echo "Attaching inline policy amiCreatorCreateImage."
aws iam put-role-policy $AWS_PROFILE --role-name $AWS_ROLE --policy-name amiCreatorCreateImage --policy-document file://policy-ec2-create-image.json
echo "Attaching inline policy amiCreatorCreateTags."
aws iam put-role-policy $AWS_PROFILE --role-name $AWS_ROLE --policy-name amiCreatorCreateTags --policy-document file://policy-ec2-create-tags.json
echo "Done."
