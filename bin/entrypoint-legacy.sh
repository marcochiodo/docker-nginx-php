#!/bin/sh
echo "WARNING: /etc/entrypoint.sh is deprecated. Use /usr/local/bin/entrypoint.sh" >&2
exec /usr/local/bin/entrypoint.sh "$@"
