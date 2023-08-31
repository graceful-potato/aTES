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

# Create and initilize db when running container first time.
DATABASE_EXISTS=$(PGPASSWORD=$DATABASE_PASSWORD psql -h "$DATABASE_HOST" -U "$DATABASE_USER" -tAc "SELECT 1 FROM pg_database WHERE datname='${DATABASE_NAME}_${RACK_ENV}'")
if [ "$DATABASE_EXISTS" != "1" ]; then
  rake db:setup
fi

exec "$@"
