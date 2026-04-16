ARG ALPINE_VERSION=3.23
ARG TOR_VERSION=0.4.9.6
ARG TOR_TARBALL=tor-${TOR_VERSION}.tar.gz
ARG TOR_TARBALL_URL=https://dist.torproject.org/tor-${TOR_VERSION}.tar.gz

ARG LYREBIRD_VERSION=0.8.1
ARG LYREBIRD_TARBALL=lyrebird-lyrebird-${LYREBIRD_VERSION}.tar.gz
ARG LYREBIRD_TARBALL_URL=https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird/-/archive/lyrebird-${LYREBIRD_VERSION}/lyrebird-lyrebird-${LYREBIRD_VERSION}.tar.gz

ARG MEEK_VERSION=0.38.0
ARG MEEK_TARBALL=meek-v${MEEK_VERSION}.tar.gz
ARG MEEK_TARBALL_URL=https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/meek/-/archive/v${MEEK_VERSION}/meek-v${MEEK_VERSION}.tar.gz

ARG SNOWFLAKE_VERSION=2.9.2
ARG SNOWFLAKE_TARBALL=snowflake-v${SNOWFLAKE_VERSION}.tar.gz
ARG SNOWFLAKE_TARBALL_URL=https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake/-/archive/v${SNOWFLAKE_VERSION}/snowflake-v${SNOWFLAKE_VERSION}.tar.gz

ARG GOST_VERSION=3.2.6

#base - base image with runtime dependecies
FROM alpine:${ALPINE_VERSION} AS base
RUN apk add --no-cache \
# tor dependencies
	openssl \
	libevent \
	zstd \
# network tools
	ca-certificates \
	traceroute \
	iputils \
	net-tools \
	procps

#source - special source layer to cache source artifacts
# it is not standard step in free world, but we need to cache sources in docker layer to have access to them without VPN
FROM alpine:${ALPINE_VERSION} AS source
ARG TOR_VERSION
ARG TOR_TARBALL
ARG TOR_TARBALL_URL
ARG LYREBIRD_VERSION
ARG LYREBIRD_TARBALL
ARG LYREBIRD_TARBALL_URL
ARG MEEK_VERSION
ARG MEEK_TARBALL
ARG MEEK_TARBALL_URL
ARG SNOWFLAKE_VERSION
ARG SNOWFLAKE_TARBALL
ARG SNOWFLAKE_TARBALL_URL
ARG HTTP_PROXY
WORKDIR /build
RUN apk add --no-cache \
	curl \
	gnupg

# 514102454D0A87DB0767A1EBBE6A0531C18A9179 Alexander Færøy ahf@torproject.org
# B74417EDDF22AC9F9E90F49142E86A2A11F48D36 David Goulet dgoulet@torproject.org
# 2133BC600AB133E1D826D173FE43009C4607B1FB Nick Mathewson nickm@torproject.org

RUN gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys \
		514102454D0A87DB0767A1EBBE6A0531C18A9179 \ 
		B74417EDDF22AC9F9E90F49142E86A2A11F48D36 \
		2133BC600AB133E1D826D173FE43009C4607B1FB

# if HTTP_PROXY is setted to socks5h://localhost:9050 we download tor sources via tor
RUN if [ -n ${HTTP_PROXY} ]; then \
		echo "using proxy: ${HTTP_PROXY}" && \
		curl -x ${HTTP_PROXY} -O ${TOR_TARBALL_URL} && \
		curl -x ${HTTP_PROXY} -O ${TOR_TARBALL_URL}.sha256sum && \
		curl -x ${HTTP_PROXY} -O ${TOR_TARBALL_URL}.sha256sum.asc && \
		curl -x ${HTTP_PROXY} -O ${LYREBIRD_TARBALL_URL} &&\
		curl -x ${HTTP_PROXY} -O ${MEEK_TARBALL_URL} &&\
		curl -x ${HTTP_PROXY} -O ${SNOWFLAKE_TARBALL_URL} ;\
	else \
		echo "direct curl connection" && \
		curl -O ${TOR_TARBALL_URL} && \
		curl -O ${TOR_TARBALL_URL}.sha256sum && \
		curl -O ${TOR_TARBALL_URL}.sha256sum.asc \
		curl -O ${LYREBIRD_TARBALL_URL} && \
		curl -O ${MEEK_TARBALL_URL} && \
		curl -O ${SNOWFLAKE_TARBALL_URL} ;\
    fi

