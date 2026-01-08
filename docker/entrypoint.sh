#!/bin/sh
set -eu

PORT="${PORT:-4567}"
CRON_TZ="${TZ:-UTC}"
AUTH_KEY="${AUTH_KEY:-}"
app_pid=""

term_handler() {
  if [ -n "$app_pid" ] && kill -0 "$app_pid" 2>/dev/null; then
    kill -TERM "$app_pid" 2>/dev/null || true
    wait "$app_pid" 2>/dev/null || true
  fi
  exit 0
}

trap 'term_handler' TERM INT

if [ -z "$AUTH_KEY" ]; then
  echo "AUTH_KEY is not set" >&2
  exit 1
fi

CRON_FILE="/etc/cron.d/pixoo64-calendar"
cat > "$CRON_FILE" <<CRON_EOF
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
CRON_TZ=${CRON_TZ}
AUTH_KEY=${AUTH_KEY}
PORT=${PORT}
0 * * * * root /usr/local/bin/pixoo64-update >> /var/log/cron.log 2>&1
CRON_EOF

chmod 0644 "$CRON_FILE"
touch /var/log/cron.log

cron

"$@" &
app_pid=$!

/usr/local/bin/pixoo64-update --wait || true

wait "$app_pid"
