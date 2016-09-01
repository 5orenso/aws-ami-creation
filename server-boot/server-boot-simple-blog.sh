#!/bin/bash

export LC_ALL=en_US.UTF-8

# Associate IP (data is pushed to this IP from Oracle etc)
ELASTIC_IP=52.17.86.89
INSTANCE_ID=`curl http://169.254.169.254/latest/meta-data/instance-id`
aws ec2 associate-address --instance-id $INSTANCE_ID --public-ip $ELASTIC_IP --allow-reassociation

# ----------------------------------------------------------------
# Get the application you want to run on this server:
mkdir /srv/
cd /srv/
git clone https://github.com/5orenso/simple-blog.git

# Install all packages
cd /srv/simple-blog/
npm install

# Install the application:
chown ubuntu:ubuntu /srv/simple-blog/
chmod 755 /srv/simple-blog/

# Link the content folder
mkdir /srv/simple-blog/content/
chown ubuntu:ubuntu /srv/simple-blog/content/
ln -s /home/ubuntu/Dropbox/websites/next.telia.no /srv/simple-blog/content/.

# Config file
mkdir /srv/config/

cat > /srv/config/simple-blog-next.telia.no.js <<'EOF'
module.exports = {
    version: 1,
    photoPath: '/srv/simple-blog/content/next.telia.no/images/',
    blog: {
        title: 'next.telia.no',
        disqus: 'next-telia-no',
        protocol: 'http',
        domain: 'next.telia.no',
        tags: 'IoT, DataLab, PurplePipe, Identity',
        copyright: 'Copyright 2016 next.telia.no',
        email: 'oistein.sorensen@telia.no',
        searchResults: 'blog posts related to ',
        showListOnIndex: 1,
//        social: {
//            twitter: 'https://twitter.com/sorenso',
//            facebook: 'https://facebook.com/sorenso',
//            googleplus: '',
//            pintrest: '',
//            instagram: 'http://instagram.com/sorenso'
//        },
        staticFilesPath: '/home/ubuntu/html/',
        textFilesPath: '/home/ubuntu/text-files/',
        topImage: false, // Don't use image[0] as top image on site. Use topImage instead.
        simpleHeader: false, // Use simple header instead of top panorama
        //googleAnalytics: 'UA-6268609-3',
        googleTagManager: 'GTM-WZPRG9',
        author: {
            sorenso: {
                image: '/pho/profile/fishOistein.jpg?w=50',
                name: '<a href="https://twitter.com/sorenso">Sorenso</a>',
            }
        },
        rewrites: [
//            { url: '/wip4/.*', target: '/', code: 302 }
        ]
    },
    app: {
        port: 8080
    },
    template: {
        blog: 'template/current/blog.html',
        index: 'template/current/blog.html'
    },
    adapter: {
        current: 'markdown',
        markdown: {
            contentPath: '/srv/simple-blog/content/next.telia.no/articles/',
            photoPath: '/srv/simple-blog/content/next.telia.no/images/',
            maxArticles: 50,
        },
        elasticsearch: {
            server: 'search-tsn-insight-next-boqizt4pqm27qs5fhq5lzqrkvu.eu-west-1.es.amazonaws.com',
            port: 9200,
            index: 'next.telia.no',
            type: 'article',
            multiMatchType: 'most_fields',
            multiMatchTieBreaker: 0.3
        }
    }
};
EOF

# Add config-sitemap-next-telia-no.js
cat > /srv/config/simple-blog-sitemap-next-telia-no.js <<'EOF'
module.exports = {
    version: 1,
    blog: {
        title: 'next.telia.no',
        protocol: 'http',
        domain: 'next.telia.no'
    },
    app: {
        port: 8080
    },
    template: {
        blog: 'template/current/blog.html',
        index: 'template/current/blog.html'
    },
    adapter: {
        current: 'markdown',
        markdown: {
            contentPath: '/srv/simple-blog/content/next.telia.no/articles/',
            photoPath: '/srv/simple-blog/content/next.telia.no/images/',
            maxArticles: 5000,
        },
        elasticsearch: {
            server: 'search-tsn-insight-next-boqizt4pqm27qs5fhq5lzqrkvu.eu-west-1.es.amazonaws.com',
            port: 80,
            index: 'next.telia.no',
            type: 'article'
        }
    }
};
EOF

# Add crontab entries
read -r -d '' CRONTAB_LINES <<- EOM
1,31 * * * *  /usr/local/bin/node /srv/simple-blog/app/sitemap.js -c /srv/config/simple-blog-sitemap-next-telia-no.js > /dev/null 2>&1
EOM
(crontab -l; echo "$CRONTAB_LINES" ) | crontab -u ubuntu -

# Logging folders
mkdir /srv/simple-blog/logs/
chown ubuntu:ubuntu /srv/simple-blog/logs/
chmod u+w /srv/simple-blog/logs/

mkdir /var/log/simple-blog/
chown ubuntu:ubuntu /var/log/simple-blog/
chmod u+w /var/log/simple-blog/

# Pid file
mkdir /var/run/simple-blog/
chown ubuntu:ubuntu /var/run/simple-blog
chmod u+w /var/run/simple-blog

# Startup script
cat > /etc/init/simple-blog-next-telia-no.conf <<'EOF'
# ----------------------------------------------------------------------
# datapiper - instance
#
description     "simple-blog"

start on (virtual-filesystems and net-device-up IFACE=eth0)
stop on runlevel [06]

respawn
respawn limit 10 5    # Die if respawn more than 10 times in 5 sec.

chdir /srv/simple-blog
setuid ubuntu
setgid ubuntu
console log

script
    echo $$ > /var/run/simple-blog/simple-blog-next.telia.no.pid
    exec /usr/local/bin/node /srv/simple-blog/app/server.js -c /srv/config/simple-blog-next.telia.no.js  >> /var/log/simple-blog/simple-blog-next.telia.no.log 2>&1
end script

pre-start script
    # Date format same as (new Date()).toISOString() for consistency
    echo "[`date -u +%Y-%m-%dT%T.%3NZ`] (sys) Starting" >> /var/log/simple-blog/simple-blog-next.telia.no.log
end script

pre-stop script
    rm /var/run/simple-blog/simple-blog-next.telia.no.pid
    echo "[`date -u +%Y-%m-%dT%T.%3NZ`] (sys) Stopping" >> /var/log/simple-blog/simple-blog-next.telia.no.log
end script

#-----[ HOWTO ]--------------------------------------------------
# sudo cp upstart.conf /etc/init/simple-blog.conf
# sudo initctl start simple-blog
# sudo tail -f /var/log/simple-blog/simple-blog-next.telia.no.log
EOF

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

# Run the application:
service simple-blog-next-telia-no start


# Cleanup as the ubuntu user
# service simple-blog-next-telia-no stop
# rm -rf /srv/simple-blog/
# rm /srv/config/simple-blog-next.telia.no.js
# rm -rf /var/log/simple-blog/
# rm -rf /var/run/simple-blog/
# rm /etc/init/simple-blog-next-telia-no.conf