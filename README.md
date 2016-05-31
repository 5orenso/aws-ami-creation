# AWS AMI Creation

A simple approach to create Amazon Machine Images (AMI) you need for your AWS servers.

I know there is Puppet, Chef and other tools out there to help you build images. 
But if you just want a nice, fast and simple way to create images with a minimum of effort,
this is the way.

__An auto scaled server setup in 3 steps:__

1. [create-role.sh](#user-content-get-started) : Create a role with access to create AMIs.
2. [create-ami.sh](#user-content-get-started) : Create an AMI for your server.
3. [create-launch-config.sh](launch-configuration.md) : Create a Launch Configuration for your Auto Scaling Group.
4. [create-auto-scaling-group.sh](auto-scaling-group.md) : Create an Auto Scaling Group.


## Get started

Make sure all [Prerequisite](#user-content-prerequisite) are fullfilled.

__Create a new Role:__
```bash
$ bash ./create-role.sh
```

__To get started creating a basic Ubuntu Node.js AMI, simply type:__
```bash
$ bash ./create-ami.sh -u template-node-ami.sh
```

__Example:__
```bash
$ bash ./create-ami.sh \
    -u template-node-ami.sh \
    -k my-key-pair \
    -i role-ami-creator
```


* Follow the instructions on the screen.
* After 10-15 minutes your image should be ready to be used with an [AWS Launch Configuration](launch-configuration.md).
* When you've created a Launch Configuration then you can fire up the number of server you want with an [AWS Auto Scaling Groups](auto-scaling-group.md).


## Prerequisite

Before you can run the command to create a new AMI you need to register an AWS account, 
install the AWS CLI, create a new role for the creator and install [jq](https://stedolan.github.io/jq/download/).
 
__This is how you do it:__
* [Setup an Amazon Web Services account](https://aws.amazon.com/)
* [Install the AWS Command Line Interface](http://docs.aws.amazon.com/cli/latest/userguide/installing.html)
* [Configure the AWS Command Line Interface](http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html)


That's all!

If you create any useful server AMIs please [make a pull request](https://help.github.com/articles/creating-a-pull-request/).

