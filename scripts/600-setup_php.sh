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
echo -e "${YELLOW}*      500-setup_php.sh      *${NC}"
echo -e "${YELLOW}******************************${NC}"

function setup_opcache() {
    cat <<EOL >> /opt/phpfarm/inst/php-$1/etc/php.ini

[opcache]
opcache.enable=1
opcache.enable_cli=1
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=4000
opcache.memory_consumption=128
opcache.revalidate_freq=15
EOL
}

function setup_xdebug() {
    cd /usr/lib
    if [ -d /usr/lib/xdebug ]; then
        rm -rf xdebug
    fi
    git clone git://github.com/xdebug/xdebug.git
    cd xdebug

    if [[ $1 == *"5.4"* ]] ; then
        git checkout xdebug_2_3
    fi

    if [[ $1 == *"5.5"* ]] ; then
        git checkout xdebug_2_4
    fi

    if [[ $1 == *"5.6"* ]] ; then
        git checkout xdebug_2_5
    fi

    /opt/phpfarm/inst/php-$1/bin/phpize
    ./configure --with-php-config=/opt/phpfarm/inst/php-$1/bin/php-config
    make
    make install
	cat <<EOL >> /opt/phpfarm/inst/php-$1/etc/php.ini

[xdebug]
zend_extension=xdebug.so
xdebug.max_nesting_level=512
;xdebug.profiler_enable=1
xdebug.profiler_enable_trigger=1
xdebug.profiler_output_dir=/srv/www/xdebug_profiler
xdebug.remote_enable=1
xdebug.remote_connect_back=1
xdebug.remote_host=192.168.33.1
xdebug.remote_port=9000
;xdebug.remote_log="/tmp/xdbg.log"
EOL

}

function setup_imagick() {
    wget --progress=bar:force -O imagick.tgz http://pecl.php.net/get/imagick
    tar xvzf imagick.tgz
    cd imagick-*
    /opt/phpfarm/inst/php-$1/bin/phpize

    ./configure --with-php-config=/opt/phpfarm/inst/php-$1/bin/php-config
    make
    make install
    cat <<EOL >> /opt/phpfarm/inst/php-$1/etc/php.ini

[imagick]
extension=imagick.so
EOL
}

function setup_apcu() {
    cd /usr/lib
    if [ -d /usr/lib/apcu ]; then
        rm -rf apcu
    fi
    git clone git://github.com/krakjoe/apcu.git
    cd apcu

    git checkout v5.1.16

    /opt/phpfarm/inst/php-$1/bin/phpize
    ./configure --with-php-config=/opt/phpfarm/inst/php-$1/bin/php-config
    make
    make install
	cat <<EOL >> /opt/phpfarm/inst/php-$1/etc/php.ini

[apcu]
extension=apcu.so
apc.enable_cli=1
EOL
}

function setup_phpfarm() {
    cd /opt
    if [ ! -d /opt/phpfarm ]; then
        git clone https://github.com/fpoirotte/phpfarm.git phpfarm
    fi
}

