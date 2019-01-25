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
echo -e "${YELLOW}*     400-setup_redis.sh     *${NC}"
echo -e "${YELLOW}******************************${NC}"

# Setup Redis
apt-get install -y redis-server 2>&1

#setup redis script
yes | cp -rf /vagrant/files/tools/redis-setup.sh /usr/local/bin/redis-setup
chmod +x /usr/local/bin/redis-setup

if [ ! -f /etc/redis/redis-default.conf ]; then
    cp /vagrant/files/redis-default.conf /etc/redis/redis-default.conf
fi
