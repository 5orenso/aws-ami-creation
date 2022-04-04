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
Environment="GOOGLE_APPLICATION_CREDENTIALS=/srv/config/node-ffe-web/ffe-dealerweb-c587eaa3f46b.json"
ExecStart=/usr/bin/node /srv/simple-blog/app/server.js -c /srv/config/simple-blog/config-${domain}.js  >> /var/log/simple-blog/simple-blog-${domain}.log 2>&1
StandardOutput=null
Restart=on-failure

EOF

# Run the application:
service simple-blog-${domain} start

# Add crontab entries
cat >> /etc/cron.daily/simple-blog-sitemap.sh <<EOF
/usr/bin/node /srv/simple-blog/app/sitemap.js -c /srv/config/simple-blog/config-${domain}.js > /dev/null 2>&1
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

cat > /etc/systemd/system/eagleeyeai.litt.no.service <<EOF
[Unit]
Description=eagleeyeai.litt.no

[Service]
Type=simple
ExecStart=/usr/bin/node /srv/eagle-eye-ai/app/server.js -c /srv/eagle-eye-ai/config/config.js >> /var/log/simple-blog/eagleeyeai.litt.no.log 2>&1
StandardOutput=null
Restart=on-failure

EOF

cat > /etc/systemd/system/themusher.litt.no.service <<EOF
[Unit]
Description=themusher.litt.no

[Service]
Type=simple
Environment="GOOGLE_APPLICATION_CREDENTIALS=/srv/musher/the-musher-100940e760c0.json"
ExecStart=/usr/bin/node /srv/musher/app/server.js -c /srv/musher/config/config.js >> /var/log/simple-blog/themusher.litt.no.log 2>&1
StandardOutput=null
Restart=on-failure

EOF

cat > /etc/systemd/system/wifetoperator.litt.no.service <<EOF
[Unit]
Description=wifetoperator.litt.no

[Service]
Type=simple
ExecStart=/usr/bin/node /srv/wifet-operator-api/app/server.js -c /srv/wifet-operator-api/config/config.js >> /var/log/simple-blog/wifetoperator.litt.no.log 2>&1
StandardOutput=null
Restart=on-failure

EOF


chmod 755 /etc/cron.hourly/simple-blog-sitemap.sh
service awslogs restart
