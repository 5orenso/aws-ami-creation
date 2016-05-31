# AWS Auto Scaling Group creation

Make sure all [Prerequisite](#user-content-prerequisite) are fullfilled.

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

* When you've created an Auto Scaling Group you should check out the behavior of the servers requested.
* There should be nice and shiny new servers up and running. If you kill any of them a new one should 
startup after 60 seconds.

You'll find all details on your 
[Auto Scaling Console](https://eu-west-1.console.aws.amazon.com/ec2/autoscaling/home?region=eu-west-1#AutoScalingGroups:view=instances).

The servers are also visible in the [EC2 console](https://eu-west-1.console.aws.amazon.com/ec2/v2/home?region=eu-west-1#Instances:sort=desc:launchTime)


## Prerequisite

* [An AMI for the server](../README.md)
* [AWS Launch Configuration](launch-configuration.md).
