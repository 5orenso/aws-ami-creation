#!/bin/bash
# Your boot template
BOOT_FILE='server-boot-mqtt-broker.sh'

# Fetch the file, make it runnable, run it and remove it.
curl -o ./${BOOT_FILE} https://raw.githubusercontent.com/5orenso/aws-ami-creation/master/server-boot/${BOOT_FILE}
chmod u+x ./${BOOT_FILE}
bash ./${BOOT_FILE}
rm ./${BOOT_FILE}
