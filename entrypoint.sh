#!/bin/ash

Initialise(){
   lan_ip="$(hostname -i)"
   container_network="$(ip route | grep $(hostname -i) | grep -v default | awk '{print $1}')"
   echo
   echo "$(date '+%d/%m/%Y %H:%M:%S')| ***** Starting $($(which squid) -v | grep Version) *****"
   echo "$(date '+%d/%m/%Y %H:%M:%S')| $(cat /etc/*-release | grep "PRETTY_NAME" | sed 's/PRETTY_NAME=//g' | sed 's/"//g')"
   echo "$(date '+%d/%m/%Y %H:%M:%S')| Squid User ID: $(id -u squid)"
   echo "$(date '+%d/%m/%Y %H:%M:%S')| Monitoring Group ID: ${monitoring_gid}"
   echo "$(date '+%d/%m/%Y %H:%M:%S')| IP address: ${lan_ip}"
   echo "$(date '+%d/%m/%Y %H:%M:%S')| Container network: ${container_network}"
   echo "$(date '+%d/%m/%Y %H:%M:%S')| Config directory: ${config_dir}"
   echo "$(date '+%d/%m/%Y %H:%M:%S')| Data directory: ${data_dir:=/data}"
   if [ "${home_dir}" ]; then echo "$(date '+%d/%m/%Y %H:%M:%S')| Home directory for proxyconfig web server to serve proxy pac and installation certificates: ${home_dir}"; fi
}

