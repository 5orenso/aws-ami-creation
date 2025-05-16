#!/bin/bash

export LC_ALL=en_US.UTF-8

# ----------------------------------------------------------------
# Update hostfile
cat >> /etc/hosts <<'EOF'
# MongoDB setup.
172.31.32.220        mongo20.raskepoter.no
172.31.0.221         mongo21.raskepoter.no
172.31.16.222        mongo22.raskepoter.no
172.31.32.223        mongo23.raskepoter.no

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
git clone --depth 1 $GIT_REPO_MUSHER

# Install all packages
cd /srv/musher/
npm install --production --force

# Logging folders
mkdir /var/log/musher/
chown -R ubuntu:ubuntu /var/log/musher/
chmod u+w /var/log/musher/

# Pid file
mkdir /var/run/musher/
chown -R ubuntu:ubuntu /var/run/musher/
chmod u+w /var/run/musher/

# node app/server.js -c /srv/config/musher/config.js

cat > /etc/systemd/system/themusher.service <<EOF
[Unit]
Description=themusher.app

[Service]
Type=simple
Environment="GOOGLE_APPLICATION_CREDENTIALS=/srv/musher/the-musher-100940e760c0.json"
ExecStart=/usr/local/bin/node /srv/musher/app/server.js -c /srv/musher/config/config.js

StandardOutput=file:/var/log/musher/themusher.app.log
StandardError=file:/var/log/musher/themusher.app.error

Restart=on-failure
EOF


# Run the application:
service themusher start


# ----------------------------------------------------------------
# sudo service themusher status