function setup_php() {
    # Making these local so they don't bleed out into the global scope
    local arr
    local conf
    local config_php
    local expected
    local i
    local installed
    local phpv
    local phpn
    local phpp
    local php_config_suffix_escaped
    local prefix
    local processes
    local shortname

    source /vagrant/config_php.sh

    if [[ ! -e /opt/phpfarm/custom ]]; then
        sudo mkdir -p /opt/phpfarm/custom
    fi

    sudo cp -a /vagrant/files/php-options/. /opt/phpfarm/custom/

    # Remove any php version not currently shown in config_php.sh
    for installed in $(ls -d /opt/phpfarm/inst/php-* | cut -d'/' -f5 | cut -d'-' -f2); do
        expected='no';
        for i in "${config_php[@]}"; do
            arr=(${i// / })
            if [ ${installed} == ${arr[0]} ]; then
                expected='yes'
            fi
        done;
        if [ ${expected} == 'no' ]; then
            # Remove unrequired php
            if [ -f /opt/phpfarm/inst/php-${installed}/bin/php ]; then
                echo "Removing PHP ${installed}"
                rm -Rf /opt/phpfarm/inst/php-${installed}
            fi
            for shortname in $(ls -d /etc/init.d/php-* | cut -d'/' -f4 | cut -d'-' -f2); do
                echo "testing ${shortname}:"
                if grep -q "php-${installed}" /etc/init.d/php-${shortname} ; then
                    echo "Removing PHP init file php-${shortname}"
                    /etc/init.d/php-${shortname} stop || true

                    # This next bit is to ensure that no process keeps the listening port occupied
                    prefix=$(cat /etc/init.d/php-${shortname} | grep 'prefix=/opt/phpfarm' | cut -d'=' -f2)
                    conf=$(cat /etc/init.d/php-${shortname} | grep 'php_fpm_CONF=' | cut -d'}' -f2)
                    processes=$(ps aux | grep $prefix$conf | tr -s ' ' | cut -d ' ' -f2)
                    echo "Processes to kill: ${processes}"
                    kill ${processes} || true

                    rm /etc/init.d/php-${shortname}
                fi
            done
        fi
    done;

    # Add new versions of PHP
    for i in "${config_php[@]}"; do
        arr=(${i// / })
        phpv=${arr[0]}
        phpn=${arr[1]}
        phpp=${arr[2]}

        if [ ! -f /opt/phpfarm/inst/php-${phpv}/bin/php ]; then
            cd /opt/phpfarm/src
            ./main.sh ${phpv}
            setup_opcache ${phpv}
            setup_apcu ${phpv}
            setup_imagick ${phpv}
            setup_xdebug ${phpv}

            cat <<EOL >> /opt/phpfarm/inst/php-${phpv}/etc/php.ini

[PHP]
memory_limit = 1G

[Date]
date.timezone = Etc/UTC
EOL

            cp /opt/phpfarm/inst/php-${phpv}/etc/php.ini /opt/phpfarm/inst/php-${phpv}/lib/php.ini
        fi
        if [ ${phpv:0:1} == 5 ]; then
            php_config_suffix_escaped="\/etc\/php-fpm.conf"
            if [ ! -f /opt/phpfarm/inst/php-${phpv}/etc/php-fpm.conf ]; then
                cp /vagrant/files/php-fpm-xxx.conf /opt/phpfarm/inst/php-${phpv}/etc/php-fpm.conf
                sed -i "s/###phpv###/${phpv}/g"    /opt/phpfarm/inst/php-${phpv}/etc/php-fpm.conf
                sed -i "s/###phpn###/${phpn}/g"    /opt/phpfarm/inst/php-${phpv}/etc/php-fpm.conf
                sed -i "s/###phpp###/${phpp}/g"    /opt/phpfarm/inst/php-${phpv}/etc/php-fpm.conf
            fi
        else
            php_config_suffix_escaped="\/etc\/php-fpm.d\/www.conf"
            if [ ! -f /opt/phpfarm/inst/php-${phpv}/etc/php-fpm.conf ]; then
                cp /opt/phpfarm/inst/php-${phpv}/etc/php-fpm.conf.default /opt/phpfarm/inst/php-${phpv}/etc/php-fpm.conf
            fi
            if [ ! -f /opt/phpfarm/inst/php-${phpv}/etc/php-fpm.d/www.conf ]; then
                cp /vagrant/files/php-fpm-xxx.conf /opt/phpfarm/inst/php-${phpv}/etc/php-fpm.d/www.conf
                sed -i "s/###phpv###/${phpv}/g"    /opt/phpfarm/inst/php-${phpv}/etc/php-fpm.d/www.conf
                sed -i "s/###phpn###/${phpn}/g"    /opt/phpfarm/inst/php-${phpv}/etc/php-fpm.d/www.conf
                sed -i "s/###phpp###/${phpp}/g"    /opt/phpfarm/inst/php-${phpv}/etc/php-fpm.d/www.conf
            fi
        fi
        if [ ! -f /etc/init.d/php-${phpn} ]; then
            cp /vagrant/files/php-init.d-xxx.sh /etc/init.d/php-${phpn}
            sed -i "s/###phpv###/${phpv}/g" /etc/init.d/php-${phpn}
            sed -i "s/###php_config_suffix###/${php_config_suffix_escaped}/g" /etc/init.d/php-${phpn}
            chmod +x /etc/init.d/php-${phpn}
            update-rc.d php-${phpn} defaults
        fi
    done
}

setup_phpfarm
setup_php

# Add PHPFarm to PATH
if ! grep -q "phpfarm" /etc/environment ; then
    echo "PATH="$PATH:/opt/phpfarm/inst/bin:/opt/phpfarm/inst/current/bin:/opt/phpfarm/inst/current/sbin"" >> /etc/environment
fi

# Set Default php to newest available
/opt/phpfarm/inst/bin/switch-phpfarm $(ls -1 /opt/phpfarm/inst/ | grep php | tail -n1 | cut -d'-' -f2);
