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
echo -e "${YELLOW}*    999-setup_finish.sh     *${NC}"
echo -e "${YELLOW}******************************${NC}"

# Restart Services
service varnish restart
service apache2 restart
service mysql restart
for f in /etc/profile.d/*-aliases.sh; do source $f; done
phpRestart

####################
echo -e ""
echo -e "${GREEN}******************************${NC}"
echo -e "${GREEN}*            DONE!           *${NC}"
echo -e "${GREEN}******************************${NC}"
echo -e ""
####################