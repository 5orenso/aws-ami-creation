#!/bin/bash
# Fetch the file, make it runnable, run it and remove it.
curl -o ./server-boot.sh https://raw.githubusercontent.com/5orenso/aws-ami-creation/master/server-boot/server-boot-mongodb.sh
chmod u+x ./server-boot.sh
bash ./server-boot.sh
rm ./server-boot.sh
