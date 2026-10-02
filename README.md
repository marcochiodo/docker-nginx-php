
# Docker webserver Nginx PHP-FPM

[GitHub Project](https://github.com/marcochiodo/docker-nginx-php)  
[DockerHub Image](https://hub.docker.com/r/sigblue/nginx-php)  
Developed by [Marco Chiodo](https://www.marcochiodo.it/) 🇮🇹 | [Swiss Division](https://www.marcochiodo.ch/) 🇨🇭

## About

Based on Alpine image.  
Images are published for `linux/amd64` and `linux/arm64`.
Many extensions are already installed - see Dockerfile at `#Install packages`.  
Install extra extensions with:

```bash
apk add php{PHP_VERSION}-{EXT_NAME}
```

Example:

```bash
apk add php84-gd
```

## Layout

Scripts live in `bin/`:

- `bin/entrypoint.sh` → `/usr/local/bin/entrypoint.sh` (container CMD)
- `bin/entrypoint-legacy.sh` → `/etc/entrypoint.sh` (deprecated shim, prints WARNING and execs new path)
- `bin/healthcheck.sh` → `/usr/local/bin/healthcheck.sh` (HEALTHCHECK)
- `bin/composer-installer.sh` → `/var/www/composer-installer.sh`

Config files live in `config/` (`nginx.conf`, `fpm-pool.conf`, `php.ini`).

## Build

Images are built and published to Docker Hub only by GitHub Actions, never with a
manual `docker push`. Docker Hub does not merge architectures: a tag is an index
linking the amd64 and arm64 versions, created by buildx only when building with
`--platform linux/amd64,linux/arm64 --push`. A manual push of a locally built
image would replace that index with the local version only, and ARM users would
silently get the wrong image again. `build.sh` is for local testing only and
does not publish anything.

## Extension points

**Extra healthchecks.** Drop executable `*.sh` files in `/usr/local/share/healthcheck.d/`. `healthcheck.sh` runs the base `fpm-ping` probe then executes every script; any non-zero exit marks the container unhealthy.

```Dockerfile
COPY --chown=www --chmod=0755 my-check.sh /usr/local/share/healthcheck.d/my-check.sh
```

**Custom entrypoint.** Override `CMD` with your own script that performs setup, then `exec /usr/local/bin/entrypoint.sh "$@"` to start php-fpm + nginx.

## Runtime

```bash
docker run -it --rm \
 -v ${PWD}:/var/www/html \
 -v "./etc/nginx.conf":/etc/nginx/conf.d/extra.conf:ro \
 -v "./etc/default-server-nginx.conf":/etc/nginx/default-server.conf.d/extra.conf:ro \
 -v "./etc/php.ini":/etc/php/conf.d/www.ini:ro \
 -v "./etc/php-fpm.conf":/etc/php/php-fpm.d/z-custom.conf:ro \
 -e APP_ENV=development \
 -p 80:8080 \
 --name myapp \
 sigblue/nginx-php:84

```

Explore the running container with:

```bash
docker exec -it myapp sh
```

## Workdir example

> /public/index.php

```php
<?php

echo "Hello World";

```

> Dockerfile

```Dockerfile
FROM sigblue/nginx-php:84
ARG app_env=production
ENV APP_ENV=$app_env
COPY ./etc/default-server-nginx.conf /etc/nginx/default-server.conf.d/extra.conf
COPY ./etc/nginx.conf /etc/nginx/conf.d/extra.conf
COPY ./etc/php.ini /etc/php/conf.d/www.ini
COPY ./etc/php-fpm.conf /etc/php/php-fpm.d/z-custom.conf
COPY --chown=www . /var/www/html
RUN sh /var/www/composer-installer.sh
RUN php -c . composer.phar install -o --no-dev
RUN rm composer.phar composer.json composer.lock

```

> /etc/default-server-nginx.conf

```nginx
port_in_redirect off;
location /assets {
 expires 30d;
 alias /var/www/html/dist/assets;
 try_files $uri /index.php /index.html;
}

```

> /etc/nginx.conf

```nginx
server {
 listen [::]:8080;
 listen 8080;
 server_name mysite.it;
 rewrite ^/(.*)$ https://www.mysite.it/$1 permanent;
}

```

> /etc/php.ini

```ini
max_execution_time = ${MAX_EXECUTION_TIME:-60}
display_errors = ${DISPLAY_ERRORS:-0}
opcache.enable=${OPCACHE_ENABLE:-1}

```

> /etc/php-fpm.conf

```ini
[global]
;update global directives
[www]
;update pool directives

```
