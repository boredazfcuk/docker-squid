FROM alpine:latest
MAINTAINER boredazfcuk

ENV CONFIGDIR="/config" \
   APPS="openssl squid tzdata"

COPY start-squid.sh /usr/local/bin/start-squid.sh

RUN echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD STARTED *****" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install Applications" && \
   apk add --no-cache --no-progress ${APPS} && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Create required directories and set permissions" && \
   mkdir -p "${CONFIGDIR}/certificates" && \
   mv /var/log/squid/ "${CONFIGDIR}/log/" && \
   mv /var/cache/squid/ "${CONFIGDIR}/cache/" && \
   chown -R squid:squid "$CONFIGDIR" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Move default squid.conf to config directory and create new config" && \
   cp "/etc/squid/"* "${CONFIGDIR}/" && \
   mv "${CONFIGDIR}/squid.conf" "${CONFIGDIR}/squid.conf.bak" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Set permissions on launcher" && \
   chmod +x /usr/local/bin/start-squid.sh && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD COMPLETE *****"

COPY squid.conf "${CONFIGDIR}/squid.conf"
COPY SquidCA.cnf "${CONFIGDIR}/certificates/SquidCA.cnf"

VOLUME "${CONFIGDIR}"

CMD /usr/local/bin/start-squid.sh