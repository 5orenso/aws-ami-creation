#!/bin/bash

export LC_ALL=en_US.UTF-8

# ----------------------------------------------------------------
# Get the applications and configs you want to run on this server:
mkdir /srv/
cd /srv/
git clone $GIT_REPO_CONFIG
git clone $GIT_REPO_ZU_CMS

# --> Zu-CMS
# Install all Node.js packages
cd /srv/Zu-CMS/
npm install --production

# Install the application:
chown www-data:www-data /srv/Zu-CMS/
chmod 755 /srv/Zu-CMS/

# Log folder
mkdir /srv/Zu-CMS/logs/
chown www-data:www-data /srv/Zu-CMS/logs/

# Config file
ln -s /srv/config/ffe/Zu-CMS/zu/config.js /srv/Zu-CMS/config/config.js


# --> FFE-CMS
# PHP
mkdir /var/www/
chown www-data.www-data /var/www/
chmod 755 /var/www/
chmod g+s /var/www/

mkdir /var/www/lib/

# dev.zu.no
mkdir -p /var/www/dev.zu.no/zu/images/
git clone $GIT_REPO_FFE_CMS /var/www/dev.zu.no/zu/
mkdir -p /var/www/dev.zu.no/images/cache/
ln -s /var/www/dev.zu.no/zu/images/index.php /var/www/dev.zu.no/images/index.php
ln -s /var/www/dev.zu.no/zu/images/pix.gif /var/www/dev.zu.no/images/pig.gif
ln -s /srv/config/ffe/FFE-CMS/dev.zu.no/main.ini /var/www/dev.zu.no/zu/config/main.ini
ln -s /var/www/dev.zu.no/zu/view/consumer_web/css /var/www/dev.zu.no/css
ln -s /var/www/dev.zu.no/zu/view/consumer_web/js /var/www/dev.zu.no/js
ln -s /var/www/dev.zu.no/zu/view/consumer_web/posters /var/www/dev.zu.no/posters
ln -s /var/www/dev.zu.no/zu/view/consumer_web/img /var/www/dev.zu.no/imgs
ln -s /var/www/dev.zu.no/zu/qrcodes /var/www/dev.zu.no/qrcodes

# dealer.flyfisheurope.com
mkdir -p /var/www/dealer.flyfisheurope.com/zu/images/
git clone $GIT_REPO_FFE_CMS /var/www/dealer.flyfisheurope.com/zu/
mkdir -p /var/www/dealer.flyfisheurope.com/images/cache/
ln -s /var/www/dealer.flyfisheurope.com/zu/images/index.php /var/www/dealer.flyfisheurope.com/images/index.php
ln -s /var/www/dealer.flyfisheurope.com/zu/images/pix.gif /var/www/dealer.flyfisheurope.com/images/pig.gif
ln -s /srv/config/ffe/FFE-CMS/dealer.flyfisheurope.com/main.ini /var/www/dealer.flyfisheurope.com/zu/config/main.ini
ln -s /var/www/dealer.flyfisheurope.com/zu/view/consumer_web/css /var/www/dealer.flyfisheurope.com/css
ln -s /var/www/dealer.flyfisheurope.com/zu/view/consumer_web/js /var/www/dealer.flyfisheurope.com/js
ln -s /var/www/dealer.flyfisheurope.com/zu/view/consumer_web/posters /var/www/dealer.flyfisheurope.com/posters
ln -s /var/www/dealer.flyfisheurope.com/zu/view/consumer_web/img /var/www/dealer.flyfisheurope.com/imgs
ln -s /var/www/dealer.flyfisheurope.com/zu/qrcodes /var/www/dealer.flyfisheurope.com/qrcodes

# www.flyfisheurope.com
mkdir -p /var/www/www.flyfisheurope.com/zu/images/
git clone $GIT_REPO_FFE_CMS /var/www/www.flyfisheurope.com/zu/
mkdir -p /var/www/www.flyfisheurope.com/images/cache/
ln -s /var/www/www.flyfisheurope.com/zu/images/index.php /var/www/www.flyfisheurope.com/images/index.php
ln -s /var/www/www.flyfisheurope.com/zu/images/pix.gif /var/www/www.flyfisheurope.com/images/pig.gif
ln -s /srv/config/ffe/FFE-CMS/www.flyfisheurope.com/main.ini /var/www/www.flyfisheurope.com/zu/config/main.ini
ln -s /var/www/www.flyfisheurope.com/zu/view/consumer_web/css /var/www/www.flyfisheurope.com/css
ln -s /var/www/www.flyfisheurope.com/zu/view/consumer_web/js /var/www/www.flyfisheurope.com/js
ln -s /var/www/www.flyfisheurope.com/zu/view/consumer_web/posters /var/www/www.flyfisheurope.com/posters
ln -s /var/www/www.flyfisheurope.com/zu/view/consumer_web/img /var/www/www.flyfisheurope.com/imgs
ln -s /var/www/www.flyfisheurope.com/zu/qrcodes /var/www/www.flyfisheurope.com/qrcodes

# Chown
chown -R www-data.www-data /var/www/

mkdir /var/log/FFE-CMS
mkdir /var/run/FFE-CMS

