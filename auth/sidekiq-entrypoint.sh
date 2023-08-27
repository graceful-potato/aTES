#!/bin/sh
set -e

# Wait for postgres
until PGPASSWORD=$DATABASE_PASSWORD psql -h "$DATABASE_HOST" -U "$DATABASE_USER" -d "postgres" -c '\q'; do
  sleep 1
done

# Wait for redis
until nc -z redis 6379; do
  sleep 1
done

# Wait for kafka
until nc -z kafka 9092; do
  sleep 1
done

# Wait for schema registry
until nc -z schema-registry 8081; do
  sleep 1
done

# Wait for roda app
# TODO: extract port into env variable
until nc -z auth 3000; do
  sleep 1
done

exec "$@"
