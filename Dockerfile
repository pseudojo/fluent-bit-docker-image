FROM debian:stretch as builder

# Fluent Bit version
ENV FLB_MAJOR 1
ENV FLB_MINOR 0
ENV FLB_PATCH 5
ENV FLB_VERSION 1.0.5

ENV DEBIAN_FRONTEND noninteractive

ENV FLB_TARBALL http://github.com/fluent/fluent-bit/archive/v$FLB_VERSION.zip
RUN mkdir -p /fluent-bit/bin /fluent-bit/etc /fluent-bit/log /tmp/fluent-bit-master/

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential \
      cmake \
      make \
      wget \
      unzip \
      libssl1.0-dev \
      libasl-dev \
      libsasl2-dev \
      pkg-config \
      libsystemd-dev \
      zlib1g-dev \
      ca-certificates \
    && wget -O "/tmp/fluent-bit-${FLB_VERSION}.zip" ${FLB_TARBALL} \
    && cd /tmp && unzip "fluent-bit-$FLB_VERSION.zip" \
    && cd "fluent-bit-$FLB_VERSION"/build/ \
    && rm -rf /tmp/fluent-bit-$FLB_VERSION/build/*

WORKDIR /tmp/fluent-bit-$FLB_VERSION/build/
RUN cmake -DFLB_DEBUG=On \
          -DFLB_TRACE=Off \
          -DFLB_JEMALLOC=On \
          -DFLB_TLS=On \
          -DFLB_SHARED_LIB=Off \
          -DFLB_EXAMPLES=Off \
          -DFLB_HTTP_SERVER=On \
          -DFLB_IN_SYSTEMD=On \
          -DFLB_OUT_KAFKA=On ..

RUN make -j $(getconf _NPROCESSORS_ONLN)
RUN install bin/fluent-bit /fluent-bit/bin/

# Configuration files
COPY fluent-bit.conf \
     parsers.conf \
     parsers_java.conf \
     parsers_extra.conf \
     parsers_openstack.conf \
     parsers_cinder.conf \
     plugins.conf \
     /fluent-bit/etc/

# use centos instead of distroless image; gcr.io/distroless/cc
FROM centos:7
MAINTAINER Hyungu Cho <pseudojo.1989@gmail.com>
LABEL Description="Fluent Bit docker image with centos 7.6.1810" Vendor="Fluent Organization" Version="1.0.5-centos7"

RUN yum -y install vim

COPY --from=builder /usr/lib/x86_64-linux-gnu/*sasl* /usr/lib64/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libz* /usr/lib64/
COPY --from=builder /lib/x86_64-linux-gnu/libz* /lib64/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libssl.so* /usr/lib64/
COPY --from=builder /usr/lib/x86_64-linux-gnu/libcrypto.so* /usr/lib64/
# These below are all needed for systemd
COPY --from=builder /lib/x86_64-linux-gnu/libsystemd* /lib64/
COPY --from=builder /lib/x86_64-linux-gnu/libselinux.so* /lib64/
COPY --from=builder /lib/x86_64-linux-gnu/liblzma.so* /lib64/
COPY --from=builder /usr/lib/x86_64-linux-gnu/liblz4.so* /usr/lib64/
COPY --from=builder /lib/x86_64-linux-gnu/libgcrypt.so* /lib64/
COPY --from=builder /lib/x86_64-linux-gnu/libpcre.so* /lib64/
COPY --from=builder /lib/x86_64-linux-gnu/libgpg-error.so* /lib64/

COPY --from=builder /fluent-bit /fluent-bit

#
EXPOSE 2020

# Entry point
CMD ["/fluent-bit/bin/fluent-bit", "-c", "/fluent-bit/etc/fluent-bit.conf"]
