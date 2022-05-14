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

# ----------------------------------------------------------------
# Get the application you want to run on this server:
mkdir /srv/
cd /srv/
git clone $GIT_REPO_CONFIG
git clone $GIT_REPO_MUSHER
git clone $GIT_REPO_EAGLEEYE
git clone https://github.com/5orenso/simple-blog.git

# Install all packages
cd /srv/simple-blog/
npm install --force

cd /srv/musher/
npm install --production --force

cd /srv/eagle-eye-ai/
npm install --production --force
git lfs fetch --all
git lfs pull

# Logging folders
mkdir /var/log/simple-blog/
chown -R ubuntu:ubuntu /var/log/simple-blog/
chmod u+w /var/log/simple-blog/

mkdir /srv/simple-blog/logs/
chown -R ubuntu:ubuntu /srv/simple-blog/logs/
chmod u+w /srv/simple-blog/logs/


mkdir /var/log/musher/
chown -R ubuntu:ubuntu /var/log/musher/
chmod u+w /var/log/musher/

# Pid file
mkdir /var/run/simple-blog/
chown -R ubuntu:ubuntu /var/run/simple-blog/
chmod u+w /var/run/simple-blog/

mkdir /var/run/musher/
chown -R ubuntu:ubuntu /var/run/musher/
chmod u+w /var/run/musher/

mkdir /var/run/eagle-eye-ai/
chown -R ubuntu:ubuntu /var/run/eagle-eye-ai/
chmod u+w /var/run/eagle-eye-ai/

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

cat > /etc/systemd/system/themusher.litt.no.service <<EOF
[Unit]
Description=themusher.litt.no

[Service]
Type=simple
Environment="GOOGLE_APPLICATION_CREDENTIALS=/srv/musher/the-musher-100940e760c0.json"
ExecStart=/usr/local/bin/node /srv/musher/app/server.js -c /srv/config/musher/config.js >> /var/log/simple-blog/themusher.litt.no.log 2>&1
StandardOutput=null
Restart=on-failure

EOF

systemctl daemon-reload
service eagleeyeai.litt.no start
service themusher.litt.no start

chmod 755 /etc/cron.daily/simple-blog-sitemap.sh

cat >> /etc/cron.hourly/themusher <<EOF
#!/usr/bin/bash

# /usr/local/bin/node /srv/musher/bin/scrollView-update-stories.js -c /srv/config/musher/config.js -d 2  >> /home/ubuntu/scrollView-update-stories.js.log 2>&1

# 1/* * * * * /usr/local/bin/node /srv/musher/bin/get-tracking-data-pasviktrail-2022.js --config /srv/config/musher/config.js --race pasviktrail_2022 >> /home/ubuntu/get-tracking-data-pasviktrail-2022.js.log 2>&1
EOF

chmod 755 /etc/cron.hourly/themusher

cat >> /etc/cron.daily/themusher <<EOF
#!/usr/bin/bash

# Generate all stats:
# /usr/local/bin/node /srv/musher/bin/getStats.js -c /srv/config/musher/config.js >> /home/ubuntu/getStats.js.log 2>&1

# Generate new map images for workouts that nobody has opened:
# /usr/local/bin/node /srv/musher/bin/generate-new-map-images.js -c /srv/config/musher/config.js -d 1  >> /home/ubuntu/generate-new-map-images.js.log 2>&1

# Calculate dog fitness based on workouts:
# /usr/local/bin/node /srv/musher/bin/dog-calc-fitness.js -c /srv/config/musher/config.js --yesterday  >> /home/ubuntu/dog-calc-fitness.js.log 2>&1

# Calculate team fitness based on workouts:
# /usr/local/bin/node /srv/musher/bin/team-calc-fitness.js -c /srv/config/musher/config.js --yesterday  >> /home/ubuntu/team-calc-fitness.js.log 2>&1

# Award trophies based on your progress:
# /bin/bash /srv/musher/bin/trophy-awards-2021-2022.sh >> /home/ubuntu/trophy-awards-2021-2022.sh.log 2>&1

# Send birthday emails:
# /usr/local/bin/node /srv/musher/bin/send-birthday-reminder.js -c /srv/config/musher/config.js >> /home/ubuntu/send-birthday-reminder.js.log 2>&1

# Send notification emails:
# /usr/local/bin/node /srv/musher/bin/send-notification-reminder.js -c /srv/config/musher/config.js -l 5000 >> /home/ubuntu/send-notification-reminder.js.log 2>&1

EOF

chmod 755 /etc/cron.daily/themusher