RUN rm -f ~/.gnupg/public-keys.d/pubring.db.lock

RUN gpg --verify ${TOR_TARBALL}.sha256sum.asc ${TOR_TARBALL}.sha256sum && \
	sha256sum -c ${TOR_TARBALL}.sha256sum

#build
FROM source AS builder

RUN apk add --no-cache \
	git \
	make \
	gcc \
	g++ \
	libtool \
	autoconf \
	automake \
	pkgconfig \
	linux-headers \
	go \
	ca-certificates \
	python3 \
	py3-pip \
	musl-dev \
	openssl \
	openssl-dev \
	libevent \
	libevent-dev \
	zstd \
	zstd-dev \
	zlib \
	zlib-dev

RUN <<EOT
tar xfz ${TOR_TARBALL}
cd tor-${TOR_VERSION} || exit 1
./configure \
	--enable-gpl \
	--prefix=/usr/ \
	--sysconfdir=/etc \
	--localstatedir=/var \
	--disable-asciidoc \
	--disable-html-manual \
	--disable-manpage \
	--disable-module-relay \
	--disable-unittests
make -j$(nproc) install-strip
cd .. || exit 1
EOT

RUN <<EOT
tar -xvf ${LYREBIRD_TARBALL}
cd lyrebird-lyrebird-${LYREBIRD_VERSION} || exit 1
make build -e VERSION=${LYREBIRD_VERSION}
cp ./lyrebird /usr/local/bin
cd .. || exit 1
EOT

RUN <<EOT
tar -xvf ${MEEK_TARBALL}
cd meek-v${MEEK_VERSION}/meek-client || exit 1
make meek-client
cp ./meek-client /usr/local/bin
cd .. || exit 1
EOT

RUN <<EOT
tar -xvf ${SNOWFLAKE_TARBALL}
cd snowflake-v${SNOWFLAKE_VERSION}/client || exit 1
go get -v
go build -v -o /usr/local/bin/snowflake-client .
cd .. || exit 1
EOT

RUN <<EOT
cp -rv /go/bin /usr/local/bin
rm -rf /go
rm -rf /tmp/*
EOT

#artifacts
FROM scratch AS artifacts
COPY --from=builder /etc/tor/ /etc/tor/
COPY --from=builder /usr/bin/tor /usr/bin/tor
COPY --from=builder /usr/share/tor /usr/share/tor
COPY --from=builder /usr/local/bin/lyrebird /usr/local/bin/lyrebird
COPY --from=builder /usr/local/bin/meek-client /usr/local/bin/meek-client
COPY --from=builder /usr/local/bin/snowflake-client /usr/local/bin/snowflake-client
#run
FROM base AS runner
EXPOSE 9050/tcp 9051/tcp
ARG MEEK_VERSION
ENV MEEK_VERSION=${MEEK_VERSION}
RUN mkdir --mode=2700 /etc/tor /etc/tor/run

COPY --from=artifacts /etc/tor/ /etc/tor/
COPY --from=artifacts /usr/bin/tor /usr/bin/tor
COPY --from=artifacts /usr/share/tor /usr/share/tor
COPY --from=artifacts /usr/local/bin/lyrebird /usr/local/bin/lyrebird
COPY --from=artifacts /usr/local/bin/meek-client /usr/local/bin/meek-client
COPY --from=artifacts /usr/local/bin/snowflake-client /usr/local/bin/snowflake-client

COPY entrypoint.sh /entrypoint.sh
COPY start_tor.sh /start_tor.sh
COPY generate_hashed_control_password.sh /generate_hashed_control_password.sh
COPY torrc /etc/tor/torrc
RUN chmod +x /entrypoint.sh && chmod +x /start_tor.sh && chmod +x /generate_hashed_control_password.sh && chmod -R +x /usr/local/bin/
WORKDIR /var/lib/tor
ENTRYPOINT [ "/entrypoint.sh" ]