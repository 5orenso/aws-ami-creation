# AWS Session Token handling

Returns a set of temporary credentials for an AWS account or IAM user. The credentials consist of an access key ID, a secret access key, and a security token.

__To get started just type:__
```bash
$ bash ./update-session-token.sh
```

__Example:__
```bash
$ bash ./update-session-token.sh
Profile []: my_aws_profile
MFA Serial-Number []: arn:aws:iam::1337:mfa/MyPrivateMFA
MFA Token: 893388
Region [eu-west-1]:

Use aws --profile TeliaIoT_session <COMMAND> for using the temporary session token.
```

__Remember last used config:__
Using ```$HOME/.aws/update_session_token.conf``` to store last used config. This way we can just skip providing the data we already have. 

```bash
$ bash ./update-session-token.sh
Profile [my_aws_profile]:
MFA Serial-Number [arn:aws:iam::1337:mfa/MyPrivateMFA]:
MFA Token: 123456
Region [eu-west-1]:

Use aws --profile TeliaIoT_session <COMMAND> for using the temporary session token.
```
