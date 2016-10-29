#!/bin/bash

export LC_ALL=en_US.UTF-8

# Associate Elastic IP with instance if not associated before.
INSTANCE_ID=`curl http://169.254.169.254/latest/meta-data/instance-id`
#aws ec2 associate-address --instance-id $INSTANCE_ID --public-ip $ELASTIC_IP --allow-reassociation --region eu-west-1
CURRENT_INSTANCE_ID=$(/usr/bin/aws ec2 describe-addresses --allocation-ids $ELASTIC_IP_ALLOCATION_ID --region eu-west-1 | jq -r '.Addresses[].InstanceId')
DOWNLOAD_AND_PARSE_VISMA_FILES='# Do nothing. Only fetch these files on 1 server. Use the one with the Elastic IP.'
if [[ $CURRENT_INSTANCE_ID == null ]] ; then
    /usr/bin/aws ec2 associate-address --instance-id $INSTANCE_ID --allocation-id $ELASTIC_IP_ALLOCATION_ID --allow-reassociation --region eu-west-1
    DOWNLOAD_AND_PARSE_VISMA_FILES='2,7,12,17,22,27,32,37,42,47,52,57 * * * * /bin/bash /var/www/dealer.flyfisheurope.com/zu/cli/download_xml_files.sh >> /var/www/dealer.flyfisheurope.com/zu/cli/log/download_xml_files.`/bin/date +\%Y\%m\%d`.log 2>&1'

    mkdir /home/ubuntu/weborder_S3/
    chown ubuntu.ubuntu /home/ubuntu/weborder_S3/
    /usr/bin/aws s3 sync s3://ffe-bin/ /home/ubuntu/ --region eu-west-1
    EXPORT_WEBORDERS_TO_S3='0 1 * * *  /bin/bash /home/ubuntu/weborder_export.sh'
fi

# ----------------------------------------------------------------
# Update hostfile
cat >> /etc/hosts <<'EOF'
# MongoDB setup.
172.30.2.250        mongo0.flyfisheurope.com
172.30.1.250        mongo1.flyfisheurope.com
172.30.0.250        mongo2.flyfisheurope.com
EOF


# ----------------------------------------------------------------
# Get the applications and configs you want to run on this server:
cd /srv/
git clone $GIT_REPO_CONFIG
git clone $GIT_REPO_ZU_CMS

# --> Zu-CMS
# Install all Node.js packages
ln -s /srv/Zu-CMS /srv/zu
cd /srv/zu/
npm install --production

# Config file
ln -s /srv/config/ffe/Zu-CMS/zu/config.js /srv/Zu-CMS/config/config.js
cp /srv/config/ffe/etc/init/zu.conf /etc/init/zu.conf

# Log folder
mkdir /srv/Zu-CMS/logs/
mkdir /var/log/Zu-CMS/
mkdir /var/log/zu/
mkdir /var/run/zu/
chown www-data.www-data /var/log/Zu-CMS/ /var/run/zu/ /var/log/zu/ /srv/Zu-CMS/logs/

chown www-data:www-data /srv/Zu-CMS/
chmod 755 /srv/Zu-CMS/

aws s3 sync s3://ffe-visma-import/ /srv/Zu-CMS/example/ --region eu-west-1

service zu start

# --> FFE-CMS
# PHP
chown www-data.www-data /var/www/
chmod 755 /var/www/
chmod g+s /var/www/

# www.flyfisheurope.com
# git clone creates the target folder with mkdir -p
git clone $GIT_REPO_FFE_CMS /var/www/www.flyfisheurope.com/zu/
mkdir -p /var/www/www.flyfisheurope.com/images/cache/
ln -s /srv/config/ffe/FFE-CMS/www.flyfisheurope.com/main.ini /var/www/www.flyfisheurope.com/zu/config/main.ini
ln -s /var/www/www.flyfisheurope.com/zu/view/consumer_web/css /var/www/www.flyfisheurope.com/css
ln -s /var/www/www.flyfisheurope.com/zu/view/consumer_web/js /var/www/www.flyfisheurope.com/js
ln -s /var/www/www.flyfisheurope.com/zu/view/consumer_web/posters /var/www/www.flyfisheurope.com/posters
ln -s /var/www/www.flyfisheurope.com/zu/view/consumer_web/img /var/www/www.flyfisheurope.com/imgs
ln -s /var/www/www.flyfisheurope.com/zu/qrcodes /var/www/www.flyfisheurope.com/qrcodes

