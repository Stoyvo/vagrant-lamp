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
echo -e "${YELLOW}*    200-setup_varnish.sh    *${NC}"
echo -e "${YELLOW}******************************${NC}"

# Setup Varnish
apt-get install -y varnish 2>&1
sed -i.bak 's/.port = "8080";$/.port = "8090";\n    .connect_timeout = 30s;\n    .first_byte_timeout = 3000s;\n    .between_bytes_timeout = 50s;/' /etc/varnish/default.vcl

if [ ! -f /etc/default/varnish.bak ]; then
    cp /etc/default/{varnish,varnish.bak}
fi
cat > /etc/default/varnish <<EOF
START=yes
NFILES=131072
MEMLOCK=82000
DAEMON_OPTS="-a :80 \\
             -T localhost:6082 \\
             -f /etc/varnish/default.vcl \\
             -S /etc/varnish/secret \\
             -s malloc,256m"
EOF
