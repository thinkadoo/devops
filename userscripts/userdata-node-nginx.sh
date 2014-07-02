#!/bin/bash

## ------ START:	Standard Config Elements ------ ##
export ENV='$NODE_ENV'
export PROJECT_NAME='$PROJECT_NAME'
export SCRIPT_NAME='release.sh'
export S3_DEPLOYMENT_KEY='$ACCESS_KEY'
# Rember that if this contains \ or / you need to escape that with \
export S3_DEPLOYMENT_SECRET='$SECRET_KEY'
export S3_DEPLOYMENT_PASSPHRASE='$DEPLOYMENT_PASSPHRASE'
export S3_BUCKET_NAME='$BUCKET_NAME'
## ------ END:		Standard Config Elements ------ ##


## ------ START:	Standard Node AMI UserData Script ------ ##
sudo npm install -g grunt-cli
sudo npm install -g bower
sudo npm install -g cleverstack-cli

sed -i -r "s/(access_key *= *).*/\1$S3_DEPLOYMENT_KEY/" /home/ubuntu/.s3cfg
sed -i -r "s/(secret_key *= *).*/\1$S3_DEPLOYMENT_SECRET/" /home/ubuntu/.s3cfg
sed -i -r "s/(gpg_passphrase *= *).*/\1$S3_DEPLOYMENT_PASSPHRASE/" /home/ubuntu/.s3cfg

S3_APP_SCRIPT_PATH="s3://ite-devops/$ENV/$PROJECT_NAME/$SCRIPT_NAME"

# Store the launch script MD5 hash
s3cmd -f --config /home/ubuntu/.s3cfg ls $S3_APP_SCRIPT_PATH | md5sum | awk '{ print $1 }' > /tmp/releaseCurrentMd5.txt
chown ubuntu:ubuntu /tmp/releaseCurrentMd5.txt

# Fetch a copy of the launch script
s3cmd -f --config /home/ubuntu/.s3cfg get $S3_APP_SCRIPT_PATH /opt/$SCRIPT_NAME

# Ensure permissions of launch script are good
chmod o+x /opt/$SCRIPT_NAME
chown ubuntu:ubuntu /opt/$SCRIPT_NAME
mkdir /opt
chmod 777 /opt
chown ubuntu:ubuntu /opt

# Ubuntu cannot bind port 80, so we do this here in userdata as root so it redirects 80 to 8080 (where node is running)
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080

## Install and configure NGINX (this serves the frontend from S3 and forwards+rewrites anything /api/* to localhost:8080/*)
sudo apt-get -y install nginx
sudo cat << 'EOF' > /etc/nginx/nginx.conf

user www-data;
worker_processes 4;
pid /var/run/nginx.pid;
worker_rlimit_nofile 8192;

events {
        worker_connections 2048;
        use epoll;
        multi_accept on;
}

http {
        include /etc/nginx/mime.types;
        default_type application/octet-stream;

        log_format main '$remote_addr - $remote_user [$time_local] $status '
                        '"$request" $body_bytes_sent "$http_referer" '
                        '"$http_user_agent" "$http_x_forwarded_for"';
        log_format  byte '$bytes_sent';
        access_log /var/log/nginx/access.log main;

        client_header_timeout 3m;
        client_body_timeout 3m;
        send_timeout 3m;

        server_tokens off;

        client_header_buffer_size 1k;
        large_client_header_buffers 4 4k;
        server_names_hash_bucket_size 128;

        gzip on;
        gzip_min_length 1100;
        gzip_buffers 4 8k;
        gzip_types text/plain text/css application/x-javascript text/xml application/xml text/javascript;

        output_buffers 1 32k;
        postpone_output 1460;

        sendfile on;
        tcp_nopush on;
        tcp_nodelay on;
        directio 4m;

        open_file_cache max=1000 inactive=20s;
        open_file_cache_valid 30s;
        open_file_cache_min_uses 2;
        open_file_cache_errors on;

        server {
                listen 80;
                access_log /var/log/nginx/dev.log main;

                location /api/ {

                        rewrite /api/(.*) /$1  break;

                        proxy_pass         http://127.0.0.1:8080/;
                        proxy_redirect     off;
                        proxy_set_header   Host             $host;
                        proxy_set_header   X-Real-IP        $remote_addr;
                        proxy_set_header   X-Forwarded-For  $proxy_add_x_forwarded_for;
                        proxy_set_header   X-NginX-Proxy    true;
                        proxy_connect_timeout      90;
                        proxy_send_timeout         90;
                        proxy_read_timeout         90;
                        proxy_buffer_size          4k;
                        proxy_buffers              4 32k;
                        proxy_busy_buffers_size    64k;
                        proxy_temp_file_write_size 64k;

                        # websockets:
                        proxy_http_version 1.1;
                        proxy_set_header Upgrade $http_upgrade;
                        proxy_set_header Connection "upgrade";

                        client_max_body_size       30m;
                        client_body_buffer_size    128k;
                }

                location / {

                        proxy_pass         http://ai-app-dev.s3-website-us-east-1.amazonaws.com/;
                        proxy_redirect     off;
                        proxy_set_header   Host             "$S3_BUCKET_NAME";
                        proxy_set_header   X-Real-IP        $remote_addr;
                        proxy_set_header   X-Forwarded-For  $proxy_add_x_forwarded_for;
                        proxy_set_header   X-NginX-Proxy    true;
                        proxy_connect_timeout      90;
                        proxy_send_timeout         90;
                        proxy_read_timeout         90;
                        proxy_buffer_size          4k;
                        proxy_buffers              4 32k;
                        proxy_busy_buffers_size    64k;
                        proxy_temp_file_write_size 64k;

                        client_max_body_size       30m;
                        client_body_buffer_size    128k;

                }

        }
}

EOF

sudo /etc/init.d/nginx restart

# Run the script for the first time
sudo -u ubuntu bash /opt/$SCRIPT_NAME >> /tmp/deploy.log
sudo chown ubuntu:ubuntu /tmp/deploy.log
## ------ END:		Standard Node AMI UserData Script ------ ##