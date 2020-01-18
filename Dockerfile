FROM alpine:latest
MAINTAINER boredazfcuk
ARG app_dependencies="openssl squid tzdata"
ENV config_dir="/config"

RUN echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD STARTED *****" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install Applications" && \
   apk add --no-cache --no-progress ${app_dependencies} && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Create required directories and set permissions" && \
   mkdir -p "${config_dir}/certificates" && \
   mv /var/log/squid/ "${config_dir}/log/" && \
   mv /var/cache/squid/ "${config_dir}/cache/" && \
   chown -R squid:squid "$config_dir" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Move default squid.conf to config directory and create new config" && \
   cp "/etc/squid/"* "${config_dir}/" && \
   mv "${config_dir}/squid.conf" "${config_dir}/squid.conf.bak"

COPY start-squid.sh /usr/local/bin/start-squid.sh

RUN echo "$(date '+%d/%m/%Y - %H:%M:%S') | Set permissions on launcher" && \
   chmod +x /usr/local/bin/start-squid.sh && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD COMPLETE *****"

COPY squid.conf "${config_dir}/squid.conf"
COPY SquidCA.cnf "${config_dir}/certificates/SquidCA.cnf"

VOLUME "${config_dir}"

CMD /usr/local/bin/start-squid.sh