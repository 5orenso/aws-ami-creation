#!/bin/bash

export LC_ALL=en_US.UTF-8

# ----------------------------------------------------------------
# Update hostfile
cat >> /etc/hosts <<'EOF'
# MongoDB setup.
172.30.2.220        mongo20.flyfisheurope.com
172.30.0.221        mongo21.flyfisheurope.com
172.30.1.222        mongo22.flyfisheurope.com
172.30.2.223        mongo23.flyfisheurope.com
EOF

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
git clone $GIT_REPO_SIMPLE_BLOG
git clone $GIT_REPO_MUSHER

# Install all packages
cd /srv/simple-blog/
npm install --production

cd /srv/musher/
npm install --production

# Logging folders
mkdir /var/log/simple-blog/
chown -R ubuntu:ubuntu /var/log/simple-blog/
chmod u+w /var/log/simple-blog/

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

# node app/server.js -c /srv/config/musher/config.js


cat > /etc/systemd/system/simple-blog-femundlopet.no.service <<EOF
[Unit]
Description=simple-blog-femundlopet.no

[Service]
Type=simple
Environment="GOOGLE_APPLICATION_CREDENTIALS=/srv/config/node-ffe-web/ffe-dealerweb-c587eaa3f46b.json"
ExecStart=/usr/local/bin/node /srv/simple-blog/app/server.js -c /srv/config/simple-blog/config-femundlopet.no.js  >> /var/log/simple-blog/simple-blog-femundlopet.no.log 2>&1

StandardOutput=/var/log/simple-blog/simple-blog-femundlopet.no.log
StandardError=file:/var/log/simple-blog/simple-blog-femundlopet.no.error

Restart=on-failure
EOF


cat > /etc/systemd/system/simple-blog-themusher.no.service <<EOF
[Unit]
Description=simple-blog-themusher.no

[Service]
Type=simple
Environment="GOOGLE_APPLICATION_CREDENTIALS=/srv/config/node-ffe-web/ffe-dealerweb-c587eaa3f46b.json"
ExecStart=/usr/local/bin/node /srv/simple-blog/app/server.js -c /srv/config/simple-blog/config-themusher.no.js  >> /var/log/simple-blog/simple-blog-themusher.no.log 2>&1

StandardOutput=/var/log/simple-blog/simple-blog-themusher.no.log
StandardError=file:/var/log/simple-blog/simple-blog-themusher.no.error

Restart=on-failure
EOF

cat > /etc/systemd/system/themusher.litt.no.service <<EOF
[Unit]
Description=themusher.app

[Service]
Type=simple
Environment="GOOGLE_APPLICATION_CREDENTIALS=/srv/musher/the-musher-100940e760c0.json"
ExecStart=/usr/bin/node /srv/musher/app/server.js -c /srv/config/musher/config.js

StandardOutput=file:/var/log/musher/themusher.app.log
StandardError=file:/var/log/musher/themusher.app.error

Restart=on-failure
EOF

# Run the application:
service simple-blog-femundlopet.no start
service simple-blog-themusher.no start
service themusher.litt.no start