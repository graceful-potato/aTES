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
until [[ $(curl -s -o /dev/null -w "%{http_code}" http://nginx:8081) -ne "502" ]]; do
  sleep 1
done

# Wait for rails app
# TODO: extract port into env variable
until nc -z task-tracker 3001; do
  sleep 1
done

exec "$@"
