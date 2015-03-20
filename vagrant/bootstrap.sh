#!/bin/bash

function coloredEcho(){
    local exp=$1;
    local color=$2;
    if ! [[ $color =~ '^[0-9]$' ]] ; then
       case $(echo $color | tr '[:upper:]' '[:lower:]') in
        black) color=0 ;;
        red) color=1 ;;
        green) color=2 ;;
        yellow) color=3 ;;
        blue) color=4 ;;
        magenta) color=5 ;;
        cyan) color=6 ;;
        white|*) color=7 ;; # white or invalid color
       esac
    fi
    tput setaf $color;
    echo $exp;
    tput sgr0;
}

function writeOut(){
    local str=$1;
    local color=$2;
    coloredEcho "--------------------------------" yellow
    coloredEcho "| $str" $color
    coloredEcho "--------------------------------" yellow
}

#MYSQL Global parameters
MYSQL_ROOT_USERNAME=root
MYSQL_ROOT_PASS=1234
MYSQL_BIND_ADDR=0.0.0.0

#Mysql a2billing parameters
MYSQL_A2B_HOST=127.0.0.1
MYSQL_A2B_DB=mya2billing
MYSQL_A2B_USER=a2billinguser
MYSQL_A2B_PASS=a2billing

#Mysql asterisk CDRDB parameters
MYSQL_CDRDB_HOST=127.0.0.1
MYSQL_CDRDB_DB=asteriskcdrdb
MYSQL_CDRDB_USER=asterisk
MYSQL_CDRDB_PASS=asterisk

#A2Billing
A2B_ROOT_DIR=/vagrant/a2billing

cat <<EOF >>/etc/environment
LANGUAGE=en_US.UTF-8
LC_ALL=en_US.UTF-8
LANG=en_US.UTF-8
LC_TYPE=en_US.UTF-8
EOF

locale-gen en_US en_US.UTF-8 && sudo dpkg-reconfigure locales

writeOut "Provisioning virtual machine..."
writeOut "Updating to closest mirrors..."
sed -i.bak -r "s/^(deb|deb-src) (http[^ ]+) (.*)$/\1 mirror\:\/\/mirrors\.ubuntu\.com\/mirrors\.txt \3/" /etc/apt/sources.list
sudo apt-get update

writeOut "Installing Git and wget"
sudo apt-get install zsh git wget memcached mc mcedit -y

writeOut "Switching to zsh"
sudo chsh -s /bin/zsh vagrant

writeOut "Installing Nginx"
sudo apt-get install nginx -y

writeOut "Installing PHP"
sudo apt-get install php5-common php5-dev php5-cli php5-fpm -y
sed -i "s/user =.*/user = vagrant/" /etc/php5/fpm/pool.d/www.conf
sed -i "s/[;]cgi\.fix_pathinfo=.*/cgi\.fix_pathinfo\=1/" /etc/php5/fpm/php.ini

writeOut "Installing PHP extensions"
apt-get install curl php5-mysql php5-imagick php5-intl \
    php5-apcu php5-memcache php5-memcached php5-xdebug \
    php5-redis php5-curl php5-gd \
    php5-mcrypt php5-mysql php-gettext php-soap -y

sudo php5enmod mcrypt
sudo service php5-fpm restart

writeOut "Setting up Xdebug"
cat <<EOF >>/etc/php5/fpm/conf.d/20-xdebug.ini
xdebug.default_enable = 1
xdebug.idekey = "PHPSTORM"
xdebug.remote_enable = 1
xdebug.remote_autostart = 0
xdebug.remote_port = 9000
xdebug.remote_handler=dbgp
xdebug.remote_log="/var/log/xdebug/xdebug.log"
xdebug.remote_host=10.0.2.2 ; IDE-Environments IP, from vagrant box.
EOF

writeOut "Installing Composer for PHP"
mkdir -p /home/vagrant/bin && cd /home/vagrant/bin && curl -sS https://getcomposer.org/installer | php
ln -s /home/vagrant/bin/composer.phar /usr/local/bin/composer

writeOut "Installing MySQL with root password: $MYSQL_ROOT_PASS"
apt-get install debconf-utils -y
debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASS"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASS"
sudo apt-get install mysql-server -y

