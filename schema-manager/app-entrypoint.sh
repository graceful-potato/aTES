#!/bin/sh
set -e

# Wait for kafka
until nc -z kafka 9092; do
  sleep 1
done

# Wait for schema registry
until nc -z schema-registry 8081; do
  sleep 1
done

exec "$@"
