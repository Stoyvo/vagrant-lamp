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
echo -e "${YELLOW}*  000-setup_environment.sh  *${NC}"
echo -e "${YELLOW}******************************${NC}"

# Create backup folders for mysql and web config
mkdir -p /srv/backup/mysql
mkdir -p /srv/backup/webconfig

# Create folder for mysql data
mkdir -p /srv/mysql/data

apt-get update

# Install git, tig, htop, smem, strace, lynx and dos2unix
# Sytem Tools
apt-get install -y git tig htop smem strace lynx dos2unix 2>&1

# Correct non Unix line endings
find /vagrant/files -type f -exec dos2unix {} \;
dos2unix /vagrant/config_php.sh
dos2unix /vagrant/config_groups.sh
dos2unix /vagrant/config_users.sh

# Removes old non-modular alias if present
rm -f /etc/profile.d/00-aliases.sh

# Copy bash aliases for all users
cp /vagrant/files/profile.d/* /etc/profile.d/

# Next line needed so that root will have access to these aliases
if [ ! -f /root/.bash_aliases ] || [ $(grep -c "for f in /etc/profile.d/\*aliases.sh; do source \$f; done" /root/.bash_aliases) -eq 0 ] ; then
    echo 'for f in /etc/profile.d/*-aliases.sh; do source $f; done' >> /root/.bash_aliases
fi

#Setup PHP compile pre-requisites
apt-get install -y  build-essential libbz2-dev libmysqlclient-dev libxpm-dev libmcrypt-dev \
    libcurl4-gnutls-dev libxml2-dev libjpeg-dev libpng-dev libssl-dev pkg-config libreadline-dev \
    curl autoconf libicu-dev libxslt-dev libfreetype6-dev devscripts language-pack-en openjdk-8-jre-headless \
    libzip-dev libmagickwand-dev 2>&1

if [[ ! -e /usr/include/curl ]]; then
    sudo ln -s /usr/include/x86_64-linux-gnu/curl /usr/include/curl
fi

# Workaround to allow custom scripts added to path with sudo
if ! grep -q "^#Defaults[[:blank:]]*secure_path" /etc/sudoers ; then
    sed -i 's/^Defaults[[:blank:]]*secure_path/#Defaults       secure_path/' /etc/sudoers
fi
