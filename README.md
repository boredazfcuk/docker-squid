# docker-squid
An Alpine Linux Docker container for Squid with transparent HTTPS interception and decryption.

This container monitors Internet bound traffic on my network. It requires the docker-proxyconfig container running alongside it to work properly.

When it starts up, it will copy the Certification Authority certificates it generates to a folder shared with the docker-proxyconfig container.

The docker-proxyconfig container will make these certificates available via simple web page so they can be manually installed on client machines that need monitoring.

The docker-proxyconfig will also publish a proxy.pac file, which tells the clients which domains should be contacted directly, and everything else to go direct.

Currently, I configure the proxy.pac location via DHCP. Once I've containerised that side of things, I'll publish that too.

This squid container logs all outgoing traffic to /var/log/squid/access.log
