#!/bin/bash

export LC_ALL=en_US.UTF-8

export USER=ubuntu

# Associate IP (data is pushed to this IP from Oracle etc)
ELASTIC_IP=52.17.86.89
INSTANCE_ID=`curl http://169.254.169.254/latest/meta-data/instance-id`
aws ec2 associate-address --instance-id $INSTANCE_ID --public-ip $ELASTIC_IP --allow-reassociation

# ----------------------------------------------------------------
# Get the application you want to run on this server:
mkdir /srv/
cd /srv/
git clone $GIT_REPO_CONFIG
git clone https://github.com/5orenso/simple-blog.git

# Install all packages
cd /srv/simple-blog/
npm install

# Install the application:
chown ubuntu:ubuntu /srv/simple-blog/
chmod 755 /srv/simple-blog/

# Link the content folder
mkdir /srv/simple-blog/content/
chown ubuntu:ubuntu /srv/simple-blog/content/
ln -s /home/ubuntu/Dropbox/websites /srv/simple-blog/content

# Config file
mkdir /srv/config/

# Add crontab entries
read -r -d '' CRONTAB_LINES <<- EOM
1,31 * * * *  /usr/local/bin/node /srv/simple-blog/app/sitemap.js -c /srv/config/simple-blog-sitemap-next-telia-no.js > /dev/null 2>&1
EOM
(crontab -l; echo "$CRONTAB_LINES" ) | crontab -u ubuntu -

# Logging folders
mkdir /srv/simple-blog/logs/
chown ubuntu:ubuntu /srv/simple-blog/logs/
chmod u+w /srv/simple-blog/logs/

mkdir /var/log/simple-blog/
chown ubuntu:ubuntu /var/log/simple-blog/
chmod u+w /var/log/simple-blog/

# Pid file
mkdir /var/run/simple-blog/
chown ubuntu:ubuntu /var/run/simple-blog
chmod u+w /var/run/simple-blog

# Startup script
cat > /etc/init/simple-blog-next-telia-no.conf <<'EOF'
# ----------------------------------------------------------------------
# datapiper - instance
#
description     "simple-blog"

start on (virtual-filesystems and net-device-up IFACE=eth0)
stop on runlevel [06]

respawn
respawn limit 10 5    # Die if respawn more than 10 times in 5 sec.

chdir /srv/simple-blog
setuid ubuntu
setgid ubuntu
console log

script
    echo $$ > /var/run/simple-blog/simple-blog-next.telia.no.pid
    exec /usr/local/bin/node /srv/simple-blog/app/server.js -c /srv/config/simple-blog-next.telia.no.js  >> /var/log/simple-blog/simple-blog-next.telia.no.log 2>&1
end script

pre-start script
    # Date format same as (new Date()).toISOString() for consistency
    echo "[`date -u +%Y-%m-%dT%T.%3NZ`] (sys) Starting" >> /var/log/simple-blog/simple-blog-next.telia.no.log
end script

pre-stop script
    rm /var/run/simple-blog/simple-blog-next.telia.no.pid
    echo "[`date -u +%Y-%m-%dT%T.%3NZ`] (sys) Stopping" >> /var/log/simple-blog/simple-blog-next.telia.no.log
end script

#-----[ HOWTO ]--------------------------------------------------
# sudo cp upstart.conf /etc/init/simple-blog.conf
# sudo initctl start simple-blog
# sudo tail -f /var/log/simple-blog/simple-blog-next.telia.no.log
EOF

# Logs to AWS Cloudwatch
cat > /var/awslogs/etc/awslogs.conf <<'EOF'
[general]
state_file = /var/awslogs/state/agent-state

[/tmp/apilog.log]
datetime_format = %Y-%m-%d %H:%M:%S
file = /var/log/simple-blog/simple-blog-next.telia.no.log
buffer_duration = 5000
log_stream_name = {instance_id}
initial_position = start_of_file
log_group_name = api/apilog.log

[/tmp/request.log]
datetime_format = %Y-%m-%d %H:%M:%S
file = /srv/simple-blog/logs/web-access.log
buffer_duration = 5000
log_stream_name = {instance_id}
initial_position = start_of_file
log_group_name = api/request.log
EOF
service awslogs restart

# Run the application:
service simple-blog-next-telia-no start


# Cleanup as the ubuntu user
# service simple-blog-next-telia-no stop
# rm -rf /srv/simple-blog/
# rm /srv/config/simple-blog-next.telia.no.js
# rm -rf /var/log/simple-blog/
# rm -rf /var/run/simple-blog/
# rm /etc/init/simple-blog-next-telia-no.conf
