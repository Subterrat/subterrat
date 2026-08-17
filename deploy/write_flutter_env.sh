#!/bin/sh
set -eu

target_path="${1:-.env}"
maps_key="${GOOGLE_MAPS_API_KEY:-}"

if [ -z "$maps_key" ] || [ "$maps_key" = "YOUR_MAPS_API_KEY" ]; then
  echo "GOOGLE_MAPS_API_KEY must contain a real browser key" >&2
  exit 64
fi

umask 077
printf 'GOOGLE_MAPS_API_KEY=%s\n' "$maps_key" > "$target_path"
chmod 0644 "$target_path"
