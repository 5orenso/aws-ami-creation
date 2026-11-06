# AWS Launch Template creation

Make sure all [Prerequisite](#user-content-prerequisite) are fullfilled.

__Create a new server role:__
```bash
$ bash ./create-server-role.sh
```
_PS! You might need to add policies to this role depending on the AWS Services your application uses._

__To get started just type:__
```bash
$ bash ./create-launch-template.sh
```

__Example:__
```bash
$ bash ./create-launch-template.sh \
    -u server-boot/server-boot-node.sh \
    -n lt-node \
    -k my-key-pair \
    -i role-node-server \
    -I ami-MyNodeAmi \
    -g sg-12345678
```

The server boot file is embedded directly into the launch template user data,
so the servers no longer fetch anything from GitHub at boot. Secrets can be
prepended with `-s launch-configurations/secret-user-data-<name>.sh` (these
files are gitignored).

If the launch template already exists, a new version is created. An Auto
Scaling Group created with [create-auto-scaling-group.sh](auto-scaling-group.md)
uses the `$Latest` version, so new servers automatically pick up the new
version. To replace the running servers right away:

```bash
$ aws autoscaling start-instance-refresh --auto-scaling-group-name ag-node
```

* When you've created a Launch Template then you can fire up the number of servers you want with an [AWS Auto Scaling Group](auto-scaling-group.md).


## Prerequisite

* [An AMI for the server](../README.md)

### Create a new security group for the servers

1. Create new security group. `sg-node-server`
2. Add inbound rules to your new group.
3. Outbound rules can be as it is.
