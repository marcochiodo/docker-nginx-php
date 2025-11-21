ARG ALPINE_VERSION=3.20

FROM alpine:$ALPINE_VERSION

# 82, 83 ...
ARG V

# make sure you can use HTTPS
RUN apk update


# Install packages
RUN apk --no-cache add ca-certificates php$V-fpm php$V \
    php$V-apcu php$V-intl php$V-opcache php$V-zip php$V-curl \
    php$V-openssl php$V-phar php$V-mbstring php$V-xml php$V-simplexml php$V-xmlwriter php$V-dom php$V-ctype php$V-iconv \
    php$V-pdo php$V-pdo_sqlite php$V-sqlite3 \
    php$V-sodium \
    nginx curl

RUN [ ! -e "/usr/bin/php" ] && ln -s /usr/bin/php$V /usr/bin/php || true
RUN [ ! -e "/usr/sbin/php-fpm" ] && ln -s /usr/sbin/php-fpm$V /usr/sbin/php-fpm || true

RUN apk --no-cache add shadow

#RUN apk --no-cache add supervisor

# Configure nginx
COPY config/nginx.conf /etc/nginx/nginx.conf
RUN mkdir -p /etc/nginx/default-server.conf.d

# Configure PHP-FPM
RUN ln -sf /etc/php$V /etc/php
COPY config/fpm-pool.conf /etc/php/php-fpm.d/www.conf
COPY config/php.ini /etc/php/conf.d/custom.ini

# Configure supervisord
#COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN addgroup --gid "1000" "www"
RUN adduser --disabled-password --gecos "" --home "/var/www" --ingroup "www" --no-create-home --uid "1000" www

# Setup document root
RUN mkdir -p /var/www/html
RUN chown www:www -R /var/www

COPY --chown=www config/entrypoint.sh /etc/entrypoint.sh
#RUN sed -i "s/php-fpm/php-fpm${V}/g" /etc/entrypoint.sh
RUN chmod +x /etc/entrypoint.sh

COPY --chown=www ./composer-installer.sh /var/www/

# Make sure files/folders needed by the processes are accessable when they run under the nobody user
RUN chown www:www -R /var/www /run /var/lib/nginx /var/log/nginx

# Switch to use a non-root user from here on
USER www

# Add application
WORKDIR /var/www/html
COPY --chown=www src/ /var/www/html/

# Let supervisord start nginx & php-fpm
#CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:8080/fpm-ping

ENTRYPOINT ["/bin/sh"]
CMD ["/etc/entrypoint.sh"]
