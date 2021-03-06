#!/usr/bin/env bash

####################
# COLOURS
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
####################

# Enable trace printing and exit on the first error
# set -ex

# Just exit on first error
set -e

echo -e ""
echo -e "${YELLOW}******************************${NC}"
echo -e "${YELLOW}*    200-setup_apache.sh     *${NC}"
echo -e "${YELLOW}******************************${NC}"

# Setup Apache
apt-get install -y apache2 2>&1
a2dismod mpm_prefork mpm_worker
a2enmod rewrite actions ssl headers
a2enmod proxy_fcgi
a2enmod proxy_http

# Change Listen Port
sed -i.bak 's/Listen 80$/Listen 8090/' /etc/apache2/ports.conf

# Change user and groups to vagrant
sed -i.bak 's/www-data$/vagrant/' /etc/apache2/envvars
if [ -f /etc/apache2/sites-available/default-ssl.conf ]; then
    rm /etc/apache2/sites-available/default-ssl.conf
fi

# Setup VHOST Script
yes | cp -rf /vagrant/files/tools/vhost.sh /usr/local/bin/vhost
chmod +x /usr/local/bin/vhost