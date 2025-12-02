#!/usr/bin/bash

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
172.30.2.220        mongo20.flyfisheurope.com
172.30.0.221        mongo21.flyfisheurope.com
172.30.1.222        mongo22.flyfisheurope.com
172.30.2.223        mongo23.flyfisheurope.com
EOF

mkdir /root/.node-gyp/

# Fix telegraph config
cat > /etc/telegraf/telegraf.conf <<'EOF'
# Telegraf Configuration

# Global tags can be specified here in key="value" format.
[global_tags]
  # dc = "us-east-1" # will tag all metrics with dc=us-east-1

# Configuration for telegraf agent
[agent]
  interval = "10s"
  round_interval = true
  metric_batch_size = 1000
  metric_buffer_limit = 10000
  collection_jitter = "0s"
  flush_interval = "10s"
  flush_jitter = "0s"
  precision = ""
  debug = false
  quiet = false
  logfile = ""

  hostname = ""
  omit_hostname = false

###############################################################################
#                            OUTPUT PLUGINS                                   #
###############################################################################

# Configuration for influxdb server to send metrics to
[[outputs.influxdb]]
  urls = ["http://172.30.1.31:8086"] # required
  database = "telegraf" # required
  retention_policy = ""
  write_consistency = "any"
  timeout = "5s"
  username = "telegraf"
  password = "telegraf"

###############################################################################
#                            INPUT PLUGINS                                    #
###############################################################################

# Read metrics about cpu usage
[[inputs.cpu]]
  percpu = true
  totalcpu = true
  collect_cpu_time = false

# Read metrics about disk usage by mount point
[[inputs.disk]]
  ignore_fs = ["tmpfs", "devtmpfs"]


# Read metrics about disk IO by device
[[inputs.diskio]]
  # no configuration

# Get kernel statistics from /proc/stat
[[inputs.kernel]]
  # no configuration

# Read metrics about memory usage
[[inputs.mem]]
  # no configuration

# Get the number of processes and group them by status
[[inputs.processes]]
  # no configuration

# Read metrics about swap memory usage
[[inputs.swap]]
  # no configuration

# Read metrics about system load & uptime
[[inputs.system]]
  # no configuration

# Statsd Server
[[inputs.statsd]]
  service_address = ":8125"
  delete_gauges = true
  delete_counters = true
  delete_sets = false
  delete_timings = true
  percentiles = [90]
  metric_separator = "_"
  parse_data_dog_tags = false
  templates = [
      "cpu.* measurement*"
  ]
  allowed_pending_messages = 10000
  percentile_limit = 1000
  udp_packet_size = 1500

EOF

# Restart telegraf service:
service telegraf stop
service telegraf start


# Install missing modules
sudo apt-get update
sudo apt-get install -y \
    libnss3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libx11-xcb1 \
    libdrm2 \
    libgbm1 \
    libxdamage1 \
    libxcomposite1 \
    libxext6 \
    libxfixes3 \
    libxrandr2 \
    libgtk-3-0 \
    libasound2

# ----------------------------------------------------------------
# Get the application you want to run on this server:
mkdir /srv/
cd /srv/
git clone --depth=1 $GIT_REPO_CONFIG
git clone --depth=1 $GIT_REPO_EAGLEEYE
git clone --depth=1 $GIT_REPO_WELAND
git clone --depth=1 $GIT_REPO_LIVERACE
git clone --depth=1 $GIT_REPO_KEEPSPOT
git clone --depth=1 $GIT_REPO_RASKEPOTER
git clone --depth=1 $GIT_REPO_DYREJOURNAL
# Clone GIT_REPO_DYREJOURNAL into beta folder dyrejournal-beta
git clone --depth=1 $GIT_REPO_DYREJOURNAL dyrejournal-beta
git clone --depth=1 $GIT_REPO_SIMPLE_BLOG

# Install all packages
cd /srv/eagle-eye-ai/
npm install --force
git lfs fetch --all
git lfs pull

cd /srv/weland/backend/
npm install --force

cd /srv/liverace/backend/
npm install --force

cd /srv/keepspot/backend/
npm install --force

cd /srv/raskepoter/backend/
npm install --force

cd /srv/dyrejournal/backend/
npm install --force

cd /srv/dyrejournal-beta/backend/
npm install --force

cd /srv/simple-blog/
npm install --force

# Logging folders
mkdir /var/log/simple-blog/
chown -R ubuntu:ubuntu /var/log/simple-blog/
chmod u+w /var/log/simple-blog/

mkdir /srv/simple-blog/logs/
chown -R ubuntu:ubuntu /srv/simple-blog/logs/
chmod u+w /srv/simple-blog/logs/

mkdir /var/log/eagle-eye-ai/
chown -R ubuntu:ubuntu /var/log/eagle-eye-ai/
chmod u+w /var/log/eagle-eye-ai/

mkdir /var/log/weland/
chown -R ubuntu:ubuntu /var/log/weland/
chmod u+w /var/log/weland/

mkdir /var/log/liverace/
chown -R ubuntu:ubuntu /var/log/liverace/
chmod u+w /var/log/liverace/

mkdir /var/log/keepspot/
chown -R ubuntu:ubuntu /var/log/keepspot/
chmod u+w /var/log/keepspot/