writeOut "Creating databases and privileges"
mysql -p$MYSQL_ROOT_PASS mysql <<EOF
GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_ROOT_USERNAME'@'%' IDENTIFIED BY '$MYSQL_ROOT_PASS' WITH GRANT OPTION;
CREATE DATABASE IF NOT EXISTS $MYSQL_A2B_DB;
CREATE DATABASE IF NOT EXISTS $MYSQL_CDRDB_DB;
GRANT ALL PRIVILEGES ON $MYSQL_A2B_DB.* TO '$MYSQL_A2B_USER'@'%' IDENTIFIED BY '$MYSQL_A2B_PASS' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON $MYSQL_CDRDB_DB.* TO '$MYSQL_CDRDB_USER'@'%' IDENTIFIED BY '$MYSQL_CDRDB_PASS' WITH GRANT OPTION;
flush privileges;
EOF
sed -r -i "s/bind-address.*/bind-address = $MYSQL_BIND_ADDR/" /etc/mysql/my.cnf
service mysql restart

writeOut "Setting up Nginx"
rm -rf /etc/nginx/sites-enabled/*
cp -r /vagrant/vagrant/config/etc/nginx/* /etc/nginx/
service nginx restart

writeOut "Installing asterisk"
sudo apt-get install asterisk -y

writeOut "Cloning a2billing master"
sudo rm -rf $A2B_ROOT_DIR/* $A2B_ROOT_DIR/.*
git clone https://github.com/Star2Billing/a2billing.git $A2B_ROOT_DIR/ && rm -rf $A2B_ROOT_DIR/.git

writeOut "Setting up a2billing"

$A2B_ROOT_DIR/DataBase/mysql-5.x/install-db.sh << EOF
$MYSQL_A2B_DB
$MYSQL_A2B_HOST
$MYSQL_A2B_USER
$MYSQL_A2B_PASS
EOF

sudo ln -s $A2B_ROOT_DIR/a2billing.conf /etc/
sed -i.bak -r "s/hostname =.*$/hostname = $MYSQL_A2B_HOST/g" $A2B_ROOT_DIR/a2billing.conf
sed -i.bak -r "s/port =.*$/port = 3306/g" $A2B_ROOT_DIR/a2billing.conf
sed -i.bak -r "s/user =.*$/user = $MYSQL_A2B_USER/g" $A2B_ROOT_DIR/a2billing.conf
sed -i.bak -r "s/password =.*$/password = $MYSQL_A2B_PASS/g" $A2B_ROOT_DIR/a2billing.conf
sed -i.bak -r "s/dbname =.*$/dbname = $MYSQL_A2B_DB/g" $A2B_ROOT_DIR/a2billing.conf

writeOut "Copy asterisk config files to etc"

cp -rf /etc/asterisk/ /etc/asterisk.old/ \
 && rm -rf /etc/asterisk/* \
 && cp -r /vagrant/vagrant/config/etc/asterisk/* /etc/asterisk/

sed -i "s/%%MYSQL_CDRDB_USER%%/$MYSQL_CDRDB_USER/g" /etc/asterisk/res_odbc.conf
sed -i "s/%%MYSQL_CDRDB_PASS%%/$MYSQL_CDRDB_PASS/g" /etc/asterisk/res_odbc.conf
sed -i "s/%%MYSQL_A2B_USER%%/$MYSQL_A2B_USER/g" /etc/asterisk/res_odbc.conf
sed -i "s/%%MYSQL_A2B_PASS%%/$MYSQL_A2B_PASS/g" /etc/asterisk/res_odbc.conf

chmod -R 777 /etc/asterisk

apt-get install libmyodbc unixodbc-bin -y
sudo apt-get install unixODBC unixODBC-dev -y

cp -f /vagrant/vagrant/config/etc/odbc.ini /etc/
cp -f /vagrant/vagrant/config/etc/odbcinst.ini /etc/

sed -i "s/%%MYSQL_CDRDB_HOST%%/$MYSQL_CDRDB_HOST/g" /etc/odbc.ini
sed -i "s/%%MYSQL_CDRDB_DB%%/$MYSQL_CDRDB_DB/g" /etc/odbc.ini
sed -i "s/%%MYSQL_CDRDB_USER%%/$MYSQL_CDRDB_USER/g" /etc/odbc.ini
sed -i "s/%%MYSQL_CDRDB_PASS%%/$MYSQL_CDRDB_PASS/g" /etc/odbc.ini

sed -i "s/%%MYSQL_A2B_HOST%%/$MYSQL_A2B_HOST/g" /etc/odbc.ini
sed -i "s/%%MYSQL_A2B_DB%%/$MYSQL_A2B_DB/g" /etc/odbc.ini
sed -i "s/%%MYSQL_A2B_USER%%/$MYSQL_A2B_USER/g" /etc/odbc.ini
sed -i "s/%%MYSQL_A2B_PASS%%/$MYSQL_A2B_PASS/g" /etc/odbc.ini

odbcinst -i -d -f /etc/odbcinst.ini
odbcinst -i -s -l -f /etc/odbc.ini
odbcinst -s -q

isql -v MySQL-cdrdb <<EOF
quit
EOF
isql -v MySQL-asterisk <<EOF
quit
EOF

chown -Rf www-data /etc/asterisk/additional_a2billing_iax.conf

cd  $A2B_ROOT_DIR/addons/sounds/ && ./install_a2b_sounds.sh && chown -R asterisk:asterisk /usr/share/asterisk/sounds/

mkdir -p /usr/share/asterisk/agi-bin
chown asterisk:asterisk /usr/share/asterisk/agi-bin

ln -s $A2B_ROOT_DIR/AGI/a2billing.php /usr/share/asterisk/agi-bin/a2billing.php
ln -s $A2B_ROOT_DIR/AGI/a2billing_monitoring.php /usr/share/asterisk/agi-bin/a2billing_monitoring.php
ln -s $A2B_ROOT_DIR/AGI/lib /usr/share/asterisk/agi-bin/lib
chmod +x /usr/share/asterisk/agi-bin/a2billing.php
chmod +x /usr/share/asterisk/agi-bin/a2billing_monitoring.php
ln -s /usr/share/asterisk/agi-bin/ /var/lib/asterisk/

chmod 755 $A2B_ROOT_DIR/admin/templates_c
chmod 755 $A2B_ROOT_DIR/customer/templates_c
chmod 755 $A2B_ROOT_DIR/agent/templates_c
chown -Rf www-data:www-data $A2B_ROOT_DIR/admin/templates_c
chown -Rf www-data:www-data $A2B_ROOT_DIR/customer/templates_c
chown -Rf www-data:www-data $A2B_ROOT_DIR/agent/templates_c

writeOut "Installing asterisk realtime"

mysql -u$MYSQL_CDRDB_USER -p$MYSQL_CDRDB_PASS $MYSQL_CDRDB_DB <<EOF
CREATE TABLE cdr ( \
  calldate datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  clid varchar(80) NOT NULL DEFAULT '',
  src varchar(80) NOT NULL DEFAULT '',
  dst varchar(80) NOT NULL DEFAULT '',
  dcontext varchar(80) NOT NULL DEFAULT '',
  channel varchar(80) NOT NULL DEFAULT '',
  dstchannel varchar(80) NOT NULL DEFAULT '',
  lastapp varchar(80) NOT NULL DEFAULT '',
  lastdata varchar(80) NOT NULL DEFAULT '',
  duration int(11) NOT NULL DEFAULT '0',
  billsec int(11) NOT NULL DEFAULT '0',
  disposition varchar(45) NOT NULL DEFAULT '',
  amaflags int(11) NOT NULL DEFAULT '0',
  accountcode varchar(20) NOT NULL DEFAULT '',
  uniqueid varchar(32) NOT NULL DEFAULT '',
  userfield varchar(255) NOT NULL DEFAULT '',
  did varchar(50) NOT NULL DEFAULT '',
  recordingfile varchar(255) NOT NULL DEFAULT '',
  cnum varchar(40) NOT NULL DEFAULT '',
  cnam varchar(40) NOT NULL DEFAULT '',
  outbound_cnum varchar(40) NOT NULL DEFAULT '',
  outbound_cnam varchar(40) NOT NULL DEFAULT '',
  dst_cnam varchar(40) NOT NULL DEFAULT '',
  KEY calldate (calldate),
  KEY dst (dst),
  KEY accountcode (accountcode)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
EOF

service asterisk stop
service asterisk start

asterisk -rx "core show config mappings"
