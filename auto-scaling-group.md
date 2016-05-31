# AWS Auto Scaling Group creation

Make sure all [Prerequisite](#Prerequisite) are fullfilled.

__To get started just type:__
```bash
$ bash ./create-auto-scaling-group.sh
```

__Example:__
```bash
$ bash ./create-auto-scaling-group.sh \
    -n ag-node-servers \
    -l lc-node-2016-06-01 \
    -s subnet-xxxx1a,subnet-xxx1b,subnet-xxxx1c
```

## Prerequisite

* [An AMI for the server](README.md)
* [AWS Launch Configuration](launch-configuration.md).
