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
echo -e "${YELLOW}*     500-setup_mysql.sh     *${NC}"
echo -e "${YELLOW}******************************${NC}"


# If mysql is already here, move existing data to /srv/mysql/data and change my.cnf to point there
if [ -f /etc/init.d/mysql* ]; then
    service mysql stop

    sed -i "s/datadir.*/datadir = \/srv\/mysql\/data/" /etc/mysql/percona-server.conf.d/mysqld.cnf
    if [ ! -d /srv/mysql/data/mysql ]; then
        echo "Copying mysql databases from /var/lib/mysql/ to /srv/mysql/data/"
        cp -fR /var/lib/mysql/* /srv/mysql/data
        echo "Done copying mysql databases"
    else
        echo "Not moving mysql databases from /var/lib/mysql/ to /srv/mysql/data/ since data is already present there"
    fi

    sudo chown -fR mysql:mysql /srv/mysql

    service mysql start
fi

export DEBIAN_FRONTEND=noninteractive
if [ ! -f /etc/init.d/mysql* ]; then
    wget --progress=bar:force https://repo.percona.com/apt/percona-release_latest.$(lsb_release -sc)_all.deb
    dpkg -i percona-release_latest.$(lsb_release -sc)_all.deb
    apt-get update

    export MYSQL_ROOT_PASSWORD='root'
    export DEBIAN_FRONTEND='noninteractive'

    echo "percona-server-server-5.7 percona-server-server-5.7/root-pass password $MYSQL_ROOT_PASSWORD" | debconf-set-selections
    echo "percona-server-server-5.7 percona-server-server-5.7/re-root-pass password $MYSQL_ROOT_PASSWORD" | debconf-set-selections

    export MYSQL_ROOT_PASSWORD=''
    export DEBIAN_FRONTEND=''

    apt install -y percona-server-server-5.7 percona-server-client-5.7 2>&1

    service mysql stop

    sed -i "s/explicit_defaults_for_timestamp/explicit_defaults_for_timestamp\nbind-address = 0.0.0.0/" /etc/mysql/percona-server.conf.d/mysqld.cnf

    # AIO with file mount fails, lets disable
    sed -i "s/explicit_defaults_for_timestamp/explicit_defaults_for_timestamp\ninnodb_use_native_aio=0/" /etc/mysql/percona-server.conf.d/mysqld.cnf

    sed -i "s/explicit_defaults_for_timestamp/explicit_defaults_for_timestamp\ninnodb_log_file_size = 256M\nmax_allowed_packet = 64M/" /etc/mysql/percona-server.conf.d/mysqld.cnf
    sed -i "s/datadir.*/datadir = \/srv\/mysql\/data/" /etc/mysql/percona-server.conf.d/mysqld.cnf
    if [ ! -d /srv/mysql/data/mysql ]; then
        echo "Copying mysql databases from /var/lib/mysql/ to /srv/mysql/data/"
        cp -r /var/lib/mysql/* /srv/mysql/data
        echo "Done copying mysql databases"
    else
        echo "Not moving mysql databases from /var/lib/mysql/ to /srv/mysql/data/ since data is already present there"
    fi

    sudo chown -fR mysql:mysql /srv/mysql

    service mysql start

    export MYSQL_PWD='root'
    echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'root';" | mysql -u'root'
    export MYSQL_PWD=''
fi

if [[ $(/etc/mysql/percona-server.conf.d/mysqld.cnf | grep 'innodb_log_file_size')  == '' ]]; then
    echo "Patching to allow long blobs in mysql imports"
    sed -i 's/explicit_defaults_for_timestamp/explicit_defaults_for_timestamp\ninnodb_log_file_size = 256M\n/' /etc/mysql/percona-server.conf.d/mysqld.cnf
fi

apt-get install -q -y percona-toolkit 2>&1

# Setup mysql-sync script
yes | cp -rf /vagrant/files/tools/mysql-sync.sh /usr/local/bin/mysql-sync
chmod +x /usr/local/bin/mysql-sync
