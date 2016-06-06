#!/bin/bash

export LC_ALL=en_US.UTF-8

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

service zu start


# --> FFE-CMS
# PHP
chown www-data.www-data /var/www/
chmod 755 /var/www/
chmod g+s /var/www/

mkdir /var/www/lib/


# www.flyfisheurope.com
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
/usr/bin/aws s3 sync s3://ffe-static-web/jquery-file-upload/ /var/www/www.flyfisheurope.com/jquery-file-upload/ --region eu-west-1
/usr/bin/aws s3 sync s3://ffe-static-web/sizechart/ /var/www/www.flyfisheurope.com/sizechart/ --region eu-west-1
/usr/bin/aws s3 sync s3://ffe-static-web/test/ /var/www/www.flyfisheurope.com/test/ --region eu-west-1
/usr/bin/aws s3 cp s3://ffe-static-web/index.html /var/www/www.flyfisheurope.com/index.html --region eu-west-1
/usr/bin/aws s3 cp s3://ffe-static-web/index_dealer.html /var/www/www.flyfisheurope.com/index_dealer.html --region eu-west-1
/usr/bin/aws s3 cp s3://ffe-static-web/favicon.ico /var/www/www.flyfisheurope.com/favicon.ico --region eu-west-1
/usr/bin/aws s3 cp s3://ffe-static-web/img.php /var/www/www.flyfisheurope.com/img.php --region eu-west-1


# dev.zu.no
git clone $GIT_REPO_FFE_CMS /var/www/dev.zu.no/zu/
ln -s /var/www/www.flyfisheurope.com/images /var/www/dev.zu.no/.
ln -s /srv/config/ffe/FFE-CMS/dev.zu.no/main.ini /var/www/dev.zu.no/zu/config/main.ini
ln -s /var/www/dev.zu.no/zu/view/consumer_web/css /var/www/dev.zu.no/css
ln -s /var/www/dev.zu.no/zu/view/consumer_web/js /var/www/dev.zu.no/js
ln -s /var/www/dev.zu.no/zu/view/consumer_web/posters /var/www/dev.zu.no/posters
ln -s /var/www/dev.zu.no/zu/view/consumer_web/img /var/www/dev.zu.no/imgs
ln -s /var/www/dev.zu.no/zu/qrcodes /var/www/dev.zu.no/qrcodes

# dealer.flyfisheurope.com
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
ln -s /var/www/dealer.flyfisheurope.com/zu/qrcodes /var/www/dealer.flyfisheurope.com/qrcodes

# Chown
chown -R www-data.www-data /var/www/

mkdir /var/log/FFE-CMS
mkdir /var/run/FFE-CMS

chown www-data.www-data /var/log/FFE-CMS/
chown www-data.www-data /var/run/FFE-CMS/

# Install PHP stuff
# curl -o /var/www/lib/v1.24.1.tar.gz https://codeload.github.com/twigphp/Twig/tar.gz/v1.24.1
aws s3 cp s3://ffe-static-web/php/v1.24.1.tar.gz /var/www/lib/v1.24.1.tar.gz
tar -zxvf /var/www/lib/v1.24.1.tar.gz -C /var/www/lib/
ln -s /var/www/lib/Twig-1.24.1 /var/www/lib/Twig
# curl -o /var/www/lib/aws.phar https://github.com/aws/aws-sdk-php/releases/download/3.0.0/aws.phar
aws s3 cp s3://ffe-static-web/php/aws.phar /var/www/lib/aws.phar --region eu-west-1
# wget https://s3-eu-west-1.amazonaws.com/ffe-static-web/php/PHPExcel_1.8.0.zip -O /var/www/lib/PHPExcel_1.8.0.zip
aws s3 cp s3://ffe-static-web/php/PHPExcel_1.8.0.zip /var/www/lib/PHPExcel_1.8.0.zip --region eu-west-1
unzip /var/www/lib/PHPExcel_1.8.0.zip -d /var/www/lib/
ln -s /var/www/lib/Classes /var/www/lib/PHPExcel

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
ln -s /srv/config/ffe/etc/fail2ban/jail.conf /etc/fail2ban/.

# Fix logrotate config
ln -s /srv/config/ffe/etc/logrotate.d/apache2 /etc/logrotate.d/.
ln -s /srv/config/ffe/etc/logrotate.d/fail2ban /etc/logrotate.d/.
ln -s /srv/config/ffe/etc/logrotate.d/zu /etc/logrotate.d/.
ln -s /srv/config/ffe/etc/logrotate.d/mail /etc/logrotate.d/.
ln -s /srv/config/ffe/etc/logrotate.d/syslog /etc/logrotate.d/.

# Fix postfix config. Sending email via sendgrid.
mv /etc/postfix/main.cf /etc/postfix/main.cf.old
ln -s /srv/config/ffe/etc/postfix/main.cf /etc/postfix/main.cf
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
read -r -d '' CRONTAB_LINES <<- EOM
MAILTO=sorenso@gmail.com
0 1 * * *  /usr/bin/aws s3 sync /var/www/www.flyfisheurope.com/images/             s3://ffe-static-web/images/ --exclude "cache/*" --region eu-west-1 >> /home/ubuntu/aws-s3-sync.log
10 1 * * * /usr/bin/aws s3 sync /var/www/www.flyfisheurope.com/fancyBox/           s3://ffe-static-web/fancyBox/ --region eu-west-1 >> /home/ubuntu/aws-s3-sync.log
20 1 * * * /usr/bin/aws s3 sync /var/www/www.flyfisheurope.com/img/                s3://ffe-static-web/img/ --region eu-west-1 >> /home/ubuntu/aws-s3-sync.log
30 1 * * * /usr/bin/aws s3 sync /var/www/www.flyfisheurope.com/jafw/               s3://ffe-static-web/jafw/ --region eu-west-1 >> /home/ubuntu/aws-s3-sync.log
40 1 * * * /usr/bin/aws s3 sync /var/www/www.flyfisheurope.com/jquery-file-upload/ s3://ffe-static-web/jquery-file-upload/ --region eu-west-1 >> /home/ubuntu/aws-s3-sync.log
50 1 * * * /usr/bin/aws s3 sync /var/www/www.flyfisheurope.com/sizechart/          s3://ffe-static-web/sizechart/ --region eu-west-1 >> /home/ubuntu/aws-s3-sync.log
10 2 * * * /usr/bin/aws s3 sync /var/www/www.flyfisheurope.com/test/               s3://ffe-static-web/test/ --region eu-west-1 >> /home/ubuntu/aws-s3-sync.log
20 2 * * * /usr/bin/aws s3 cp   /var/www/www.flyfisheurope.com/index.html          s3://ffe-static-web/index.html --region eu-west-1 >> /home/ubuntu/aws-s3-sync.log
30 2 * * * /usr/bin/aws s3 cp   /var/www/www.flyfisheurope.com/favicon.ico         s3://ffe-static-web/favicon.ico --region eu-west-1 >> /home/ubuntu/aws-s3-sync.log
40 2 * * * /usr/bin/aws s3 cp   /var/www/www.flyfisheurope.com/img.php             s3://ffe-static-web/img.php --region eu-west-1 >> /home/ubuntu/aws-s3-sync.log

EOM

(crontab -l; echo "$CRONTAB_LINES" ) | crontab -u ubuntu -