FirstRun(){
   if [ -f "/first_run" ]; then
      echo "$(date '+%d/%m/%Y %H:%M:%S')| ***** First run detected. Create default squid config in ${config_dir} *****"
      if [ -d "/etc/squid/" ]; then
         mv "/etc/squid/" "/etc/squid.default/"
         cp "/etc/squid.default/cachemgr.conf" "${config_dir}/"
         cp "/etc/squid.default/errorpage.css" "${config_dir}/"
         cp "/etc/squid.default/mime.conf" "${config_dir}/"
         cp "/etc/squid.default/squid.conf" "${config_dir}/"
      fi
      if [ "$(grep -cE "^http_port 3128$" "${config_dir}/squid.conf")" -eq 1 ]; then
         echo "$(date '+%d/%m/%Y %H:%M:%S')| Create default ssl-bump configuration"
         sed -i \
            -e "s%^http_port .*%http_port 0.0.0.0:3128 ssl-bump cert=${config_dir}/https/squid_ca_chain.pem generate-host-certificates=on dynamic_cert_mem_cache_size=16MB%" \
            "${config_dir}/squid.conf"
         echo "$(date '+%d/%m/%Y %H:%M:%S')| Create default peek and splice configuration"
         peek_and_splice="$(echo "https_port 0.0.0.0:3129 intercept ssl-bump cert=${config_dir}/https/squid_ca_chain.pem generate-host-certificates=on dynamic_cert_mem_cache_size=16MB" \
            "\nsslcrtd_program /usr/lib/squid/security_file_certgen -d -s ${data_dir}/ssl_db -M 16MB" \
            "\nsslcrtd_children 3 startup=1 idle=1" \
            "\nacl step1 at_step SslBump1" \
            "\nssl_bump peek step1" \
            "\nssl_bump bump all" \
            "\nssl_bump splice all" \
         )"
         sed -i \
            -e "/^http_port 0.0.0.0:3128/a ${peek_and_splice}" \
            "${config_dir}/squid.conf"
      fi
      if [ ! -d "${config_dir}/https" ]; then
         echo "$(date '+%d/%m/%Y %H:%M:%S')| Create certificates directory"
         mkdir -p "${config_dir}/https"
         chwown squid:squid "${config_dir}/https"

         echo "$(date '+%d/%m/%Y %H:%M:%S')| Create certification authority certificate configuration file"
         if [ ! -f "${config_dir}/https/ca.cnf" ]; then
            {
               echo '[ req ]'
               echo 'distinguished_name = req_distinguished_name'
               echo 'req_extensions = v3_req'
               echo 'x509_extensions = v3_ca'
               echo
               echo '[ req_distinguished_name]'
               echo
               echo '[ v3_req ]'
               echo 'basicConstraints = CA:TRUE'
               echo 'keyUsage = nonRepudiation, digitalSignature, keyEncipherment'
               echo
               echo '[ v3_ca ]'
               echo 'basicConstraints = CA:TRUE'
               echo 'keyUsage = cRLSign, keyCertSign'
               echo 'subjectKeyIdentifier   = hash'
               echo 'authorityKeyIdentifier = keyid:always,issuer:always'
               echo 'issuerAltName          = issuer:copy'
            } >"${config_dir}/https/ca.cnf"
         fi
         if [ ! -f "${config_dir}/https/squid_ca_key.pem" ] || [ ! -f "${config_dir}/https/squid_ca_cert.pem" ]; then
            echo "$(date '+%d/%m/%Y %H:%M:%S')| Generating certification authority certificates"
            openssl req -new -newkey rsa:2048 -sha256 -days 3650 -nodes -x509 -extensions v3_ca -config "${config_dir}/https/ca.cnf" -subj "/C=NA/ST=Global/L=Global/O=Squid/OU=Squid/CN=Squid/" -keyout "${config_dir}/https/squid_ca_key.pem"  -out "${config_dir}/https/squid_ca_cert.pem"
            echo "$(date '+%d/%m/%Y %H:%M:%S')| Creating chained certification authority certificate"
            cat "${config_dir}/https/squid_ca_cert.pem" "${config_dir}/https/squid_ca_key.pem" >> "${config_dir}/https/squid_ca_chain.pem"
         fi
         if [ ! -f "${config_dir}/https/squid_ca_cert.der" ]; then
            echo "$(date '+%d/%m/%Y %H:%M:%S')| Converting certification authority certificate to DER format for client installation"
            openssl x509 -in "${config_dir}/https/squid_ca_cert.pem" -outform DER -out "${config_dir}/https/squid_ca_cert.der"
         fi
         if [ -d "${data_dir}/ssl_db" ]; then
            echo "$(date '+%d/%m/%Y %H:%M:%S')| Removing SSL certificate DB as new CA certificate generated"
            rm -r "${data_dir}/ssl_db"
         fi
      fi
      if [ ! -d "${data_dir}/ssl_db" ]; then
         echo "$(date '+%d/%m/%Y %H:%M:%S')| Creating SSL certificate DB directory"
         /usr/lib/squid/security_file_certgen -c -s "${data_dir}/ssl_db" -M 16MB
         chown -R squid:squid "${data_dir}/ssl_db"
      fi
      echo "$(date '+%d/%m/%Y %H:%M:%S')| Configure logging"
      {
         echo
         echo '# Configure Logging'
         echo 'logformat gmt_access_log %tg.%03tu %6tr %>a %Ss/%03>Hs %<st %rm %ru %[un %Sh/%<a %mt'
         echo "access_log stdio:/var/log/squid/access.log gmt_access_log !ignore_container_network ignore_healthcheck"
         echo "cache_log /var/log/squid/cache.log common"
         echo 'strip_query_terms off'
      } >> "${config_dir}/squid.conf"

      echo "$(date '+%d/%m/%Y %H:%M:%S')| Configure cache"
      {
         echo
         echo '# Configure Cache'
         echo 'cache_mem 768 MB'
         echo 'maximum_object_size_in_memory 512 MB'
         echo 'maximum_object_size 3 GB'
         echo 'cache_replacement_policy heap LFUDA'
         echo 'range_offset_limit -1'
         echo 'quick_abort_min -1 KB'
      } >> "${config_dir}/squid.conf"

      echo "$(date '+%d/%m/%Y %H:%M:%S')| Configure mime table file location"
      {
         echo
         echo "# Configure relocated mime configuration file"
         echo "mime_table ${config_dir}/mime.conf"
      } >> "${config_dir}/squid.conf"

      echo "$(date '+%d/%m/%Y %H:%M:%S')| Configure PID file location"
      {
         echo
         echo "# Configure relocated pid file"
         echo 'pid_filename /run/squid/${service_name}.pid'
      } >> "${config_dir}/squid.conf"

      echo "$(date '+%d/%m/%Y %H:%M:%S')| First run configuration complete"
      rm "/first_run"
   fi
}

