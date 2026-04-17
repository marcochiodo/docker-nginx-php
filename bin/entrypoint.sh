#!/usr/bin/env sh

# Function to check if process is still running
is_running() {
    kill -0 "$1" 2>/dev/null
}

# Graceful shutdown handler
shutdown() {
    echo "Shutting down gracefully..."

    # Stop nginx first (inverse of startup order)
    if is_running $NGINX_PID; then
        echo "Stopping nginx..."
        kill -QUIT $NGINX_PID 2>/dev/null
        wait $NGINX_PID 2>/dev/null
    fi

    # Then stop php-fpm
    if is_running $PHP_PID; then
        echo "Stopping php-fpm..."
        kill -QUIT $PHP_PID 2>/dev/null
        wait $PHP_PID 2>/dev/null
    fi

    exit 0
}

# Trap SIGTERM and SIGINT
trap shutdown TERM INT

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

# Wait for any process to exit
while is_running $PHP_PID && is_running $NGINX_PID; do
    sleep 5
done

# If we exit the loop, one process died unexpectedly
if ! is_running $PHP_PID; then
    echo "php-fpm exited unexpectedly, stopping container..."
    kill -QUIT $NGINX_PID 2>/dev/null
    wait $NGINX_PID 2>/dev/null
    exit 1
else
    echo "nginx exited unexpectedly, stopping container..."
    kill -QUIT $PHP_PID 2>/dev/null
    wait $PHP_PID 2>/dev/null
    exit 1
fi