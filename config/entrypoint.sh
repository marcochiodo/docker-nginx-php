#!/usr/bin/env sh

# Start php-fpm in background (force foreground mode)
php-fpm -F &
PHP_PID=$!

# Wait for php-fpm to be ready (socket created)
echo "Waiting for php-fpm to be ready..."
TIMEOUT=30
COUNT=0
while [ ! -S /run/php-fpm.sock ] && [ $COUNT -lt $TIMEOUT ]; do
    sleep 0.1
    COUNT=$((COUNT + 1))
done

if [ ! -S /run/php-fpm.sock ]; then
    echo "ERROR: php-fpm socket not ready after ${TIMEOUT}s"
    exit 1
fi

echo "php-fpm is ready, starting nginx..."

# Start nginx in background
nginx -g 'daemon off;' &
NGINX_PID=$!

echo "nginx is ready"

# Function to check if process is still running
is_running() {
    kill -0 "$1" 2>/dev/null
}

# Wait for any process to exit
while is_running $PHP_PID && is_running $NGINX_PID; do
    sleep 5
done

# Get exit code of the failed process
if ! is_running $PHP_PID; then
    echo "php-fpm exited, stopping container..."
    wait $PHP_PID
    exit $?
else
    echo "nginx exited, stopping container..."
    wait $NGINX_PID
    exit $?
fi