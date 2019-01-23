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
echo -e "${YELLOW}********************************${NC}"
echo -e "${YELLOW}*  650-setup_elasticsearch.sh  *${NC}"
echo -e "${YELLOW}********************************${NC}"


wget --progress=bar:force -O - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -

wget --progress=bar:force https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-5.6.14.deb
dpkg -i elasticsearch-5.6.14.deb

sed -i "s/# network.*/network.host: 192.168.33.15/g" /etc/elasticsearch/elasticsearch.yml

systemctl daemon-reload
systemctl enable elasticsearch.service
systemctl start elasticsearch.service