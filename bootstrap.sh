#!/bin/bash

HOSTNAME="mail.zsoc.com"
DOMAIN="zsoc.com"

sudo apt-get update
sudo apt-get install -y python-software-properties
 
# Add dot-deb repository key
sudo apt-key adv --recv-keys --keyserver http://www.dotdeb.org/dotdeb.gpg E9C74FEEA2098A6E
sudo add-apt-repository "deb http://packages.dotdeb.org wheezy all"
 
# Add MariaDB repository key
sudo apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xcbcb082a1bb943db
sudo add-apt-repository 'deb http://mirror.stshosting.co.uk/mariadb/repo/5.5/debian wheezy main'

sudo apt-get update
# sudo apt-get -y upgrade
sudo apt-get install -y git vim wget

# install mariadb
export DEBIAN_FRONTEND=noninteractive
sudo debconf-set-selections <<< 'mariadb-server-5.5 mysql-server/root_password password pass12345'
sudo debconf-set-selections <<< 'mariadb-server-5.5 mysql-server/root_password_again password pass12345'
sudo apt-get install -y mariadb-server

# install postfix
sudo debconf-set-selections <<< "postfix postfix/mailname string ${HOSTNAME}"
sudo debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
apt-get install -y postfix

# deliver to dovecot
sudo echo "# dovecot configuration" >> /etc/postfix/main.cf
sudo echo "alias_maps = hash:/etc/aliases" >> /etc/postfix/main.cf
sudo echo "alias_database = hash:/etc/aliases" >> /etc/postfix/main.cf
sudo echo "virtual_alias_maps = hash:/etc/postfix/virtual" >> /etc/postfix/main.cf
sudo echo "virtual_mailbox_domains = hash:/etc/postfix/virtual-mailbox-domains" >> /etc/postfix/main.cf
sudo echo "virtual_mailbox_maps = hash:/etc/postfix/virtual-mailbox-users"
sudo echo "virtual_transport = dovecot" >> /etc/postfix/main.cf
sudo echo "dovecot_destination_recipient_limit = 1" >> /etc/postfix/main.cf

# setup catch-all
sudo echo "@${DOMAIN}   catchall@${DOMAIN}" > /etc/postfix/virtual

# setup virtual mailboxes
sudo echo "${DOMAIN}    OK" > /etc/postfix/virtual-mailbox-domains

# setup virtual mailbox users
sudo echo "oz@${DOMAIN} OK" > /etc/postfix/virtual-mailbox-users

# generate databases
postmap /etc/postfix/virtual
postmap /etc/postfix/virtual-mailbox-domains
postmap /etc/postfix/virtual-mailbox-users

# 
sudo echo -e "dovecot   unix  -       n       n       -       -       pipe" >> /etc/postfix/master.cf
sudo echo -e "\tflags=DRhu user=vmail:vmail argv=/usr/lib/dovecot/deliver" >> /etc/postfix/master.cf
sudo echo -e "\t-f \${sender} -d \${recipient}" /etc/postfix/master.cf >> /etc/postfix/master.cf

# install SpamAssassin
sudo apt-get install -y spamass-milter
sudo mkdir /var/run/spamassassin
