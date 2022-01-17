FROM rabbitmq:alpine as rabbitmq
FROM redis:alpine as redis
FROM memcached:alpine as memcached
FROM zulip/zulip-postgresql:10

#==============================================================================
# Memcached
#==============================================================================

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN addgroup -g 11211 memcache && adduser -D -u 11211 -G memcache memcache

# ensure SASL's "libplain.so" is installed as per https://github.com/memcached/memcached/wiki/SASLHowto
RUN apk add --no-cache libsasl

COPY --from=memcached /usr/lib/libevent-2.1.so.7.0.1          /usr/lib/libevent-2.1.so.7
COPY --from=memcached /usr/lib/libevent_core-2.1.so.7.0.1     /usr/lib/libevent_core-2.1.so.7
COPY --from=memcached /usr/lib/libevent_extra-2.1.so.7.0.1    /usr/lib/libevent_extra-2.1.so.7
COPY --from=memcached /usr/lib/libevent_openssl-2.1.so.7.0.1  /usr/lib/libevent_openssl-2.1.so.7
COPY --from=memcached /usr/lib/libevent_pthreads-2.1.so.7.0.1 /usr/lib/libevent_pthreads-2.1.so.7
COPY --from=memcached /usr/lib/libgdbm.so.6.0.0               /usr/lib/libgdbm.so.6
COPY --from=memcached /usr/lib/libgdbm_compat.so.4.0.0        /usr/lib/libgdbm_compat.so.4
COPY --from=memcached /usr/local/bin/memcached                /usr/local/bin/
COPY --from=memcached /usr/lib/libevent_openssl-2.1.so.7.0.1  /usr/lib/libevent_openssl-2.1.so.7
COPY --from=memcached /usr/lib/libevent_openssl-2.1.so.7.0.1  /usr/lib/libevent_openssl-2.1.so.7
COPY --from=memcached /usr/lib/libevent_openssl-2.1.so.7.0.1  /usr/lib/libevent_openssl-2.1.so.7

#==============================================================================
# RabbitMQ
# https://github.com/docker-library/rabbitmq/blob/master/Dockerfile-alpine.template
#==============================================================================

ENV RABBITMQ_LOGS=-
ENV RABBITMQ_DATA_DIR=/data/rabbitmq
ENV RABBITMQ_HOME=/opt/rabbitmq

RUN addgroup -g 5672 rabbitmq && adduser -S -h "$RABBITMQ_DATA_DIR" -u 5672 -G rabbitmq rabbitmq
RUN mkdir -p "$RABBITMQ_DATA_DIR" /etc/rabbitmq /etc/rabbitmq/conf.d /tmp/rabbitmq-ssl /var/log/rabbitmq /var/lib/rabbitmq; \
	  chown -fR rabbitmq:rabbitmq "$RABBITMQ_DATA_DIR" /etc/rabbitmq /etc/rabbitmq/conf.d /tmp/rabbitmq-ssl /var/log/rabbitmq; \
	  chmod 777 "$RABBITMQ_DATA_DIR" /etc/rabbitmq /etc/rabbitmq/conf.d /tmp/rabbitmq-ssl /var/log/rabbitmq /var/lib/rabbitmq
RUN ln -sf "$RABBITMQ_DATA_DIR/.erlang.cookie" /root/.erlang.cookie; chown -R rabbitmq:rabbitmq /root/

RUN apk add --no-cache procps

COPY --from=rabbitmq /opt/rabbitmq /opt/rabbitmq
COPY --from=rabbitmq /etc/rabbitmq /etc/rabbitmq
COPY --from=rabbitmq /usr/local/lib/erlang /usr/local/lib/erlang
COPY --from=rabbitmq /usr/local/etc/ssl /usr/local/etc/ssl
COPY --from=rabbitmq --chown=rabbitmq:rabbitmq /etc/rabbitmq/conf.d/ /etc/rabbitmq/conf.d/

ENV PATH=/usr/local/lib/erlang/bin/:$RABBITMQ_HOME/sbin:$PATH

#==============================================================================
# Redis
#==============================================================================

RUN addgroup -g 6379 redis && adduser -D -u 6379 -G redis redis

RUN apk add --no-cache \
# add tzdata for https://github.com/docker-library/redis/issues/138
		tzdata

COPY --from=redis /usr/local/bin/redis-server /usr/local/bin/redis-server

RUN mkdir -p /data/redis && chown redis:redis /data/redis

#==============================================================================
# MAIN
#==============================================================================

VOLUME /data

RUN apk add supervisor
COPY supervisord.conf /
RUN wget https://github.com/coderanger/supervisor-stdout/archive/refs/heads/master.zip -O /tmp/supervisor-stdout.zip; \
    unzip /tmp/supervisor-stdout.zip -d /opt/; \
    cd /opt/supervisor-stdout-master/; python3 setup.py install; \
    rm -rf /tmp/supervisor-stdout.zip /opt/supervisor-stdout-master/

COPY docker-entrypoint.sh /

ENTRYPOINT [ "/docker-entrypoint.sh" ]
CMD [ "/usr/bin/supervisord", "-c", "/supervisord.conf" ]

