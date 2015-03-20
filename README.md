vagrant-a2billing
==================

You can set up a full working A2Billing with Asterisk Realtime functions by a simple `vagrant up` command.
Vagrant will set up your `hosts` file 

Virtual machine IP is: 33.33.33.11 however you don't need it, because hostmanager updates your hosts file.

1. Admin: http://admin.a2b.dev/
2. Agent: http://agent.a2b.dev/
3. User : http://user.a2b.dev/

You can register you SIP client on proxy: user.a2b.dev:5060


Main features
------------

1. php-fpm
2. Nginx
3. composer
4. Asterisk Realtime
5. A2billing

Installation
------------
We depends on hostmanager, so first install the plugin.

Install the plugin following the typical Vagrant 1.1 procedure:

    $ vagrant plugin install vagrant-hostmanager
    
    $ vagrant up
        
You may be prompted for password in order to write hosts file. For passwordless startup please read:
https://github.com/smdahlen/vagrant-hostmanager/blob/master/README.md#passwordless-sudo


Default passwords
-----------------

MySQL root:
- username: root
- password: 1234

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


#WEB passwords:

http://admin.a2b.dev
- username: root
- password: changepassword

#Agent
URL: http://agent.a2b.dev
you can set the login on the admin

#User
URL: http://user.a2b.dev
you can set the login on the admin

