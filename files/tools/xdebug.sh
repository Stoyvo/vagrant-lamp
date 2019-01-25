#!/usr/bin/env bash

####################
# COLOURS
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
####################

function show_header {
    echo -e "\e[32m"
    echo -e "${GREEN}*************************${NC}"
    echo -e "${GREEN}* Enable/Disable xDebug *${NC}"
    echo -e "${GREEN}*                       *${NC}"
    echo -e "${GREEN}*      Inspired by:     *${NC}"
    echo -e "${GREEN}*     Joseph Purcell    *${NC}"
    echo -e "${GREEN}*                       *${NC}"
    echo -e "${GREEN}* ${YELLOW}THIS TOOL CHANGES THE ${GREEN}*${NC}"
    echo -e "${GREEN}*  ${YELLOW}ACTIVE PHP VERSION   ${GREEN}*${NC}"
    echo -e "${GREEN}*        ${YELLOW}${PHP_VERSION}         ${GREEN}*${NC}"
    echo -e "${GREEN}*************************${NC}"
}

function show_usage {
    echo "
Enable or Disable xDebug
This can be useful for a number of reasons, such as performance reasons, or system level on/off switch

Usage: sudo xdebug enable|disable

Current PHP Version: ${PHP_VERSION}"
    echo ""
}

function enable_xdebug {
    sed -e 's/^;zend_extension=xdebug.so/zend_extension=xdebug.so/' -i /opt/phpfarm/inst/php-${PHP_VERSION}/etc/php.ini
    phpRestart
}

function disable_xdebug {
    sed -e 's/^zend_extension=xdebug.so/;zend_extension=xdebug.so/' -i /opt/phpfarm/inst/php-${PHP_VERSION}/etc/php.ini
    phpRestart
}

function getPHPVersion () {
    echo `php -r "echo PHP_VERSION;"`
}

PHP_VERSION=`getPHPVersion`
if [ "$EUID" -ne 0 ] ; then
    echo -e "${RED}Please use this with sudo${NC}"
    exit
fi

source /etc/profile.d/02-php-aliases.sh

Action=''
# Transform long options to short ones
for arg in "$@"; do
  case "$arg" in
    "enable")
        shift
        Action='enable'
        ;;
    "disable")
        shift
        Action='disable'
        ;;
  esac
done

case ${Action} in
    enable)
        enable_xdebug
        ;;
    disable)
        disable_xdebug
        ;;
    *)
        show_header
        show_usage
        exit 1
        ;;
esac