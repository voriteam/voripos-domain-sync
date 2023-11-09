FROM alpine:latest AS fswatch

RUN apk add --no-cache autoconf alpine-sdk

RUN rm /usr/include/sys/inotify.h
RUN wget https://github.com/emcrisostomo/fswatch/releases/download/1.17.1/fswatch-1.17.1.tar.gz \
    && tar -xzvf fswatch-1.17.1.tar.gz \
    && cd fswatch-1.17.1 \
    && ./configure \
    && make \
    && make install \
    && rm -rf /fswatch-1.17.1

FROM alpine:latest

# Install fswatch
COPY --from=fswatch /usr/local/bin/fswatch /usr/local/bin/fswatch
COPY --from=fswatch /usr/local/lib/libfswatch.so* /usr/local/lib/

# LiteFS setup
RUN apk add --no-cache autoconf alpine-sdk bash fuse3 sqlite ca-certificates
COPY --from=flyio/litefs:0.5 /usr/local/bin/litefs /usr/local/bin/litefs
COPY docker-build-resources/etc/litefs.yml /etc/litefs.yml

ENV LITEFS_DB_DIRECTORY=/litefs
ENV LITEFS_INTERNAL_DATA_DIRECTORY=/var/lib/litefs

WORKDIR /
COPY docker-build-resources/opentelemetry-shell /opentelemetry-shell
COPY docker-build-resources/sync.sh /sync.sh

ENTRYPOINT litefs mount
