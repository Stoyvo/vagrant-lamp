#!/usr/bin/env bash
# Version 1.0.2
#
# Show Usage, Output to STDERR
#
function show_header {
    echo -e "\e[32m"
    echo -e "***********************"
    echo -e "* vhost version 1.0.2 *"
    echo -e "***********************\e[0m"
}

function show_usage {
    local help
    local _versions=$(get_php_versions)

    read -r -d '' help << EOF_HELP
Create or Remove vHost in Ubuntu Server
Assumes PHP-FPM with proxy_fcgi and /etc/apache2/sites-available and /etc/apache2/sites-enabled setup are used

Usage: sudo vhost add|remove -d DocumentRoot -n ServerName -p PhpVersion [-a ServerAlias] [-s CertPath] [-c CertName] [-f]
Options:
  -d DocumentRoot    : DocumentRoot i.e. /var/www/yoursite
  -h Help            : Show this menu.
  -n ServerName      : Domain i.e. example.com or sub.example.com or 'js.example.com static.example.com'
  -a ServerAlias     : Alias i.e. *.example.com or another domain altogether OPTIONAL
                       You can now add multiple aliases for any given site, e.g.
                       -a www.example.com -a example.ca -a www.example.ca
  -p PHPVersion      : PHP Version:
                       choose one of these:  [###php_versions###]
  -s CertPath        : ***SELF SIGNED CERTIFICATE ARE AUTOMATICALLY CREATED FOR EACH VHOST USE THIS TO OVERRIDE***
                       File path to the SSL certificate. Directories only, no file name. OPTIONAL
                       If using an SSL Certificate, also creates a port :443 vhost as well.
                       This *ASSUMES* a .crt and a .key file exists
                       at file path /provided-file-path/your-server-or-cert-name.[crt|key].
                       Otherwise you can except Apache errors when you reload Apache.
                       Ensure Apache's mod_ssl is enabled via "sudo a2enmod ssl".
  -k KeyPath         : ***SELF SIGNED CERTIFICATE ARE AUTOMATICALLY CREATED FOR EACH VHOST USE THIS TO OVERRIDE***
                       File path to the SSL Key. Directories only, no file name. OPTIONAL
                       If using an SSL Certificate, also creates a port :443 vhost as well.
                       This *ASSUMES* a .crt and a .key file exists
                       at file path /provided-file-path/your-server-or-cert-name.[crt|key].
                       Otherwise you can except Apache errors when you reload Apache.
                       Ensure Apache's mod_ssl is enabled via "sudo a2enmod ssl".
  -c CertName        : ***SELF SIGNED CERTIFICATE ARE AUTOMATICALLY CREATED FOR EACH VHOST USE THIS TO OVERRIDE***
                       Certificate Name "example.com" becomes "example.com.key" and "example.com.crt". OPTIONAL
                       Will default to ServerName
  -f                 : Force mode - silently reponds 'yes' to any confirmation messages




EOF_HELP
    echo "$help" | sed "s/###php_versions###/${_versions}/g"
    echo ""
}


function get_php_versions {
    local config_php
    source /vagrant/config_php.sh
    for i in "${config_php[@]}"; do
        arr=(${i// / })
        phpn=${arr[1]}
        _versions="${_versions}${phpn} "
    done;
    echo "${_versions:0:-1}"
}


#
#   Output vHost skeleton, fill with userinput
#   To be outputted into new file
#
function create_vhost {
cat <<- _EOF_
<VirtualHost *:8090>
    ServerAdmin webmaster@localhost
    ServerName  $ServerName

    ###ServerAlias###

    DocumentRoot $DocumentRoot

    # PHP proxy specifications
    <Proxy fcgi://127.0.0.1:$PhpPort>
        ProxySet timeout=1800
    </Proxy>

    ProxyPassMatch ^/(.*\.php(/.*)?)$ fcgi://127.0.0.1:$PhpPort$DocumentRoot/\$1

    <Directory $DocumentRoot>
        Options -Indexes +FollowSymLinks +MultiViews
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/$ServerName-error.log

    # Possible values include: debug, info, notice, warn, error, crit,
    # alert, emerg.
    LogLevel warn

    CustomLog \${APACHE_LOG_DIR}/$ServerName-access.log combined


</VirtualHost>
_EOF_
}

function create_ssl_vhost {
cat <<- _EOF_
<VirtualHost *:443>
    ServerAdmin webmaster@localhost
    ServerName  $ServerName

    ###ServerAlias###

    # PHP proxy specifications
    <Proxy fcgi://127.0.0.1:$PhpPort>
        ProxySet timeout=1800
    </Proxy>

    ProxyPassMatch ^/(.*\.php(/.*)?)$ fcgi://127.0.0.1:$PhpPort$DocumentRoot/\$1

    DocumentRoot $DocumentRoot

    <Directory $DocumentRoot>
        Options -Indexes +FollowSymLinks +MultiViews
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/$ServerName-error.log

    # Possible values include: debug, info, notice, warn, error, crit,
    # alert, emerg.
    LogLevel warn

    CustomLog \${APACHE_LOG_DIR}/$ServerName-access.log combined

    SSLEngine on

    SSLCertificateFile  $CertPath/$CertName.crt
    SSLCertificateKeyFile $KeyPath/$CertName.key

    <FilesMatch "\.(cgi|shtml|phtml|php)$">
        SSLOptions +StdEnvVars
    </FilesMatch>

    BrowserMatch "MSIE [2-6]" \\
        nokeepalive ssl-unclean-shutdown \\
        downgrade-1.0 force-response-1.0
    # MSIE 7 and newer should be able to use keepalive
    BrowserMatch "MSIE [17-9]" ssl-unclean-shutdown
</VirtualHost>
_EOF_
}

function confirm () {
    if [ "$Force" = "y" ]; then
        true
    else
        # call with a prompt string or use a default
        echo -en "\n\e[33m${1:-Are you sure? [y/N]}\e[0m"
        read -r -p ' ' response
        case ${response} in
            [yY][eE][sS]|[yY])
                true
                ;;
            *)
                false
                ;;
        esac
    fi
}

function add_vhost {
    # If CertName doesn't get set, set it to ServerName
    if [ "$CertName" == "" ]; then
        CertName=$ServerName
    fi

    # If CertName doesn't get set, set it to ServerName
    if [ "$CertPath" == "" ]; then
        CertPath="/etc/apache2/ssl/cert"
    fi

    # If CertName doesn't get set, set it to ServerName
    if [ "$KeyPath" == "" ]; then
        KeyPath="/etc/apache2/ssl/private"
    fi

    if [ ! -d $DocumentRoot ]; then
        mkdir -p $DocumentRoot
        #chown USER:USER $DocumentRoot #POSSIBLE IMPLEMENTATION, new flag -u ?
    fi

    create_vhost | sed "s/###ServerAlias###/${ServerAlias}/g" > /etc/apache2/sites-available/200-${ServerName}.conf

    # Make directory to place SSL Certificate if it doesn't exists
    if [[ ! -d $KeyPath ]]; then
      sudo mkdir -p $KeyPath
    fi

    if [[ ! -d $CertPath ]]; then
      sudo mkdir -p $CertPath
    fi

    if [ ! -f "$CertPath/$ServerName.crt" ] && [ ! -f "$KeyPath/$ServerName.key" ]; then
        openssl req -x509 -nodes -newkey rsa:2048 -keyout "$KeyPath/$ServerName.key" -out "$CertPath/$ServerName.crt" -days 365 \
        -reqexts SAN -extensions SAN -config <(cat /etc/ssl/openssl.cnf <(printf "[SAN]\nsubjectAltName=DNS:$ServerName")) \
        -subj "/C=CA/ST=Ontario/L=Toronto/O=Demac Media/OU=Development/CN=$ServerName"
    elif [ -f "$CertPath/$ServerName.crt" ] && [ -f "$KeyPath/$ServerName.key" ]; then
        if confirm "SSL Key and certificate for $ServerName already exist. Recreate them? [y/N]" ; then
            openssl req -x509 -nodes -newkey rsa:2048 -keyout "$KeyPath/$ServerName.key" -out "$CertPath/$ServerName.crt" -days 365 \
            -reqexts SAN -extensions SAN -config <(cat /etc/ssl/openssl.cnf <(printf "[SAN]\nsubjectAltName=DNS:$ServerName")) \
            -subj "/C=CA/ST=Ontario/L=Toronto/O=Demac Media/OU=Development/CN=$ServerName"
        fi
    fi

    create_ssl_vhost | sed "s/###ServerAlias###/${ServerAlias}/g" >> /etc/apache2/sites-available/200-${ServerName}.conf

    # Enable Site
    cd /etc/apache2/sites-available/ && a2ensite 200-${ServerName}.conf

    # Add entry to hosts
    if ! grep -q "127.0.0.1 $ServerName" /etc/hosts ; then
      echo "127.0.0.1 $ServerName" >> /etc/hosts
    fi

    echo ""
    service apache2 reload
}

function remove_vhost {
    if [ ! -f "/etc/apache2/sites-available/$ServerName.conf" ] && [ ! -f "/etc/apache2/sites-available/200-$ServerName.conf" ]; then
        show_error "vHost $ServerName not found.  Aborting."
        exit 1
    fi

    # Remove legacy non-prefixed version first:
    if [ -f "/etc/apache2/sites-enabled/$ServerName.conf" ]; then
        cd /etc/apache2/sites-available/ && a2dissite ${ServerName}.conf
        rm /etc/apache2/sites-available/${ServerName}.conf
    fi

    # Remove new prefixed version next:
    if [ -f "/etc/apache2/sites-enabled/200-$ServerName.conf" ]; then
        cd /etc/apache2/sites-available/ && a2dissite 200-${ServerName}.conf
        rm /etc/apache2/sites-available/200-${ServerName}.conf
    fi

    service apache2 reload
}

function parse_php_version {
    local config_php
    local i
    source /vagrant/config_php.sh
    for i in "${config_php[@]}"; do
        local arr=(${i// / })
        local phpv=${arr[0]}
        local phpn=${arr[1]}
        local phpp=${arr[2]}
        if [ ${PhpVersion} == ${phpn} ]; then
            PhpPort=${phpp}
        fi
    done;
    if [ -z ${PhpPort+x} ]; then
        show_error "Unsupported PHP version [$PhpVersion].  Supported versions are: [$(get_php_versions)].  Aborting."
        exit 1
    fi
}

function show_error {
    show_usage
    echo -e "\e[31m${1}\e[0m"
}

# Set Defaults
CertPath=""
KeyPath=""
ServerAlias=""
force="n"

# Transform long options to short ones
for arg in "$@"; do
  case "$arg" in
    "add")
        shift
        set -- "$@" "-A"
        ;;
    "remove")
        shift
        set -- "$@" "-R"
        ;;
     *)
        set -- "$@" "$arg"
  esac
