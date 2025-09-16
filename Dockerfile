# Download base image ubuntu 22.04
FROM ubuntu:24.04

LABEL org.opencontainers.image.source="https://github.com/ict-solutions-dev/docker-duoauthproxy" \
      org.opencontainers.image.description="Docker image for Duo Security Authentication Proxy with RADIUS support." \
      org.opencontainers.image.title="Security Authentication Proxy" \
      org.opencontainers.image.authors="Jozef Rebjak <jozef.rebjak@ictsolutions.net>" \
      org.opencontainers.image.vendor="ICT Solutions"

# Disable Prompt During Packages Installation
ARG DEBIAN_FRONTEND=noninteractive

# Update Ubuntu Software repository and install dependencies
# hadolint ignore=DL3008
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    libssl-dev=3.0.2-0ubuntu1* \
    build-essential=12.9ubuntu3* \
    libffi-dev=3.4.2-4* \
    perl=5.34.0-3ubuntu1* \
    zlib1g-dev=1:1.2.11.dfsg-2ubuntu9* \
    wget=1.21.2-2ubuntu1* \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Add default user (with UID 35505 and GID 35505)
RUN groupadd -r duo -g 35505 && useradd --no-log-init -r -g duo -u 35505 duo

# Specify DuoAuthProxy version
ARG DUO_VERSION

# Install duoauthproxy itself
WORKDIR /tmp
RUN wget --progress=dot:giga --no-check-certificate -O duoauthproxy-${DUO_VERSION}-src.tgz https://dl.duosecurity.com/duoauthproxy-${DUO_VERSION}-src.tgz && \
    tar -zxf duoauthproxy-${DUO_VERSION}-src.tgz && \
    rm duo*.tgz && \
    mv duoauthproxy-*-src duoauthproxy-src

WORKDIR /tmp/duoauthproxy-src
RUN make

WORKDIR /tmp/duoauthproxy-src/duoauthproxy-build
RUN ./install --install-dir /opt/duoauthproxy --service-user duo --log-group duo --create-init-script no --enable-selinux no

# Clean up
RUN rm -rf /tmp/duoauthproxy-src && \
    apt-get clean

# Expose Ports for the Application
EXPOSE 1812-1818/udp 18120/udp 636/tcp 389/tcp

# Volume configuration
VOLUME ["/opt/duoauthproxy/conf/","/opt/duoauthproxy/log/"]

# Copy init script and make it executable
COPY assets/01-init.sh /

RUN chmod +x /01-init.sh

USER duo:duo

ENTRYPOINT ["/01-init.sh"]
