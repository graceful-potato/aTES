#!/bin/sh
set -e

# Wait for kafka
until nc -z kafka 9092; do
  sleep 1
done

# Wait for schema registry
until [[ $(curl -s -o /dev/null -w "%{http_code}" http://nginx:8081) -ne "502" ]]; do
  sleep 1
done

exec "$@"