done

#Parse flags
ServerAlias=""
Force='n'
while getopts "d:s:k:a:p:n:c:h:ARf" OPTION; do
    case $OPTION in
        h)
            show_usage
            ;;
        d)
            DocumentRoot=$OPTARG
            ;;
        n)
            ServerName=$OPTARG
            ;;
        a)
            if [[ $(echo "${ServerAlias}" | grep ${OPTARG}) == '' ]]; then
                ServerAlias+="ServerAlias ${OPTARG}\n    "
            fi
            ;;
        p)
            PhpVersion=$OPTARG
            ;;
        s)
            CertPath=$OPTARG
            ;;
        k)
            KeyPath=$OPTARG
            ;;
        c)
            CertName=$OPTARG
            ;;
        A)
            Task="add"
            ;;
        R)
            Task="remove"
            ;;
        f)
            Force="y"
            ;;
        *)
            show_usage
            ;;
    esac
done

show_header
if [ "$(id -u)" != "0" ]; then
    if [ "$Task" == 'add' ] || [ "$Task" == 'remove' ]; then
        show_error "Must be run with 'sudo' or as root.  Aborting."
        exit 1
    fi
    show_usage
    exit 1
elif [ "$Task" = "add" ] ; then
    if [ "$ServerName" = "" ] ; then
        show_error "Missing Server Name.  Aborting."
        exit 1
    elif [ "$DocumentRoot" == "" ]; then
        show_error "DocumentRoot must be set.  Aborting."
        exit 1
    elif [ "$CertPath" != "" ] && [ "$KeyPath" == "" ]; then
        show_error "When supplying CertPath, KeyPath must also be supplied.  Aborting."
        exit 1
    elif [ "$CertPath" == "" ] && [ "$KeyPath" != "" ]; then
        show_error "When supplying KeyPath, CertPath must also be supplied.  Aborting."
        exit 1
    elif [ -f "/etc/apache2/sites-available/$ServerName.conf" ] || [ -f "/etc/apache2/sites-available/200-$ServerName.conf" ]; then
        parse_php_version
        if confirm "vHost $ServerName already exists. Remove and Recreate it? [y/N]" ; then
            remove_vhost
        else
            exit 1
        fi
    fi
    parse_php_version
    add_vhost
elif [ "$Task" = "remove" ] ; then
    if [ "$ServerName" = "" ] ; then
        show_error "Missing Server Name.  Aborting."
        exit 1
    fi
    if [ ! -f "/etc/apache2/sites-available/$ServerName.conf" ] && [ ! -f "/etc/apache2/sites-available/200-$ServerName.conf" ]; then
        show_error "vHost $ServerName not present"
        exit 1
    fi
    confirm "Remove vHost $ServerName? [y/N]" && remove_vhost
else
    show_usage
    exit 1
fi
