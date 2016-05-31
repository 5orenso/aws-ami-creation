#!/bin/bash
# Fetch the file, make it runnable, run it and remove it.
curl -o ./server-boot-node.sh https://raw.githubusercontent.com/5orenso/aws-ami-creation/master/server-boot-node.sh
chmod u+x ./server-boot-node.sh
bash ./server-boot-node.sh
rm ./server-boot-node.sh