chown www-data.www-data /var/log/FFE-CMS/
chown www-data.www-data /var/run/FFE-CMS/

# Install PHP stuff
curl -o /var/www/lib/v1.18.1.tar.gz https://github.com/twigphp/Twig/archive/v1.18.1.tar.gz
tar -zxvf /var/www/lib/v1.18.1.tar.gz -C /var/www/lib/
ln -s /var/www/lib/Twig-1.18.1 /var/www/lib/Twig
curl -o /var/www/lib/aws.phar https://github.com/aws/aws-sdk-php/releases/download/3.0.0/aws.phar
# wget https://s3-eu-west-1.amazonaws.com/ffe-static-web/php/PHPExcel_1.8.0.zip -O /var/www/lib/PHPExcel_1.8.0.zip
aws s3 cp s3://ffe-static-web/php/PHPExcel_1.8.0.zip /var/www/lib/PHPExcel_1.8.0.zip
unzip /var/www/lib/PHPExcel_1.8.0.zip -d /var/www/lib/
ln -s /var/www/lib/Classes /var/www/lib/PHPExcel

ln -s /srv/config/ffe/php5/apache2/php.ini /etc/php5/apache2/php.ini
ln -s /srv/config/ffe/php5/mods-available/mongo.ini /etc/php5/apache2/conf.d/20-mongo.ini
ln -s /srv/config/ffe/php5/mods-available/mongo.ini /etc/php5/cli/conf.d/20-mongo.ini

# Fix apache configs.
ln -s /srv/config/ffe/apache2/apache2.conf /etc/apache2/apache2.conf
ln -s /srv/config/ffe/apache2/ports.conf /etc/apache2/ports.conf
ln -s /srv/config/ffe/apache2/sites-enabled/dealer.flyfisheurope.com /etc/apache2/sites-enabled/dealer.flyfisheurope.com
ln -s /srv/config/ffe/apache2/sites-enabled/www.flyfisheurope.com /etc/apache2/sites-enabled/www.flyfisheurope.com
ln -s /srv/config/ffe/apache2/sites-enabled/dev.zu.no /etc/apache2/sites-enabled/dev.zu.no

# Fix varnish config.
ln -s /srv/config/ffe/varnish/default.vcl /etc/varnish/default.vcl
ln -s /srv/config/ffe/etc/default/varnish /etc/default/varnish

# Logs to AWS Cloudwatch
cat > /var/awslogs/etc/awslogs.conf <<'EOF'
[general]
state_file = /var/awslogs/state/agent-state

[/tmp/apilog.log]
datetime_format = %Y-%m-%d %H:%M:%S
file = /var/log/simple-blog/simple-blog-next.telia.no.log
buffer_duration = 5000
log_stream_name = {instance_id}
initial_position = start_of_file
log_group_name = api/apilog.log

[/tmp/request.log]
datetime_format = %Y-%m-%d %H:%M:%S
file = /srv/simple-blog/logs/web-access.log
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
read -r -d '' CRONTAB_LINES <<- EOM
MAILTO=sorenso@gmail.com
0 1 * * * /usr/local/bin/aws s3 sync /var/www/dealer.flyfisheurope.com/images/ s3://ffe-static-web/images/ --exclude "cache/*" >> /home/ubuntu/aws-s3-sync.log
0 2 * * * /usr/local/bin/aws s3 sync /var/www/dealer.flyfisheurope.com/fancyBox/ s3://ffe-static-web/fancyBox/ >> /home/ubuntu/aws-s3-sync.log
0 2 * * * /usr/local/bin/aws s3 sync /var/www/dealer.flyfisheurope.com/img/ s3://ffe-static-web/img/ >> /home/ubuntu/aws-s3-sync.log
0 2 * * * /usr/local/bin/aws s3 sync /var/www/dealer.flyfisheurope.com/jafw/ s3://ffe-static-web/jafw/ >> /home/ubuntu/aws-s3-sync.log
0 2 * * * /usr/local/bin/aws s3 sync /var/www/dealer.flyfisheurope.com/jquery-file-upload/ s3://ffe-static-web/jquery-file-upload/ >> /home/ubuntu/aws-s3-sync.log
0 2 * * * /usr/local/bin/aws s3 sync /var/www/dev.zu.no/sizechart/ s3://ffe-static-web/sizechart/ >> /home/ubuntu/aws-s3-sync.log
0 2 * * * /usr/local/bin/aws s3 sync /var/www/dev.zu.no/test/ s3://ffe-static-web/test/ >> /home/ubuntu/aws-s3-sync.log
0 2 * * * /usr/local/bin/aws s3 cp /var/www/www.flyfisheurope.com/index.html s3://ffe-static-web/index.html >> /home/ubuntu/aws-s3-sync.log
0 2 * * * /usr/local/bin/aws s3 cp /var/www/www.flyfisheurope.com/favicon.ico s3://ffe-static-web/favicon.ico >> /home/ubuntu/aws-s3-sync.log
0 2 * * * /usr/local/bin/aws s3 cp /var/www/dev.zu.no/img.php s3://ffe-static-web/img.php >> /home/ubuntu/aws-s3-sync.log

EOM
(crontab -l; echo "$CRONTAB_LINES" ) | crontab -u ubuntu -
