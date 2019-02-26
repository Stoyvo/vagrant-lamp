# PHP functions:
function phpRestart() {
    local arr config_php i phpn
    source /vagrant/config_php.sh
    for i in "${config_php[@]}"; do
        arr=(${i// / })
        phpn=${arr[1]}
        sudo service php-${phpn} restart
    done;
}

function makePhpShortformAliases {
    local arr config_php i phpa
    source /vagrant/config_php.sh
    for i in "${config_php[@]}"; do
        arr=(${i// / })
        phpa="php${arr[1]}='/opt/phpfarm/inst/php-${arr[0]}/bin/php'"
        alias $phpa;
    done;
}

makePhpShortformAliases

