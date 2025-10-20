FROM php:8.4-fpm-alpine

RUN set -eux; \
    apk add --no-cache nginx supervisor icu-dev libzip-dev oniguruma bash curl tzdata; \
    docker-php-ext-install intl pdo pdo_mysql opcache

RUN { \
  echo 'opcache.enable=1'; \
  echo 'opcache.enable_cli=0'; \
  echo 'opcache.validate_timestamps=0'; \
  echo 'opcache.jit_buffer_size=32M'; \
  echo 'memory_limit=256M'; \
  echo 'expose_php=0'; \
} > /usr/local/etc/php/conf.d/prod.ini

WORKDIR /var/www/html

COPY . /var/www/html/

# ===== DEBUG: upewnij się, że .env trafił do obrazu =====
RUN set -eux; \
    ls -la /var/www/html | sed -n '1,200p'; \
    test -f /var/www/html/.env || (echo "ERROR: .env not found in image" && exit 1); \
    php -r "echo 'PHP sees .env: '; var_dump(is_file('/var/www/html/.env'), is_readable('/var/www/html/.env'));"
# =========================================================

RUN set -eux; \
    mkdir -p /run/nginx \
             /var/lib/nginx/tmp/client_body \
             /var/lib/nginx/tmp/proxy \
             /var/lib/nginx/tmp/fastcgi \
             /var/log/nginx; \
    chown -R nginx:nginx /run/nginx /var/lib/nginx /var/log/nginx; \
    mkdir -p /var/www/html/var; \
    chown -R www-data:www-data /var/www/html/var

COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/supervisord.conf /etc/supervisord.conf

EXPOSE 8083

HEALTHCHECK --interval=300s --timeout=15s --start-period=30s \
  CMD wget -qO- http://127.0.0.1:8083/health || exit 1

CMD ["/usr/bin/supervisord","-c","/etc/supervisord.conf"]
