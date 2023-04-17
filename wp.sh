#!/bin/bash

# Input
read -p "Masukkan nama database MySQL: " dbname
read -p "Masukkan nama pengguna MySQL: " dbuser
read -sp "Masukkan kata sandi pengguna MySQL: " dbpass
echo ""
read -p "Masukkan nama situs web: " sitename
read -p "Masukkan alamat email admin site: " adminemail
read -sp "Masukkan kata sandi admin site: " adminpass
echo ""
read -p "Masukkan alamat IP server: " serverip


#update
yum update -y
sudo yum -y install http://rpms.remirepo.net/enterprise/remi-release-7.rpm 
sudo yum -y install epel-release yum-utils
sudo yum-config-manager --enable remi-php56

# Install LAMP stack
yum install -y httpd mariadb-server mariadb php php-mysql

# install wget
yum install wget -y

# Start LAMP services
systemctl enable httpd
systemctl enable mariadb
systemctl start httpd
systemctl start mariadb

# Enable needed ports
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload

# Secure MariaDB Installation
echo "Please configure your MariaDB Root Password:"
mysql_secure_installation

# Set MySQL root password 
mysqladmin -u root password $dbpass

# Create new MySQL database
mysql -u root -p$dbpass -e "CREATE DATABASE $dbname"

# Create new MySQL user and grant privileges to the new database
mysql -u root -p$dbpass -e "CREATE USER '$dbuser'@'localhost' IDENTIFIED BY '$dbpass';"
mysql -u root -p$dbpass -e "GRANT ALL PRIVILEGES ON $dbname.* TO '$dbuser'@'%' IDENTIFIED BY '$dbpass'"

# Flush MySQL privileges
mysql -u root -p$dbpass -e "FLUSH PRIVILEGES"

# Download WordPress package
wget https://wordpress.org/latest.tar.gz
tar -xvf latest.tar.gz
cp -r wordpress/* /var/www/html/

# Change ownership of WordPress files to Apache user
chown -R apache:apache /var/www/html/

# Configure WordPress
cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
sed -i "s/database_name_here/$dbname/g" /var/www/html/wp-config.php
sed -i "s/username_here/$dbuser/g" /var/www/html/wp-config.php
sed -i "s/password_here/$dbpass/g" /var/www/html/wp-config.php

#create folder vhost
mkdir /etc/httpd/sites-available /etc/httpd/sites-enabled

# Create vhost configuration file
echo "
<VirtualHost $serverip:80 *:80>
    ServerAdmin $adminemail
    DocumentRoot /var/www/html
    ServerName $sitename
    ErrorLog /var/log/httpd/$sitename-error.log
    CustomLog /var/log/httpd/$sitename-access.log combined
</VirtualHost>
" > /etc/httpd/sites-available/$sitename.conf

# Enable vhost
ln -s /etc/httpd/sites-available/$sitename.conf /etc/httpd/sites-enabled/$sitename.conf

# Update Apache configuration
echo "IncludeOptional sites-enabled/*.conf" >> /etc/httpd/conf/httpd.conf

# Restart Apache
systemctl restart httpd

echo "Instalasi WordPress telah berhasil."
echo "Anda dapat mengakses situs web di http://$serverip atau http://$sitename"


