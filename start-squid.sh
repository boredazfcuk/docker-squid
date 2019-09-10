#!/bin/ash

echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** Starting Squid *****"

if [ $(grep -c XCONFIGDIRX "${CONFIGDIR}/squid.conf") -ne 0 ]; then
   echo "$(date '+%d/%m/%Y - %H:%M:%S') | Initialising Squid config file"
   sed -i -e "s#XCONFIGDIRX#${CONFIGDIR}#" "${CONFIGDIR}/squid.conf"
fi

if [ ! -f "${CONFIGDIR}/certificates/SquidCA.pem" ]; then
   echo "$(date '+%d/%m/%Y - %H:%M:%S') | Generating host certificates"
   mkdir -p "${CONFIGDIR}/certificates"
   openssl req -new -newkey rsa:2048 -sha256 -days 3650 -nodes -x509 -extensions v3_ca -config "${CONFIGDIR}/certificates/SquidCA.cnf" -subj "/C=NA/ST=Global/L=Global/O=Squid/OU=squid-cache/CN=Squid-Proxy/" -keyout "${CONFIGDIR}/certificates/SquidCA.pem"  -out "${CONFIGDIR}/certificates/SquidCA.pem"
   openssl x509 -in "${CONFIGDIR}/certificates/SquidCA.pem" -outform DER -out "${CONFIGDIR}/certificates/SquidCA.der"
fi

if [ ! -d "${CONFIGDIR}/ssl_db" ]; then
   echo "$(date '+%d/%m/%Y - %H:%M:%S') | Creating dynamically generated certificates database"
   /usr/lib/squid/security_file_certgen -c -d -s "${CONFIGDIR}/ssl_db" -M 4MB
fi

if [ ! -f "${CONFIGDIR}/cache/swap.state" ]; then
   echo "$(date '+%d/%m/%Y - %H:%M:%S') | Creating cache for dynamically generated certificates"
   squid -z -f "${CONFIGDIR}/squid.conf"
fi

if [ $(find "${CONFIGDIR}" ! -user squid | wc -l) -ne 0 ]; then
   echo "$(date '+%d/%m/%Y - %H:%M:%S') | Setting owner on files and folders that need it"
   find "${CONFIGDIR}" ! -user squid -exec chown squid {} \;
fi

if [ $(find "${CONFIGDIR}" ! -group squid | wc -l) -ne 0 ]; then
   echo "$(date '+%d/%m/%Y - %H:%M:%S') | Setting group on files and folders that need it"
   find "${CONFIGDIR}" ! -group squid -exec chgrp squid {} \;
fi

/usr/sbin/squid -NYC -d9 -f ${CONFIGDIR}/squid.conf