FROM alpine:3.14
MAINTAINER boredazfcuk
ARG app_dependencies="openssl squid tzdata"
ENV config_dir="/config" \
   cache_dir="/cache"

RUN echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD STARTED FOR SQUID *****" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install Applications" && \
   apk add --no-cache --no-progress ${app_dependencies} && \
   touch "/first_run" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD COMPLETE *****"

COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chmod=0755 healthcheck.sh /usr/local/bin/healthcheck.sh

VOLUME "${config_dir}" "${cache_dir}"

ENTRYPOINT /usr/local/bin/entrypoint.sh