mkdir /var/log/raskepoter/
chown -R ubuntu:ubuntu /var/log/raskepoter/
chmod u+w /var/log/raskepoter/

mkdir /var/log/dyrejournal/
chown -R ubuntu:ubuntu /var/log/dyrejournal/
chmod u+w /var/log/dyrejournal/

# Create cron job script for sitemap generation
cat >> /etc/cron.daily/simple-blog-sitemap.sh <<EOF
#!/usr/bin/bash

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
Environment="GOOGLE_APPLICATION_CREDENTIALS=/srv/config/node-ffe-web/ffe-dealerweb-c587eaa3f46b.json"
ExecStart=/usr/local/bin/node /srv/simple-blog/app/server.js -c /srv/config/simple-blog/config-${domain}.js  >> /var/log/simple-blog/simple-blog-${domain}.log 2>&1
StandardOutput=null
Restart=on-failure

EOF

# Reload system daemon
systemctl daemon-reload

# Run the application:
service simple-blog-${domain} start

# Add crontab entries
cat >> /etc/cron.daily/simple-blog-sitemap.sh <<EOF
/usr/local/bin/node /srv/simple-blog/app/sitemap.js -c /srv/config/simple-blog/config-${domain}.js > /dev/null 2>&1
EOF

done < "/srv/config/simple-blog/active-domains.txt"

# ---[ /ALL active domains ]--------------------------------------------------

cat > /etc/systemd/system/eagleeyeai.litt.no.service <<EOF
[Unit]
Description=eagleeyeai.litt.no

[Service]
Type=simple
ExecStart=/usr/local/bin/node /srv/eagle-eye-ai/app/server.js -c /srv/config/eagle-eye-ai/config.js >> /var/log/simple-blog/eagleeyeai.litt.no.log 2>&1
StandardOutput=null
Restart=on-failure

EOF

cat > /etc/systemd/system/weland.app.service <<EOF
[Unit]
Description=weland.app

[Service]
Type=simple
Environment="GOOGLE_APPLICATION_CREDENTIALS=/srv/weland/the-musher-100940e760c0.json"
ExecStart=/usr/local/bin/node /srv/weland/backend/app/server.js -c /srv/config/weland/config.js >> /var/log/weland/weland.app.log 2>&1
StandardOutput=null
Restart=on-failure

EOF

cat > /etc/systemd/system/liverace.app.service <<EOF
[Unit]
Description=liverace.app

[Service]
Type=simple
Environment="GOOGLE_APPLICATION_CREDENTIALS=/srv/liverace/the-musher-100940e760c0.json"
ExecStart=/usr/local/bin/node /srv/liverace/backend/app/server.js -c /srv/config/liverace/config.js >> /var/log/liverace/liverace.app.log 2>&1
StandardOutput=null
Restart=on-failure

EOF

cat > /etc/systemd/system/keepspot.app.service <<EOF
[Unit]
Description=keepspot.app

[Service]
Type=simple
Environment="GOOGLE_APPLICATION_CREDENTIALS=/srv/keepspot/the-musher-100940e760c0.json"
ExecStart=/usr/local/bin/node /srv/keepspot/backend/app/server.js -c /srv/config/keepspot/config.js >> /var/log/keepspot/keepspot.app.log 2>&1
StandardOutput=null
Restart=on-failure

EOF

cat > /etc/systemd/system/raskepoter.app.service <<EOF
[Unit]
Description=raskepoter.app

[Service]
Type=simple
Environment="GOOGLE_APPLICATION_CREDENTIALS=/srv/raskepoter/the-musher-100940e760c0.json"
ExecStart=/usr/local/bin/node /srv/raskepoter/backend/app/server.js -c /srv/config/raskepoter/config.js >> /var/log/raskepoter/raskepoter.app.log 2>&1
StandardOutput=null
Restart=on-failure

EOF

cat > /etc/systemd/system/dyrejournal.app.service <<EOF
[Unit]
Description=dyrejournal.app

[Service]
Type=simple
Environment="GOOGLE_APPLICATION_CREDENTIALS=/srv/dyrejournal/the-musher-100940e760c0.json"
ExecStart=/usr/local/bin/node /srv/dyrejournal/backend/app/server.js -c /srv/config/dyrejournal/config.js >> /var/log/dyrejournal/dyrejournal.app.log 2>&1
StandardOutput=null
Restart=on-failure

EOF

cat > /etc/systemd/system/dyrejournal-beta.app.service <<EOF
[Unit]
Description=dyrejournal-beta.app

[Service]
Type=simple
Environment="GOOGLE_APPLICATION_CREDENTIALS=/srv/dyrejournal-beta/the-musher-100940e760c0.json"
ExecStart=/usr/local/bin/node /srv/dyrejournal-beta/backend/app/server.js -c /srv/config/dyrejournal/config-beta.js >> /var/log/dyrejournal/dyrejournal-beta.app.log 2>&1
StandardOutput=null
Restart=on-failure

EOF


systemctl daemon-reload
service eagleeyeai.litt.no start
service themusher.litt.no start
service weland.app start
service liverace.app start
service keepspot.app start
service raskepoter.app start
service dyrejournal.app start
service dyrejournal-beta.app start


chmod 755 /etc/cron.daily/simple-blog-sitemap.sh
