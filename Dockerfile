FROM php:8.4-fpm-alpine

# system + ext
RUN set -eux; \
    apk add --no-cache nginx supervisor icu-dev libzip-dev oniguruma bash curl tzdata; \
    docker-php-ext-install intl pdo pdo_mysql opcache

# php.ini prod
RUN { \
  echo 'opcache.enable=1'; \
  echo 'opcache.enable_cli=0'; \
  echo 'opcache.validate_timestamps=0'; \
  echo 'opcache.jit_buffer_size=32M'; \
  echo 'memory_limit=256M'; \
  echo 'expose_php=0'; \
} > /usr/local/etc/php/conf.d/prod.ini

WORKDIR /var/www/html

# >>> CI ma wgrać gotowe pliki tutaj (vendor, public, var/cache/prod, itd.)
COPY artifact/ /var/www/html/

# Nginx i katalogi tymczasowe + prawa dla php-fpm (www-data) do var/
RUN set -eux; \
    mkdir -p /run/nginx \
             /var/lib/nginx/tmp/client_body \
             /var/lib/nginx/tmp/proxy \
             /var/lib/nginx/tmp/fastcgi \
             /var/log/nginx; \
    chown -R nginx:nginx /run/nginx /var/lib/nginx /var/log/nginx; \
    mkdir -p /var/www/html/var; \
    chown -R www-data:www-data /var/www/html/var

# konfiguracja
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/supervisord.conf /etc/supervisord.conf

# NIE ustawiamy USER — master nginx i supervisord działają jako root (workery nginx spadną do usera `nginx`)
EXPOSE 8083

# healthcheck (nginx -> php -> symfony)
HEALTHCHECK --interval=30s --timeout=3s --start-period=15s \
  CMD wget -qO- http://127.0.0.1:8083/health || exit 1

CMD ["/usr/bin/supervisord","-c","/etc/supervisord.conf"]
