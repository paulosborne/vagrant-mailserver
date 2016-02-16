#!/bin/bash

HOSTNAME=""
DOMAIN=""

# SPAMASSASSIN CONFIGURATION
SA_USER="debian-spamd"
SA_CHILDREN=2

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
sudo echo "no-reply@${DOMAIN} OK" > /etc/postfix/virtual-mailbox-users

# generate databases
postmap /etc/postfix/virtual
postmap /etc/postfix/virtual-mailbox-domains
postmap /etc/postfix/virtual-mailbox-users

# connect dovecot and postfix
sudo echo 'dovecot   unix  -       n       n       -       -       pipe' >> /etc/postfix/master.cf
sudo echo -e "\tflags=DRhu user=vmail:vmail argv=/usr/lib/dovecot/deliver" >> /etc/postfix/master.cf
sudo echo -e "\t-f \${sender} -d \${recipient}" /etc/postfix/master.cf >> /etc/postfix/master.cf

# install SpamAssassin
sudo apt-get install -y spamass-milter
sudo mkdir /var/run/spamassassin

# configure spamassasin
sudo sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/spamassassin
sudo sed -i 's/CRON=0/CRON=1/g' /etc/default/spamassassin
sudo echo "SAHOME=\"/var/lib/spamassassin\"" >> /etc/default/spamassassin
sudo sed -i "/OPTIONS=/c\OPTIONS=\"--username ${SA_USER} --nouser-config --max-children ${SA_CHILDREN} --helper-home-dir \${SAHOME} --socketpath=/var/run/spamassassin/spamd.sock --socketowner=${SA_USER} --socketgroup=${SA_USER} --socketmode=0660\"" /etc/default/spamassassin
sudo sed -i '/PIDFILE=/c\PIDFILE="/var/run/spamassassin/spamd.pid"' /etc/default/spamassassin

sudo sed -i '/OPTIONS=/c\OPTIONS="-u spamass-milter -m -I -i 127.0.0.1 -- --socket=/var/run/spamassassin/spamd.sock"' /etc/default/spamass-milter
sudo usermod -a -G debian-spamd spamass-milter

# connect postfix and spamassasin
sudo echo 'smtpd_milters = unix:/spamass/spamass.sock' >> /etc/postfix/main.cf
sudo echo 'milter_connect_macros = j {daemon_name} v {if_name} _' >> /etc/postfix/main.cf
sudo echo 'milter_default_action = tempfail' >> /etc/postfix/main.cf

# install dovecot
sudo apt-get install -y dovecot-imapd
