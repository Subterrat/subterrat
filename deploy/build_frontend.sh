#!/bin/sh
set -eu

image="${IMAGE:-}"
maps_key="${GOOGLE_MAPS_API_KEY:-}"

if [ -z "$image" ]; then
  echo "IMAGE must contain the frontend container tag" >&2
  exit 64
fi

if [ -z "$maps_key" ] || [ "$maps_key" = "YOUR_MAPS_API_KEY" ]; then
  echo "GOOGLE_MAPS_API_KEY must contain a real browser key" >&2
  exit 64
fi

exec docker build \
  --file deploy/frontend.Dockerfile \
  --build-arg "GOOGLE_MAPS_API_KEY=$maps_key" \
  --tag "$image" \
  .
