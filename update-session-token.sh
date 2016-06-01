#!/usr/bin/env bash

TOKEN_FILE="$HOME/.aws/update_session_token.conf"

# Read the last used variables from file.
# Only load if the file exists.
if [ -r $TOKEN_FILE ]; then
  source $TOKEN_FILE
fi

read -p "Profile [$AWS_PROFILE_DEFAULT]: " AWS_PROFILE
AWS_PROFILE=${AWS_PROFILE:-$AWS_PROFILE_DEFAULT}

read -p "MFA Serial-Number [$SERIAL_NUMBER_DEFAULT]: " SERIAL_NUMBER
SERIAL_NUMBER=${SERIAL_NUMBER:-$SERIAL_NUMBER_DEFAULT}

read -p "MFA Token: " TOKEN

AWS_REGION_DEFAULT="eu-west-1"
read -p "Region [$AWS_REGION_DEFAULT]: " AWS_REGION
AWS_REGION=${AWS_REGION:-$AWS_REGION_DEFAULT}

CREATE_SESSION_RESULT=$(aws sts get-session-token --region $AWS_REGION --profile $AWS_PROFILE --serial-number $SERIAL_NUMBER --token-code $TOKEN)

if [ -z "$CREATE_SESSION_RESULT" ]
then
  exit 1;
fi

# Get variables from the AWS json and add it to aws configure command
SecretAccessKey=$(echo $CREATE_SESSION_RESULT | jq -rc '.Credentials.SecretAccessKey')
SessionToken=$(echo $CREATE_SESSION_RESULT | jq -rc '.Credentials.SessionToken')
AccessKeyId=$(echo $CREATE_SESSION_RESULT | jq -rc '.Credentials.AccessKeyId')

aws configure --profile "${AWS_PROFILE}_session" set aws_access_key_id $AccessKeyId
aws configure --profile "${AWS_PROFILE}_session" set aws_secret_access_key $SecretAccessKey
aws configure --profile "${AWS_PROFILE}_session" set aws_session_token $SessionToken

# Write last used values to file to speed up next time we get a session token
cat > $TOKEN_FILE <<EOF
AWS_PROFILE_DEFAULT="$AWS_PROFILE"
SERIAL_NUMBER_DEFAULT="$SERIAL_NUMBER"
EOF

echo
echo "Use aws --profile ${AWS_PROFILE}_session <COMMAND> for using the temporary session token."
