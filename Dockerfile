ARG     REDIS_TAG=5-alpine
FROM    redis:${REDIS_TAG}
ARG     HTTP_PROXY
ARG     HTTPS_PROXY

ARG     S6_OVERLAY_VERSION="v1.22.1.0"
ARG     S6_OVERLAY_ARCH="amd64"
ADD     https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_VERSION}/s6-overlay-${S6_OVERLAY_ARCH}.tar.gz /tmp/s6-overlay.tar.gz
ENV     S6_BEHAVIOUR_IF_STAGE2_FAILS=2

RUN     \
        if [ ! -z "$HTTP_PROXY" ]; then \
            export http_proxy=${HTTP_PROXY}; \
        fi \
        && \
        if [ ! -z "$HTTPS_PROXY" ]; then \
            export https_proxy=${HTTPS_PROXY}; \
        fi \
        && apk add --no-cache openssl tzdata \
        && apk add --no-cache --virtual .build-deps \
        autoconf \
        automake \
        build-base \
        git \
        gcc \
        libtool \
        openssl-dev \
        zlib-dev \
        && \
        if [ -z "$HTTPS_PROXY" ]; then \
            git config --global http.proxy ${HTTPS_PROXY}; \
            git config --global http.sslVerify false; \
        fi \
        && cd /usr/src \
        && git clone https://github.com/Netflix/dynomite.git \
        && cd /usr/src/dynomite \
        && autoreconf -fvi \
        && ./configure --enable-debug=log \
        && CFLAGS="-ggdb3 -O0" ./configure --enable-debug=full \
        && make \
        && make install \
        && apk del .build-deps \
        && mkdir -p /etc/dynomite /var/log/dynomite \
        && cp /usr/src/dynomite/conf/dynomite.yml /etc/dynomite/ \
        && mv /usr/src/dynomite/src/dynomite /usr/local/bin/dynomite \
        && tar xvfz /tmp/s6-overlay.tar.gz -C / \
        && rm -rf \
        /usr/src/* \
        /var/cache/apk/* \
        /tmp/*


# Expose the peer port
RUN     echo 'Exposing peer port 8101'
EXPOSE  8101

# Expose the underlying Redis port
RUN     echo 'Exposing Redis port 22122'
EXPOSE  22122

# Expose the stats/admin port
RUN     echo 'Exposing stats/admin port 22222'
EXPOSE  22222

# Default port to acccess Dynomite
RUN     echo 'Exposing client port for Dynomite 8102'
EXPOSE  8102

# Setting overcommit for Redis to be able to do BGSAVE/BGREWRITEAOF
RUN sysctl vm.overcommit_memory=1

ENTRYPOINT [ "/init" ]
CMD []
