#!/bin/bash

export LC_ALL=en_US.UTF-8

# ----------------------------------------------------------------
# Get the application you want to run on this server:
mkdir /srv/
cd /srv/
git clone https://github.com/5orenso/node-express-boilerplate.git

# Install all packages
cd /srv/node-express-boilerplate/
npm install

# Install the application:
chown ubuntu:ubuntu /srv/node-express-boilerplate/

# Config file
mkdir /srv/config/

cat > /srv/config/node-express-boilerplate.js <<'EOF'
module.exports = {
    version: '1.0.0',
    debug: true,
    logLevel: 'debug', // debug, verbose, info
    app: {
        port: 8080,
        logFile: '/tmp/access.log'
    },
    useDataDog: true
};
EOF

# Logging folders
mkdir /var/log/node-express-boilerplate/
chown ubuntu:ubuntu /var/log/node-express-boilerplate/
chmod u+w /var/log/node-express-boilerplate/

# Pid file
mkdir /var/run/node-express-boilerplate/
chown ubuntu:ubuntu /var/run/node-express-boilerplate
chmod u+w /var/run/node-express-boilerplate

# Startup script
cat > /etc/init/node-express-boilerplate.conf <<'EOF'
# ----------------------------------------------------------------------
# datapiper - instance
#
description     "node-express-boilerplate"

start on (virtual-filesystems and net-device-up IFACE=eth0)
stop on runlevel [06]

respawn
respawn limit 10 5    # Die if respawn more than 10 times in 5 sec.

chdir /srv/node-express-boilerplate
setuid ubuntu
setgid ubuntu
console log

script
    echo $$ > /var/run/node-express-boilerplate/node-express-boilerplate.pid
    exec /usr/local/bin/node /srv/node-express-boilerplate/app/server.js -c /srv/config/node-express-boilerplate.js  >> /var/log/node-express-boilerplate/node-express-boilerplate.log 2>&1
end script

pre-start script
    # Date format same as (new Date()).toISOString() for consistency
    echo "[`date -u +%Y-%m-%dT%T.%3NZ`] (sys) Starting" >> /var/log/node-express-boilerplate/node-express-boilerplate.log
end script

pre-stop script
    rm /var/run/node-express-boilerplate/node-express-boilerplate.pid
    echo "[`date -u +%Y-%m-%dT%T.%3NZ`] (sys) Stopping" >> /var/log/node-express-boilerplate/node-express-boilerplate.log
end script

#-----[ HOWTO ]--------------------------------------------------
# sudo initctl start node-express-boilerplate
# sudo tail -f /var/log/node-express-boilerplate/node-express-boilerplate.log
EOF

# Logs to AWS Cloudwatch
cat > /var/awslogs/etc/awslogs.conf <<'EOF'
[general]
state_file = /var/awslogs/state/agent-state

[/var/log/node-express-boilerplate/node-express-boilerplate.log]
datetime_format = %Y-%m-%d %H:%M:%S
file = /var/log/node-express-boilerplate/node-express-boilerplate.log
buffer_duration = 5000
log_stream_name = {instance_id}
initial_position = start_of_file
log_group_name = api/apilog.log
EOF
service awslogs restart

# Run the application:
service node-express-boilerplate start
