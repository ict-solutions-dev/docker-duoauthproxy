# Download base image ubuntu 22.04
FROM ubuntu:22.04

LABEL org.opencontainers.image.source="https://github.com/ict-solutions-dev/docker-duoauthproxy" \
      org.opencontainers.image.description="Docker image for Duo Security Authentication Proxy with RADIUS support." \
      org.opencontainers.image.title="Security Authentication Proxy" \
      org.opencontainers.image.authors="Jozef Rebjak <jozef.rebjak@ictsolutions.net>" \
      org.opencontainers.image.vendor="ICT Solutions"

# Disable Prompt During Packages Installation
ARG DEBIAN_FRONTEND=noninteractive

# Update Ubuntu Software repository
RUN apt update && apt upgrade -y

# Install dependencies
RUN apt-get -y install libssl-dev build-essential libffi-dev perl zlib1g-dev wget

# Add default user (with UID 35505 and GID 35505)
RUN groupadd -r duo -g 35505 && useradd --no-log-init -r -g duo -u 35505 duo

# Specify DuoAuthProxy version
ARG DUO_VERSION

# Install duoauthproxy itself
RUN wget -O /tmp/duoauthproxy-${DUO_VERSION}-src.tgz https://dl.duosecurity.com/duoauthproxy-${DUO_VERSION}-src.tgz && \
    tar -zxf /tmp/duoauthproxy-${DUO_VERSION}-src.tgz -C /tmp && \
    rm /tmp/duo*.tgz && \
    mv /tmp/duoauthproxy-*-src /tmp/duoauthproxy-src && \
    cd /tmp/duoauthproxy-src && \
    make && \
    cd /tmp/duoauthproxy-src/duoauthproxy-build && \
    ./install --install-dir /opt/duoauthproxy --service-user duo --log-group duo --create-init-script no --enable-selinux no

# Clean up
RUN rm -rf /tmp/duoauthproxy-src && \
    rm -rf /var/lib/apt/lists/* && \
    apt clean

# Expose Ports for the Application
EXPOSE 1812-1818/udp 18120/udp 636/tcp 389/tcp

# Volume configuration
VOLUME ["/opt/duoauthproxy/conf/","/opt/duoauthproxy/log/"]

# Copy init script and make it executable
COPY assets/01-init.sh /

RUN chmod +x /01-init.sh

USER duo:duo

ENTRYPOINT ["/01-init.sh"]
