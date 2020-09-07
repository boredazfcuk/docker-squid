FROM alpine:3.12
MAINTAINER boredazfcuk
ARG app_dependencies="openssl squid tzdata"
ENV config_dir="/config" \
   cache_dir="/cache"

RUN echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD STARTED FOR SQUID *****" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install Applications" && \
   apk add --no-cache --no-progress ${app_dependencies}

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh

RUN echo "$(date '+%d/%m/%Y - %H:%M:%S') | Set permissions on launcher" && \
   chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD COMPLETE *****"

VOLUME "${config_dir}" "${cache_dir}"

ENTRYPOINT /usr/local/bin/entrypoint.sh
