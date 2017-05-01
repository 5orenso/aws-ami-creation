#!/bin/bash

export LC_ALL=en_US.UTF-8

# ----------------------------------------------------------------
# Update hostfile
cat >> /etc/hosts <<'EOF'
# MongoDB setup.
172.30.2.250        mongo0.flyfisheurope.com
172.30.1.250        mongo1.flyfisheurope.com
172.30.0.250        mongo2.flyfisheurope.com
EOF

# ----------------------------------------------------------------
# Get the application you want to run on this server:
mkdir /srv/
cd /srv/
git clone $GIT_REPO_CONFIG
git clone $GIT_REPO_ZU_CMS
git clone $GIT_REPO_NODE_FFE_CMS

# Install all packages
cd /srv/Zu-CMS/
npm install --production

cd /srv/node-ffe-web/
npm install --production

# Logging folders
mkdir /var/log/Zu-CMS/
chown -R ubuntu:ubuntu /var/log/Zu-CMS/
chmod u+w /var/log/Zu-CMS/

mkdir /var/log/node-ffe-web/
chown -R ubuntu:ubuntu /var/log/node-ffe-web/
chmod u+w /var/log/node-ffe-web/

# Pid file
mkdir /var/run/Zu-CMS/
chown -R ubuntu:ubuntu /var/run/Zu-CMS/
chmod u+w /var/run/Zu-CMS/

mkdir /var/run/node-ffe-web/
chown -R ubuntu:ubuntu /var/run/node-ffe-web/
chmod u+w /var/run/node-ffe-web/

# node app/server.js -c /srv/config/node-ffe-web/config.js

# Startup script
cat > /etc/init/Zu-CMS.conf <<'EOF'
# ----------------------------------------------------------------------
# Zu-CMS - instance
#
description     "Zu-CMS"

start on (virtual-filesystems and net-device-up IFACE=eth0)
stop on runlevel [06]

respawn
respawn limit 10 5    # Die if respawn more than 10 times in 5 sec.

chdir /srv/Zu-CMS
setuid ubuntu
setgid ubuntu
console log

script
    echo $$ > /var/run/Zu-CMS/Zu-CMS.pid
    exec /usr/local/bin/node /srv/Zu-CMS/app/server.js -c /srv/config/ffe/Zu-CMS/zu/config.js  >> /var/log/Zu-CMS/Zu-CMS.log 2>&1
end script

pre-start script
    # Date format same as (new Date()).toISOString() for consistency
    echo "[`date -u +%Y-%m-%dT%T.%3NZ`] (sys) Starting" >> /var/log/Zu-CMS/Zu-CMS.log
end script

pre-stop script
    rm /var/run/Zu-CMS/Zu-CMS.pid
    echo "[`date -u +%Y-%m-%dT%T.%3NZ`] (sys) Stopping" >> /var/log/Zu-CMS/Zu-CMS.log
end script

#-----[ HOWTO ]--------------------------------------------------
# sudo initctl start Zu-CMS
# sudo tail -f /var/log/Zu-CMS/Zu-CMS.log
EOF

# Startup script
cat > /etc/init/node-ffe-web.conf <<'EOF'
# ----------------------------------------------------------------------
# node-ffe-web - instance
#
description     "node-ffe-web"

start on (virtual-filesystems and net-device-up IFACE=eth0)
stop on runlevel [06]

respawn
respawn limit 10 5    # Die if respawn more than 10 times in 5 sec.

chdir /srv/node-ffe-web
setuid ubuntu
setgid ubuntu
console log

script
    echo $$ > /var/run/node-ffe-web/node-ffe-web.pid
    exec /usr/local/bin/node /srv/node-ffe-web/app/server.js -c /srv/config/node-ffe-web/config.js  >> /var/log/node-ffe-web/node-ffe-web.log 2>&1
end script

pre-start script
    # Date format same as (new Date()).toISOString() for consistency
    echo "[`date -u +%Y-%m-%dT%T.%3NZ`] (sys) Starting" >> /var/log/node-ffe-web/node-ffe-web.log
end script

pre-stop script
    rm /var/run/node-ffe-web/node-ffe-web.pid
    echo "[`date -u +%Y-%m-%dT%T.%3NZ`] (sys) Stopping" >> /var/log/node-ffe-web/node-ffe-web.log
end script

#-----[ HOWTO ]--------------------------------------------------
# sudo initctl start node-ffe-web
# sudo tail -f /var/log/node-ffe-web/node-ffe-web.log
EOF



# Logs to AWS Cloudwatch
cat > /var/awslogs/etc/awslogs.conf <<'EOF'
[general]
state_file = /var/awslogs/state/agent-state

[/var/log/Zu-CMS/Zu-CMS.log]
datetime_format = %Y-%m-%d %H:%M:%S
file = /var/log/Zu-CMS/Zu-CMS.log
buffer_duration = 5000
log_stream_name = {instance_id}
initial_position = start_of_file
log_group_name = api/apilog.log

[/var/log/node-ffe-web/node-ffe-web.log]
datetime_format = %Y-%m-%d %H:%M:%S
file = /var/log/node-ffe-web/node-ffe-web.log
buffer_duration = 5000
log_stream_name = {instance_id}
initial_position = start_of_file
log_group_name = api/apilog.log

EOF
service awslogs restart

# Run the application:
service Zu-CMS start
service node-ffe-web start
