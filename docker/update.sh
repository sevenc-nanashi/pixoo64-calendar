#!/bin/sh
set -eu

PORT="${PORT:-4567}"
AUTH_KEY="${AUTH_KEY:-}"

if [ -z "$AUTH_KEY" ]; then
  echo "AUTH_KEY is not set" >&2
  exit 1
fi

wait_for=0
if [ "${1:-}" = "--wait" ]; then
  wait_for=1
fi

if [ "$wait_for" -eq 1 ]; then
  i=0
  while [ "$i" -lt 30 ]; do
    if curl -fsS -H "Authorization: ${AUTH_KEY}" "http://localhost:${PORT}/" >/dev/null; then
      break
    fi
    i=$((i + 1))
    sleep 1
  done
fi

curl -fsS -X POST -H "Authorization: ${AUTH_KEY}" "http://localhost:${PORT}/update" >/dev/null
