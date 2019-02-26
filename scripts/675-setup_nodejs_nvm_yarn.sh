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
echo -e "${YELLOW}* 675-setup_nodejs_nvm_yarn.sh *${NC}"
echo -e "${YELLOW}********************************${NC}"

wget -qO- https://raw.githubusercontent.com/creationix/nvm/v0.34.0/install.sh | bash

# Cannot use source in noninteractive mode with Debian/Ubuntu. ¯\_(ツ)_/¯
#source /home/vagrant/.bashrc

# ^ Which means we cannot install nodejs. They will need to do this in an interactive shell
#nvm install 10.15.1
#nvm install 8.15.0
#nvm use 10.15.1

curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
apt-get update
apt-get install -y yarn