mkdir /var/www/www.flyfisheurope.com/fancyBox/
mkdir /var/www/www.flyfisheurope.com/img/
mkdir /var/www/www.flyfisheurope.com/jafw/
mkdir /var/www/www.flyfisheurope.com/jquery-file-upload/
mkdir /var/www/www.flyfisheurope.com/sizechart/
mkdir /var/www/www.flyfisheurope.com/test/

# Files from s3
/usr/bin/aws s3 sync s3://ffe-static-web/images/ /var/www/www.flyfisheurope.com/images/ --region eu-west-1
/usr/bin/aws s3 sync s3://ffe-static-web/fancyBox/ /var/www/www.flyfisheurope.com/fancyBox/ --region eu-west-1
/usr/bin/aws s3 sync s3://ffe-static-web/img/ /var/www/www.flyfisheurope.com/img/ --region eu-west-1
/usr/bin/aws s3 sync s3://ffe-static-web/jafw/ /var/www/www.flyfisheurope.com/jafw/ --region eu-west-1
/usr/bin/aws s3 sync s3://ffe-static-web/jquery-file-upload/ /var/www/www.flyfisheurope.com/jquery-file-upload/ --exclude "server/php/files/*" --region eu-west-1
/usr/bin/aws s3 sync s3://ffe-static-web/sizechart/ /var/www/www.flyfisheurope.com/sizechart/ --region eu-west-1
/usr/bin/aws s3 sync s3://ffe-static-web/test/ /var/www/www.flyfisheurope.com/test/ --region eu-west-1
/usr/bin/aws s3 cp s3://ffe-static-web/index.html /var/www/www.flyfisheurope.com/index.html --region eu-west-1
/usr/bin/aws s3 cp s3://ffe-static-web/index_dealer.html /var/www/www.flyfisheurope.com/index_dealer.html --region eu-west-1
/usr/bin/aws s3 cp s3://ffe-static-web/favicon.ico /var/www/www.flyfisheurope.com/favicon.ico --region eu-west-1
/usr/bin/aws s3 cp s3://ffe-static-web/img.php /var/www/www.flyfisheurope.com/img.php --region eu-west-1
/usr/bin/aws s3 sync s3://ffe-static-web/qrcodes /var/www/www.flyfisheurope.com/zu/qrcodes --region eu-west-1

ln -s /var/www/www.flyfisheurope.com/images /var/www/www.flyfisheurope.com/jquery-file-upload/server/php/files
mv /var/www/www.flyfisheurope.com/jquery-file-upload/server/php/index.php /var/www/www.flyfisheurope.com/jquery-file-upload/server/php/index.php.old
mv /var/www/www.flyfisheurope.com/jquery-file-upload/server/php/UploadHandler.php /var/www/www.flyfisheurope.com/jquery-file-upload/server/php/UploadHandler.php.old
ln -s /var/www/www.flyfisheurope.com/zu/jquery-file-upload/index.php /var/www/www.flyfisheurope.com/jquery-file-upload/server/php/.
ln -s /var/www/www.flyfisheurope.com/zu/jquery-file-upload/UploadHandler.php /var/www/www.flyfisheurope.com/jquery-file-upload/server/php/.

mkdir /var/www/www.flyfisheurope.com/server
ln -s /var/www/www.flyfisheurope.com/zu /var/www/www.flyfisheurope.com/server/php

# dev.zu.no
# git clone creates the target folder with mkdir -p
git clone $GIT_REPO_FFE_CMS /var/www/dev.zu.no/zu/
ln -s /var/www/www.flyfisheurope.com/images /var/www/dev.zu.no/.
ln -s /var/www/www.flyfisheurope.com/fancyBox /var/www/dev.zu.no/.
ln -s /var/www/www.flyfisheurope.com/img /var/www/dev.zu.no/.
ln -s /var/www/www.flyfisheurope.com/jafw /var/www/dev.zu.no/.
ln -s /var/www/www.flyfisheurope.com/jquery-file-upload /var/www/dev.zu.no/.
ln -s /var/www/www.flyfisheurope.com/sizechart /var/www/dev.zu.no/.
ln -s /var/www/www.flyfisheurope.com/test /var/www/dev.zu.no/.
ln -s /var/www/www.flyfisheurope.com/index_dealer.html /var/www/dev.zu.no/index.html
ln -s /var/www/www.flyfisheurope.com/favicon.ico /var/www/dev.zu.no/.
ln -s /var/www/www.flyfisheurope.com/img.php /var/www/dev.zu.no/.

