#!/bin/bash

export LC_ALL=en_US.UTF-8

export USER=root

# Associate IP (data is pushed to this IP from Oracle etc)
ELASTIC_IP=52.17.86.89
INSTANCE_ID=`curl http://169.254.169.254/latest/meta-data/instance-id`
aws ec2 associate-address --instance-id $INSTANCE_ID --public-ip $ELASTIC_IP --allow-reassociation

# ----------------------------------------------------------------
# Update hostfile
cat >> /etc/hosts <<'EOF'
# MongoDB setup.
172.30.2.200        mongo10.flyfisheurope.com
172.30.0.201        mongo11.flyfisheurope.com
172.30.1.201        mongo12.flyfisheurope.com
EOF

mkdir /root/.node-gyp/

# ----------------------------------------------------------------
# Get the application you want to run on this server:
mkdir /srv/
cd /srv/
git clone $GIT_REPO_CONFIG
git clone https://github.com/5orenso/simple-blog.git

# Install all packages
cd /srv/simple-blog/
npm install --unsafe-perm

# Install the application:
chown ubuntu:ubuntu /srv/simple-blog/
chmod 755 /srv/simple-blog/

# Link the content folder
mkdir /srv/simple-blog/content/
chown ubuntu:ubuntu /srv/simple-blog/content/
ln -s /home/ubuntu/Dropbox/websites /srv/simple-blog/content

# Config file
mkdir /srv/config/

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


# Logs to AWS Cloudwatch
cat > /var/awslogs/etc/awslogs.conf <<EOF
[general]
state_file = /var/awslogs/state/agent-state

[/tmp/image-access.log]
datetime_format = %Y-%m-%d %H:%M:%S
file = /srv/simple-blog/logs/image-access.log
buffer_duration = 5000
log_stream_name = {instance_id}
initial_position = start_of_file
log_group_name = web/access

[/tmp/image-access.log]
datetime_format = %Y-%m-%d %H:%M:%S
file = /srv/simple-blog/logs/image-access.log
buffer_duration = 5000
log_stream_name = {instance_id}
initial_position = start_of_file
log_group_name = web/access

[/tmp/image-access.log]
datetime_format = %Y-%m-%d %H:%M:%S
file = /srv/simple-blog/logs/image-access.log
buffer_duration = 5000
log_stream_name = {instance_id}
initial_position = start_of_file
log_group_name = web/access

[/tmp/image-access.log]
datetime_format = %Y-%m-%d %H:%M:%S
file = /srv/simple-blog/logs/image-access.log
buffer_duration = 5000
log_stream_name = {instance_id}
initial_position = start_of_file
log_group_name = web/access

EOF

# ---[ ALL active domains ]--------------------------------------------------
while IFS= read -r domain; do
  echo "$domain"
# Startup script
cat > /etc/systemd/system/simple-blog-${domain}.service <<EOF
[Unit]
Description=simple-blog-${domain}

[Service]
Type=simple
ExecStart=/usr/local/bin/node /srv/simple-blog/app/server.js -c /srv/config/simple-blog/config-${domain}.js  >> /var/log/simple-blog/simple-blog-${domain}.log 2>&1
StandardOutput=null
Restart=on-failure

EOF

# Run the application:
service simple-blog-${domain} start

# Add crontab entries
cat >> /etc/cron.daily/simple-blog-sitemap.sh <<EOF
/usr/local/bin/node /srv/simple-blog/app/sitemap.js -c /srv/config/simple-blog/config-${domain}.js > /dev/null 2>&1
EOF

cat >> /var/awslogs/etc/awslogs.conf <<EOF
[/tmp/simple-blog-${domain}.log]
datetime_format = %Y-%m-%d %H:%M:%S
file = /var/log/simple-blog/simple-blog-${domain}.log
buffer_duration = 5000
log_stream_name = {instance_id}
initial_position = start_of_file
log_group_name = simple-blog
EOF

done < "/srv/config/simple-blog/active-domains.txt"
# ---[ /ALL active domains ]--------------------------------------------------

chmod 755 /etc/cron.hourly/simple-blog-sitemap.sh
service awslogs restart
