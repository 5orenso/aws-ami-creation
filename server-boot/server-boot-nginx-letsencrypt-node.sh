#!/bin/bash

export LC_ALL=en_US.UTF-8

# ----------------------------------------------------------------
# If you want to associate this with an elastic IP you need to
# provide a secret user data file with the option -s|--secret-user-data-file
#
#     $ create-launch-config.sh
#         -s <secret user data file>
#
# NB! Do not upload the secret file to any public repo!
#
if [ ! -z "$ELASTIC_IP_ALLOCATION_ID" ]; then
    # Associate Elastic IP with instance if not associated before.
    INSTANCE_ID=`curl http://169.254.169.254/latest/meta-data/instance-id`
    CURRENT_INSTANCE_ID=$(/usr/bin/aws ec2 describe-addresses --allocation-ids $ELASTIC_IP_ALLOCATION_ID --region eu-west-1 | jq -r '.Addresses[].InstanceId')
    if [[ $CURRENT_INSTANCE_ID == null ]] ; then
        /usr/bin/aws ec2 associate-address --instance-id $INSTANCE_ID --allocation-id $ELASTIC_IP_ALLOCATION_ID --allow-reassociation --region eu-west-1
    fi
fi

# ----------------------------------------------------------------
# Get the application you want to run on this server:
mkdir /srv/
cd /srv/
git clone https://github.com/5orenso/node-express-boilerplate.git

# Install all packages
cd /srv/node-express-boilerplate/
npm install --production

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
        logFile: '/tmp/access.log',
        domain: '${COOKIE_DOMAIN}'
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
# node-express-boilerplate - instance
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


# Nginx and letsencrypt setup
cat > /etc/nginx/sites-available/default <<'EOF'
server {
        listen 80 default_server;
        listen [::]:80 default_server ipv6only=on;

        root /usr/share/nginx/html;
        index index.html index.htm;

        # Make site accessible from http://localhost/
        server_name localhost;

        location / {
            # First attempt to serve request as file, then
            # as directory, then fall back to displaying a 404.
            try_files $uri $uri/ =404;
        }
        location ~ /.well-known {
            allow all;
        }
}
EOF
service nginx reload

cd /opt/certbot
./certbot-auto certonly --agree-tos --email ${CERT_EMAIL} -a webroot --webroot-path=/usr/share/nginx/html -d ${CERT_DOMAIN} ${CERT_ADDITIONAL_DOMAINS}
#ls -al /etc/letsencrypt/live/tools.flyfisheurope.com/fullchain.pem


cat > /etc/nginx/sites-available/default <<'EOF'
server {
    listen 443 ssl;
    server_name ${CERT_DOMAIN} ${CERT_ADDITIONAL_DOMAINS//-d/};

    root /usr/share/nginx/html;
    index index.html index.htm;

    ssl_certificate /etc/letsencrypt/live/${CERT_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${CERT_DOMAIN}/privkey.pem;

    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_dhparam /etc/ssl/certs/dhparam.pem;
    ssl_ciphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA';
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_stapling on;
    ssl_stapling_verify on;
    add_header Strict-Transport-Security max-age=15768000;

    location / {
        # First attempt to serve request as file, then
        # as directory, then fall back to displaying a 404.
        # try_files $uri $uri/ =404;
        proxy_pass http://localhost:8080;
        proxy_pass_header Server;
        proxy_redirect off;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Scheme $scheme;
        proxy_set_header REMOTE_ADDR $remote_addr;
    }
    location ~ /.well-known {
        allow all;
    }
}

server {
    listen 80;
    server_name ${CERT_DOMAIN} ${CERT_ADDITIONAL_DOMAINS//-d/};
    return 301 https://$host$request_uri;
}

EOF
service nginx reload

# Test SSL
# https://www.ssllabs.com/ssltest/analyze.html?d=${CERT_DOMAIN}

# Schedule regular update of letsencrypt certs.
read -r -d '' ROOT_CRONTAB_LINES <<- EOM
MAILTO=${CERT_EMAIL}

30 2 * * 1 /opt/certbot/certbot-auto --non-interactive renew >> /var/log/le-renew.log
35 2 * * 1 /etc/init.d/nginx reload
EOM

(crontab -l; echo "$ROOT_CRONTAB_LINES" ) | crontab -u root -

