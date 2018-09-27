#!/bin/bash
set -e -x

INSTANCE_NAME='ffe-www-php-node'

# Function to get the next number.
# $* input
# Example: echo 1 | get_next_num
get_next_num() {
    re='^[0-9]+$'
    read num
    if ! [[ $num =~ $re ]] ; then
       echo 1
    else
       echo $((num+1))
    fi
}

# Get name of new AMI image based on existing images with similar base name.
# $1 = base name
get_new_image_name() {
    IMAGE_STAMP=`date +%Y-%m-%d`
    IMAGE_BASE_NAME=$1-${IMAGE_STAMP}
    IMAGE_NEXT_ID=$(aws ec2 describe-images --region eu-west-1 --owners self --filters "Name=name,Values=${IMAGE_BASE_NAME}*" \
        | jq -r '.Images[].Name' \
        | cut -d'_' -f2 \
        | get_next_num)

    echo ${IMAGE_BASE_NAME}_${IMAGE_NEXT_ID}
}

get_ec2_instance_id() {
    echo `curl http://169.254.169.254/latest/meta-data/instance-id`
}

DEBIAN_FRONTEND=noninteractive
EC2_INSTANCE_ID=`get_ec2_instance_id`

apt-get update

# AWS tools and other software
debconf-set-selections <<< "postfix postfix/mailname string www.flyfisheurope.com"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
apt-get install postfix --yes

apt-get install jq awscli mailutils git make g++ dstat ncftp fail2ban logwatch zip unzip imagemagick imagemagick-common apache2 libapache2-mod-php5 varnish --yes
apt-get install php5 php5-curl php5-dev php5-cli php-pear php5-imagick php5-gd --yes

# Tag instance
aws ec2 create-tags --resources $EC2_INSTANCE_ID --tags Key=Name,Value=ami-creator-$INSTANCE_NAME --region eu-west-1

a2enmod headers
a2enmod expires
a2enmod rewrite

pear config-set auto_discover 1
pear install Mail
pecl install mongo


sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
NODE_VERSION="6.1.0"
sudo curl -o /usr/local/node-v$NODE_VERSION-linux-x64.tar.xz https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz
cd /usr/local && sudo tar xf /usr/local/node-v$NODE_VERSION-linux-x64.tar.xz
sudo ln -s /usr/local/node-v$NODE_VERSION-linux-x64/bin/node /usr/local/bin/node
sudo ln -s /usr/local/node-v$NODE_VERSION-linux-x64/bin/npm /usr/local/bin/npm

# Install global modules needed
npm install csv@0.3.7 -g
npm install optimist -g
npm install request -g
npm install crypto -g
npm install http-get -g
npm install xml2js -g

# Copy images from S3. It takes forever and should be done when we build the image.
mkdir -p /var/www/www.flyfisheurope.com/images/cache/
/usr/bin/aws s3 sync s3://ffe-static-web/images/ /var/www/www.flyfisheurope.com/images/ --region eu-west-1

# Install PHP stuff
# Make directory
mkdir /var/www/lib/
# Copy and unzip files.
aws s3 cp s3://ffe-static-web/php/v1.24.1.tar.gz /var/www/lib/v1.24.1.tar.gz --region eu-west-1
tar -zxvf /var/www/lib/v1.24.1.tar.gz -C /var/www/lib/
ln -s /var/www/lib/Twig-1.24.1 /var/www/lib/Twig
aws s3 cp s3://ffe-static-web/php/aws.phar /var/www/lib/aws.phar --region eu-west-1
aws s3 cp s3://ffe-static-web/php/PHPExcel_1.8.0.zip /var/www/lib/PHPExcel_1.8.0.zip --region eu-west-1
unzip /var/www/lib/PHPExcel_1.8.0.zip -d /var/www/lib/
ln -s /var/www/lib/Classes/PHPExcel /var/www/lib/PHPExcel
aws s3 cp s3://ffe-static-web/php/aws-autoloader.php /var/www/lib/aws-autoloader.php --region eu-west-1
mkdir  /var/www/lib/Aws/
aws s3 sync s3://ffe-static-web/php/Aws/ /var/www/lib/Aws/ --region eu-west-1
mkdir /var/www/lib/Guzzle/
aws s3 sync s3://ffe-static-web/php/Guzzle/ /var/www/lib/Guzzle/ --region eu-west-1
mkdir /var/www/lib/Symfony/
aws s3 sync s3://ffe-static-web/php/Symfony/ /var/www/lib/Symfony/ --region eu-west-1
aws s3 cp s3://ffe-static-web/php/phpqrcode-2010100721_1.1.4.zip /var/www/lib/phpqrcode-2010100721_1.1.4.zip --region eu-west-1
unzip -d /var/www/lib/ /var/www/lib/phpqrcode-2010100721_1.1.4.zip
# Change owner
chown -R www-data.www-data /var/www/

# Datadog
#DD_API_KEY=xxxxxyyyyzzzzz bash -c "$(curl -L https://raw.githubusercontent.com/DataDog/dd-agent/master/packaging/datadog-agent/source/install_agent.sh)"

# Cloudwatch logs
curl https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py -O
cat > /tmp/awslogs.conf <<'EOF'
[general]
state_file = /var/awslogs/state/agent-state
EOF
python3 ./awslogs-agent-setup.py -n --region eu-west-1 -c /tmp/awslogs.conf

IMAGE_NAME=`get_new_image_name ${INSTANCE_NAME}-ami`
aws ec2 create-image --instance-id $EC2_INSTANCE_ID --name $IMAGE_NAME --region eu-west-1
