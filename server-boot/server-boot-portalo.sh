#!/bin/bash

export LC_ALL=en_US.UTF-8

# ----------------------------------------------------------------
# Update hostfile
cat >> /etc/hosts <<'EOF'
# MongoDB setup.
10.1.16.220          mongo20.raskepoter.no
10.1.16.221         mongo21.raskepoter.no
10.1.32.222        mongo22.raskepoter.no
10.1.0.223        mongo23.raskepoter.no

EOF

# ----------------------------------------------------------------
# Install missing packet
sudo apt update
sudo apt-get install \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libcups2 \
    libdrm2 \
    libglib2.0-0 \
    libgtk-3-0 \
    libnss3 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxrandr2 \
    libxrender1 \
    libxss1 \
    libxtst6 \
    fonts-noto-color-emoji \
    gconf-service \
    gconf2 \
    libasound2 \
    libgbm1 \
    libpango-1.0-0 -y

sudo ldconfig

# ----------------------------------------------------------------
# Get the application you want to run on this server:
mkdir /srv/
cd /srv/
git clone --depth 1 $GIT_REPO_CONFIG
git clone --depth 1 $GIT_REPO_PORTALO

# Install all packages
cd /srv/soknadsguiden/backend/
npm install --production --force

# Logging folders
mkdir /var/log/soknadsguiden/
chown -R ubuntu:ubuntu /var/log/soknadsguiden/
chmod u+w /var/log/soknadsguiden/

# Pid file
mkdir /var/run/soknadsguiden/
chown -R ubuntu:ubuntu /var/run/soknadsguiden/
chmod u+w /var/run/soknadsguiden/

# node app/server.js -c /srv/config/soknadsguiden/config.js

cat > /etc/systemd/system/soknadsguiden.service <<EOF
[Unit]
Description=soknadsguiden.app

[Service]
Type=simple
ExecStart=/usr/local/bin/node /srv/soknadsguiden/backend/app/server.js -c /srv/config/soknadsguiden/config.js

StandardOutput=file:/var/log/soknadsguiden/soknadsguiden.app.log
StandardError=file:/var/log/soknadsguiden/soknadsguiden.app.error

Restart=on-failure
EOF


# Run the application:
service soknadsguiden start


# ----------------------------------------------------------------
# sudo service soknadsguiden.service status