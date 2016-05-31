# AWS Launch Configuration creation

Make sure all [Prerequisite](#user-content-prerequisite) are fullfilled.

__Create a new server role:__
```bash
$ bash ./create-server-role.sh
```
_PS! You might need to add policies to this role depending on the AWS Services your application uses._

__To get started just type:__
```bash
$ bash ./create-launch-config.sh
```

__Example:__
```bash
$ bash ./create-launch-config.sh \
    -u launch-config-node.sh \
    -n lc-node-2016-06-01 \
    -k my-key-pair \
    -i role-node-server \
    -I ami-MyNodeAmi \
    -g sg-12345678
```

* When you've created a Launch Configuration then you can fire up the number of server you want with an [AWS Auto Scaling Groups](auto-scaling-group.md).


## Prerequisite

* [An AMI for the server](README.md)

### Create a new security group for the servers

1. Create new security group. `sg-node-server`
2. Add inbound rules to your new group.
3. Outbound rules can be as it is. 