ln -s /srv/config/ffe/FFE-CMS/dev.zu.no/main.ini /var/www/dev.zu.no/zu/config/main.ini
ln -s /var/www/dev.zu.no/zu/view/consumer_web/css /var/www/dev.zu.no/css
ln -s /var/www/dev.zu.no/zu/view/consumer_web/js /var/www/dev.zu.no/js
ln -s /var/www/dev.zu.no/zu/view/consumer_web/posters /var/www/dev.zu.no/posters
ln -s /var/www/dev.zu.no/zu/view/consumer_web/img /var/www/dev.zu.no/imgs
ln -s /var/www/www.flyfisheurope.com/zu/qrcodes /var/www/dev.zu.no/qrcodes

mkdir /var/www/dev.zu.no/server
ln -s /var/www/dev.zu.no/zu /var/www/dev.zu.no/server/php

# dealer.flyfisheurope.com
# git clone creates the target folder with mkdir -p
git clone $GIT_REPO_FFE_CMS /var/www/dealer.flyfisheurope.com/zu/
ln -s /var/www/www.flyfisheurope.com/images /var/www/dealer.flyfisheurope.com/.
ln -s /var/www/www.flyfisheurope.com/fancyBox /var/www/dealer.flyfisheurope.com/.
ln -s /var/www/www.flyfisheurope.com/img /var/www/dealer.flyfisheurope.com/.
ln -s /var/www/www.flyfisheurope.com/jafw /var/www/dealer.flyfisheurope.com/.
ln -s /var/www/www.flyfisheurope.com/jquery-file-upload /var/www/dealer.flyfisheurope.com/.
ln -s /var/www/www.flyfisheurope.com/sizechart /var/www/dealer.flyfisheurope.com/.
ln -s /var/www/www.flyfisheurope.com/test /var/www/dealer.flyfisheurope.com/.
ln -s /var/www/www.flyfisheurope.com/index_dealer.html /var/www/dealer.flyfisheurope.com/index.html
ln -s /var/www/www.flyfisheurope.com/favicon.ico /var/www/dealer.flyfisheurope.com/.
ln -s /var/www/www.flyfisheurope.com/img.php /var/www/dealer.flyfisheurope.com/.

ln -s /srv/config/ffe/FFE-CMS/dealer.flyfisheurope.com/main.ini /var/www/dealer.flyfisheurope.com/zu/config/main.ini
ln -s /var/www/dealer.flyfisheurope.com/zu/view/consumer_web/css /var/www/dealer.flyfisheurope.com/css
ln -s /var/www/dealer.flyfisheurope.com/zu/view/consumer_web/js /var/www/dealer.flyfisheurope.com/js
ln -s /var/www/dealer.flyfisheurope.com/zu/view/consumer_web/posters /var/www/dealer.flyfisheurope.com/posters
ln -s /var/www/dealer.flyfisheurope.com/zu/view/consumer_web/img /var/www/dealer.flyfisheurope.com/imgs
ln -s /var/www/www.flyfisheurope.com/zu/qrcodes /var/www/dealer.flyfisheurope.com/qrcodes
mkdir /var/www/dealer.flyfisheurope.com/visma
mkdir /var/www/dealer.flyfisheurope.com/zu/cli/log/

mkdir /var/www/dealer.flyfisheurope.com/server
ln -s /var/www/dealer.flyfisheurope.com/zu /var/www/dealer.flyfisheurope.com/server/php

# Chown
chown -R www-data.www-data /var/www/

mkdir /var/log/FFE-CMS
mkdir /var/run/FFE-CMS

chown www-data.www-data /var/log/FFE-CMS/
chown www-data.www-data /var/run/FFE-CMS/

mv /etc/php5/apache2/php.ini /etc/php5/apache2/php.ini.old
ln -s /srv/config/ffe/php5/apache2/php.ini /etc/php5/apache2/php.ini
ln -s /srv/config/ffe/php5/mods-available/mongo.ini /etc/php5/apache2/conf.d/20-mongo.ini
ln -s /srv/config/ffe/php5/mods-available/mongo.ini /etc/php5/cli/conf.d/20-mongo.ini

