#!/bin/ash

 echo -e "\n"
echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** Starting Squid *****"

if [ $(grep -c Xconfig_dirX "${config_dir}/squid.conf") -ne 0 ]; then
   echo "$(date '+%d/%m/%Y - %H:%M:%S') | Initialising Squid config file"
   sed -i -e "s#Xconfig_dirX#${config_dir}#" "${config_dir}/squid.conf"
fi

if [ ! -f "${config_dir}/certificates/SquidCA.pem" ]; then
   echo "$(date '+%d/%m/%Y - %H:%M:%S') | Generating host certificates"
   mkdir -p "${config_dir}/certificates"
   openssl req -new -newkey rsa:2048 -sha256 -days 3650 -nodes -x509 -extensions v3_ca -config "${config_dir}/certificates/SquidCA.cnf" -subj "/C=NA/ST=Global/L=Global/O=Squid/OU=squid-cache/CN=Squid-Proxy/" -keyout "${config_dir}/certificates/SquidCA.pem"  -out "${config_dir}/certificates/SquidCA.pem"
   openssl x509 -in "${config_dir}/certificates/SquidCA.pem" -outform DER -out "${config_dir}/certificates/SquidCA.der"
fi

if [ ! -d "${config_dir}/ssl_db" ]; then
   echo "$(date '+%d/%m/%Y - %H:%M:%S') | Creating dynamically generated certificates database"
   /usr/lib/squid/security_file_certgen -c -d -s "${config_dir}/ssl_db" -M 4MB
fi

if [ ! -f "${config_dir}/cache/swap.state" ]; then
   echo "$(date '+%d/%m/%Y - %H:%M:%S') | Creating cache for dynamically generated certificates"
   squid -z -f "${config_dir}/squid.conf"
fi

if [ $(find "${config_dir}" ! -user squid | wc -l) -ne 0 ]; then
   echo "$(date '+%d/%m/%Y - %H:%M:%S') | Setting owner on files and folders that need it"
   find "${config_dir}" ! -user squid -exec chown squid {} \;
fi

if [ $(find "${config_dir}" ! -group squid | wc -l) -ne 0 ]; then
   echo "$(date '+%d/%m/%Y - %H:%M:%S') | Setting group on files and folders that need it"
   find "${config_dir}" ! -group squid -exec chgrp squid {} \;
fi

/usr/sbin/squid -NYC -d9 -f ${config_dir}/squid.conf