Configure(){
   if [ "$(grep -c "acl ignore_container_network src" "${config_dir}/squid.conf")" -eq 0 ]; then
      echo "$(date '+%d/%m/%Y %H:%M:%S')| Create access control list to prevent logging for container network: ${container_network}"
      sed -i \
         -e "/RFC 1122/i acl ignore_container_network src ${container_network}" \
         "${config_dir}/squid.conf"
   fi
   if [ "$(grep -c "acl ignore_healthcheck has request" "${config_dir}/squid.conf")" -eq 0 ]; then
      echo "$(date '+%d/%m/%Y %H:%M:%S')| Create access control list to ignore healthchecks (empty requests)"
      sed -i \
         -e "/RFC 1122/i acl ignore_healthcheck has request" \
         "${config_dir}/squid.conf"
   fi
   echo "$(date '+%d/%m/%Y %H:%M:%S')| Configure cache directory"
   sed -i \
      -e "s%^coredump_dir .*%coredump_dir ${data_dir}/cache%" \
      -e "s%#cache_dir .*%cache_dir aufs ${data_dir}/cache 3072 16 256%" \
      "${config_dir}/squid.conf"
   echo "$(date '+%d/%m/%Y %H:%M:%S')| Set Squid's LAN IP subnet in access control list: ${container_network}"
   sed -i \
      -e "s%^acl ignore_container_network src.*%acl ignore_container_network src ${container_network}%" \
      "${config_dir}/squid.conf"
   echo "$(date '+%d/%m/%Y %H:%M:%S')| Configure ssl-bump"
   sed -i \
      -e "s%^http_port .*%http_port 0.0.0.0:3128 ssl-bump cert=${config_dir}/https/squid_ca_chain.pem generate-host-certificates=on dynamic_cert_mem_cache_size=16MB%" \
      "${config_dir}/squid.conf"
   echo "$(date '+%d/%m/%Y %H:%M:%S')| Configure peek and splice"
   sed -i \
      -e "s%^https_port .*%https_port 0.0.0.0:3129 intercept ssl-bump cert=${config_dir}/https/squid_ca_chain.pem generate-host-certificates=on dynamic_cert_mem_cache_size=16MB%" \
      "${config_dir}/squid.conf"
   if [ -d "${home_dir}" ]; then
      echo "$(date '+%d/%m/%Y %H:%M:%S')| HTTPd server home folder detected, copying certificates to: ${home_dir}"
      cp "${config_dir}/https/squid_ca_cert.pem" "${config_dir}/https/squid_ca_cert.der" "${home_dir}"
   fi
   if [ -d "${data_dir}/cache" ]; then
      echo "$(date '+%d/%m/%Y %H:%M:%S')| Reinitialise cache"
      rm -r "${data_dir}/cache"
   fi
   mkdir -p "${data_dir}/cache"
   chown squid:squid "${data_dir}/cache"
   echo "$(date '+%d/%m/%Y %H:%M:%S')| Initialise cache for dynamically generated certificates"
   /usr/sbin/squid -N -z -f "${config_dir}/squid.conf"
   chown -R squid:squid "${data_dir}/cache"
}

SetOwnerAndGroup(){
   echo "$(date '+%d/%m/%Y %H:%M:%S')| Set owner of application files, if required"
   find "${config_dir}" ! -user squid -exec chown squid {} \;
   find "${config_dir}" ! -group squid -exec chgrp squid {} \;
   find "${cache_dir}" ! -user squid -exec chown squid {} \;
   find "${cache_dir}" ! -group squid -exec chgrp squid {} \;
   find "/var/log/squid" ! -user squid -exec chown squid {} \;
   find "/var/log/squid" ! -group "${monitoring_gid}" -exec chgrp "${monitoring_gid}" {} \;
   if [ -d "${home_dir}" ]; then
      find "${home_dir}" ! -user squid -exec chown squid {} \;
      find "${home_dir}" ! -group squid -exec chgrp squid {} \;
   fi
}

LaunchSquid (){
   echo "$(date '+%d/%m/%Y %H:%M:%S')| ***** Configuration of Squid container launch environment complete *****"
   if [ -z "${1}" ]; then
      echo "$(date '+%d/%m/%Y %H:%M:%S')| Starting Squid"
      exec /usr/sbin/squid -NYC -d9 -f "${config_dir}/squid.conf"
   else
      exec "$@"
   fi
}

Initialise
FirstRun
SetOwnerAndGroup
Configure
SetOwnerAndGroup
LaunchSquid