# Fix apache configs.
mv /etc/apache2/apache2.conf /etc/apache2/apache2.conf.old
ln -s /srv/config/ffe/apache2/apache2.conf /etc/apache2/apache2.conf
mv /etc/apache2/ports.conf /etc/apache2/ports.conf.old
touch /etc/apache2/httpd.conf
ln -s /srv/config/ffe/apache2/ports.conf /etc/apache2/ports.conf
ln -s /srv/config/ffe/apache2/sites-enabled/dealer.flyfisheurope.com /etc/apache2/sites-enabled/dealer.flyfisheurope.com
ln -s /srv/config/ffe/apache2/sites-enabled/www.flyfisheurope.com /etc/apache2/sites-enabled/www.flyfisheurope.com
ln -s /srv/config/ffe/apache2/sites-enabled/dev.zu.no /etc/apache2/sites-enabled/dev.zu.no

# Fix varnish config.
mv /etc/varnish/default.vcl /etc/varnish/default.vcl.old
ln -s /srv/config/ffe/varnish/default.vcl /etc/varnish/default.vcl

mv /etc/default/varnish /etc/default/varnish.old
ln -s /srv/config/ffe/etc/default/varnish /etc/default/varnish

# Fix fail2ban config
mv /etc/fail2ban/jail.conf /etc/fail2ban/jail.conf.old
ln -s /srv/config/ffe/etc/fail2ban/jail.conf /etc/fail2ban/.
service fail2ban restart

# Fix logrotate config
rm /etc/logrotate.d/apache2 /etc/logrotate.d/fail2ban
ln -s /srv/config/ffe/etc/logrotate.d/apache2 /etc/logrotate.d/.
ln -s /srv/config/ffe/etc/logrotate.d/fail2ban /etc/logrotate.d/.
ln -s /srv/config/ffe/etc/logrotate.d/zu /etc/logrotate.d/.
ln -s /srv/config/ffe/etc/logrotate.d/mail /etc/logrotate.d/.
ln -s /srv/config/ffe/etc/logrotate.d/syslog /etc/logrotate.d/.
rm /etc/logrotate.d/rsyslog
ln -s /srv/config/ffe/etc/logrotate.d/rsyslog /etc/logrotate.d/.

# Fix postfix config. Sending email via sendgrid.
mv /etc/postfix/main.cf /etc/postfix/main.cf.old
ln -s /srv/config/ffe/etc/postfix/main.cf /etc/postfix/main.cf
ln -s /srv/config/ffe/etc/postfix/generic /etc/postfix/generic
postmap /etc/postfix/generic

service postfix restart

# Logs to AWS Cloudwatch
cat > /var/awslogs/etc/awslogs.conf <<'EOF'
[general]
state_file = /var/awslogs/state/agent-state

[/var/log/zu.log]
datetime_format = %Y-%m-%d %H:%M:%S
file = /var/log/zu.log
buffer_duration = 5000
log_stream_name = {instance_id}
initial_position = start_of_file
log_group_name = api/apilog.log

[/var/log/zu.sys.log]
datetime_format = %Y-%m-%d %H:%M:%S
file = /var/log/zu.sys.log
buffer_duration = 5000
log_stream_name = {instance_id}
initial_position = start_of_file
log_group_name = api/request.log
EOF
service awslogs restart

# Run the applications:
service apache2 restart
service varnish restart

# Cron - from the repo
read -r -d '' ROOT_CRONTAB_LINES <<- EOM
MAILTO=sorenso@gmail.com

# Update date and time
0 3 * * *  /usr/sbin/ntpdate time-b.nist.gov

# Transfer all completed orders.
*/1 * * * * /bin/bash /var/www/dealer.flyfisheurope.com/zu/cli/transfer_orders.sh >> /var/www/dealer.flyfisheurope.com/zu/cli/log/transfer_orders.sh.log 2>&1

# Download and parse all XML files.
${DOWNLOAD_AND_PARSE_VISMA_FILES}

# Cleaning up files
55 5 * * * /usr/bin/find /srv/zu/example/ -name '*.xml' -mtime +1 | /usr/bin/xargs /bin/gzip -9
58 5 * * * /usr/bin/find /srv/zu/example/ -name '*.csv' -mtime +1 | /usr/bin/xargs /bin/gzip -9
55 5 * * * /usr/bin/find /var/www/dealer.flyfisheurope.com/zu/cli/log/ -name '*.log' -mtime +5 | /usr/bin/xargs /bin/gzip -9
55 5 * * * /usr/bin/find /var/www/dealer.flyfisheurope.com/zu/cli/log/ -name '*.json' -mtime +5 | /usr/bin/xargs /bin/gzip -9

