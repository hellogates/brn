#!/bin/bash

echo "Let's create a new admin user for system and Wordpress, shall we?"

echo "Please, enter the name of your new user:"

read uid

useradd -m  $uid

echo "$uid  ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers

echo "Please, enter the domain name for this WP site(WITHOUT www or http:// at the beginning):"

read domain

echo "Please, enter the title of your site:"

read title

echo "Enter the MySQL root passowrd. Please, make sure to put up a strong password to prevent getting hacked:"

read mpass

echo "Enter the WP DB name:"

read dbn

echo "Enter the Wordpress admin email for $uid:"

read email

echo "Enter the password for Wordpress admin  $uid:"

read adminpass

sudo -u $uid bash <<EOF


##################################
#installing necessary dependencies
##################################
sudo apt-get update

sudo apt-get install  -y nginx php-fpm php-mysql  php-curl php-gd php-mbstring php-mcrypt php-xml php-xmlrpc 

sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password $mpass'

sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password $mpass'

sudo apt-get -y install mysql-server




sudo wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar

sudo chmod +x wp-cli.phar

sudo mv wp-cli.phar /usr/local/bin/wp
EOF

sudo systemctl restart php7.0-fpm

##############################
##############################



sudo systemctl reload nginx

nginx -t

sed -i 's/; max_input_vars\s*=.*/max_input_vars=5000/g' /etc/php/7.0/fpm/php.ini
sed -i 's/; max_input_vars\s*=.*/max_input_vars=5000/g' /etc/php/7.0/cli/php.ini
sudo systemctl restart php7.0-fpm


sudo -u $uid bash <<EOF

sudo chown -R $uid:www-data /var/www/html
sudo chmod -R 770 /var/www/html/ 

wp core download   --locale=pt_BR  --path=/var/www/html

wp config create --dbhost=localhost --dbuser=root --dbname=$dbn --dbpass=$mpass --locale=pt_BR --path=/var/www/html

echo  "define( 'WP_MEMORY_LIMIT', '256M' );" >> /var/www/html/wp-config.php


wp db create --path=/var/www/html --url=$domain

wp core install --path=/var/www/html --url=$domain --title='$title' --admin_user=$uid --admin_email=$email --admin_password=$adminpass

wp plugin install amp  --activate --path=/var/www/html

wp plugin install  contact-form-7 --activate --path=/var/www/html

wp plugin install  wpcf7-redirect --activate --path=/var/www/html

wp plugin install  easy-wp-smtp   --activate --path=/var/www/html

wp plugin install   google-tag-manager    --activate --path=/var/www/html

wp plugin install  google-website-optimizer-for-wordpress   --activate --path=/var/www/html

wp plugin install contact-form-cfdb7  --activate --path=/var/www/html

wp plugin install  wordpress-seo  --activate --path=/var/www/html

wp plugin install google-sitemap-generator --activate --path=/var/www/html

wp plugin install facebook-conversion-pixel  --activate --path=/var/www/html

wp plugin install  loco-translate --activate --path=/var/www/html

wp plugin install w3-total-cache --activate --path=/var/www/html

wp plugin install woocommerce  --activate --path=/var/www/html

wp plugin install wordfence --activate --path=/var/www/html

wp theme install https://github.com/hellogates/breno/raw/master/uncode.zip --activate --path=/var/www/html

wp plugin install https://github.com/hellogates/breno/raw/master/plugins/layerslider-6.7.6.zip --activate --path=/var/www/html

wp plugin install  https://github.com/hellogates/breno/raw/master/plugins/slider-revolution-5.4.8.zip   --activate --path=/var/www/html
EOF
sudo chown -R www-data:www-data /var/www/html/
sudo chmod -R 0770 /var/www/html/


###########################################
###########################################
sudo add-apt-repository ppa:certbot/certbot
sudo apt-get update -y
sudo apt-get install certbot  -y
service nginx stop
certbot certonly --standalone --agree-tos -m $email --preferred-challenges http  -d  $domain -d www.$domain
service nginx start



###########################################
###########################################
cat > /etc/nginx/sites-available/default << EOF

server {

     listen 80 default_server;
     
    server_name $domain www.$domain;
    
	
     root /var/www/html;

     index index.php index.html index.htm index.nginx-debian.html;

EOF

cat >> /etc/nginx/sites-available/default << 'EOF'
    

    location / {
    #try_files $uri $uri/ =404;
    try_files $uri $uri/ /index.php$is_args$args;
    location = /favicon.ico { log_not_found off; access_log off; }
    location = /robots.txt { log_not_found off; access_log off; allow all; }
    location ~* \.(css|gif|ico|jpeg|jpg|js|png)$ {
        expires max;
        log_not_found off;
    }

      location ~ \.php$ {
               include snippets/fastcgi-php.conf;
        #
        #       # With php7.0-cgi alone:
        #       fastcgi_pass 127.0.0.1:9000;
        #       # With php7.0-fpm:
               fastcgi_pass unix:/run/php/php7.0-fpm.sock;
        }

    }
}

EOF

cat >> /etc/nginx/sites-available/default << EOF

server {
    
     root /var/www/html;

     index index.php index.html index.htm index.nginx-debian.html;


     server_name $domain www.$domain;


    listen [::]:443 ssl ipv6only=on; 
    listen 443 ssl; 
    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem; 
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem; 
    #include /etc/letsencrypt/options-ssl-nginx.conf; 
    #ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; 


    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;


    # modern configuration. tweak to your needs.
    ssl_protocols TLSv1.2;
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256';
    ssl_prefer_server_ciphers on;

    # HSTS (ngx_http_headers_module is required) (15768000 seconds = 6 months)
    add_header Strict-Transport-Security max-age=15768000;

    # OCSP Stapling ---
    # fetch OCSP records from URL in ssl_certificate and cache them
    ssl_stapling on;
    ssl_stapling_verify on;

    ## verify chain of trust of OCSP response using Root CA and Intermediate certs
    ssl_trusted_certificate /etc/letsencrypt/live/$domain/chain.pem;

   resolver 8.8.8.8;
 

EOF


cat >> /etc/nginx/sites-available/default << 'EOF'
    

    location / {
    #try_files $uri $uri/ =404;
    try_files $uri $uri/ /index.php$is_args$args;
    location = /favicon.ico { log_not_found off; access_log off; }
    location = /robots.txt { log_not_found off; access_log off; allow all; }
    location ~* \.(css|gif|ico|jpeg|jpg|js|png)$ {
        expires max;
        log_not_found off;
    }

      location ~ \.php$ {
               include snippets/fastcgi-php.conf;
        #
        #       # With php7.0-cgi alone:
        #       fastcgi_pass 127.0.0.1:9000;
        #       # With php7.0-fpm:
               fastcgi_pass unix:/run/php/php7.0-fpm.sock;
        }

    }
}

EOF
sed -i '7i\	return 301 https://$server_name$request_uri;' /etc/nginx/sites-available/default


###############################

sudo systemctl reload nginx
sudo systemctl restart php7.0-fpm

nginx -t

