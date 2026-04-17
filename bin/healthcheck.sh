#!/bin/sh
# Base healthcheck + run any extra checks dropped in /usr/local/share/healthcheck.d/*.sh

set -e

# Base check: php-fpm ping via nginx
curl --silent --fail --max-time 5 http://127.0.0.1:8080/fpm-ping > /dev/null

# Run extra checks if any
if [ -d /usr/local/share/healthcheck.d ]; then
    for check in /usr/local/share/healthcheck.d/*.sh; do
        [ -f "${check}" ] || continue
        sh "${check}" || exit 1
    done
fi

exit 0