# Copy file to AWS S3
0  * * * *  /usr/bin/aws s3 sync /var/www/www.flyfisheurope.com/images/             s3://ffe-static-web/images/ --region eu-west-1 >> /home/ubuntu/aws-s3-sync.log
10 1 * * *  /usr/bin/aws s3 sync /var/www/www.flyfisheurope.com/fancyBox/           s3://ffe-static-web/fancyBox/ --region eu-west-1 >> /home/ubuntu/aws-s3-sync.log
20 1 * * *  /usr/bin/aws s3 sync /var/www/www.flyfisheurope.com/img/                s3://ffe-static-web/img/ --region eu-west-1 >> /home/ubuntu/aws-s3-sync.log
30 1 * * *  /usr/bin/aws s3 sync /var/www/www.flyfisheurope.com/jafw/               s3://ffe-static-web/jafw/ --region eu-west-1 >> /home/ubuntu/aws-s3-sync.log
40 1 * * *  /usr/bin/aws s3 sync /var/www/www.flyfisheurope.com/jquery-file-upload/ s3://ffe-static-web/jquery-file-upload/ --exclude "server/php/files/*" --region eu-west-1 >> /home/ubuntu/aws-s3-sync.log
50 1 * * *  /usr/bin/aws s3 sync /var/www/www.flyfisheurope.com/sizechart/          s3://ffe-static-web/sizechart/ --region eu-west-1 >> /home/ubuntu/aws-s3-sync.log
10 2 * * *  /usr/bin/aws s3 sync /var/www/www.flyfisheurope.com/test/               s3://ffe-static-web/test/ --region eu-west-1 >> /home/ubuntu/aws-s3-sync.log
10 2 * * *  /usr/bin/aws s3 sync /var/www/www.flyfisheurope.com/qrcodes/            s3://ffe-static-web/qrcodes/ --region eu-west-1 >> /home/ubuntu/aws-s3-sync.log
20 2 * * *  /usr/bin/aws s3 cp   /var/www/www.flyfisheurope.com/index.html          s3://ffe-static-web/index.html --region eu-west-1 >> /home/ubuntu/aws-s3-sync.log
30 2 * * *  /usr/bin/aws s3 cp   /var/www/www.flyfisheurope.com/favicon.ico         s3://ffe-static-web/favicon.ico --region eu-west-1 >> /home/ubuntu/aws-s3-sync.log
40 2 * * *  /usr/bin/aws s3 cp   /var/www/www.flyfisheurope.com/img.php             s3://ffe-static-web/img.php --region eu-west-1 >> /home/ubuntu/aws-s3-sync.log

# Copy files from AWS S3
*/5 * * * *  /usr/bin/aws s3 sync s3://ffe-static-web/images/ /var/www/www.flyfisheurope.com/images/ --region eu-west-1 >> /home/ubuntu/aws-s3-sync-down.log
30 * * * *  /usr/bin/aws s3 sync s3://ffe-static-web/qrcodes/ /var/www/www.flyfisheurope.com/qrcodes/ --region eu-west-1 >> /home/ubuntu/aws-s3-sync-down.log
*/5 * * * *  /bin/chown -R www-data.www-data /var/www/www.flyfisheurope.com/images/ >> /home/ubuntu/aws-chown-images.log

# Copy import scripts from AWS S3
40 1 * * *  /usr/bin/aws s3 sync s3://ffe-visma-import/ /srv/Zu-CMS/example/ --exclude "*" --include "*.js" --region eu-west-1
40 1 * * *  /usr/bin/aws s3 sync s3://ffe-visma-import/ /srv/Zu-CMS/example/ --exclude "*" --include "*.json" --region eu-west-1
40 2 * * *  /usr/bin/aws s3 sync /var/www/dealer.flyfisheurope.com/zu/cli/log/ s3://ffe-visma-import-logs/ --region eu-west-1 >> /home/ubuntu/aws-s3-sync.log

# Export weborder history to S3
${EXPORT_WEBORDERS_TO_S3}

EOM

(crontab -l; echo "$ROOT_CRONTAB_LINES" ) | crontab -u root -

mail_body=$(cat <<EOM
Hey,
<p>
New server is online!
<p>
Hostname: $(hostname).<br>
Instance ID: $(curl http://169.254.169.254/latest/meta-data/instance-id).<br>
Current date is: $(date).<br>
<p>
Filesystem:<br>
<xmp>$(df -h)</xmp>
<p>
w:<br>
<xmp>$(w)</xmp>
<p>
Regards,<br>
aws-ami-creation<br>
https://github.com/5orenso/aws-ami-creation/<br>

EOM
)
echo "$mail_body" | mail sorenso@gmail.com -s 'Hey! New server is online :)' -a 'Content-type: text/html;'

# done