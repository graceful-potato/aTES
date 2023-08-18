#!/bin/sh
set -e

if [ -f tmp/pids/server.pid ]; then
  rm -f tmp/pids/server.pid;
fi

until PGPASSWORD=$DATABASE_PASSWORD psql -h "$DATABASE_HOST" -U "$DATABASE_USER" -d "postgres" -c '\q'; do
  echo "Postgres is unavailable - sleeping"
  sleep 1
done

until nc -z kafka 9092; do
    echo "Kafka is unavailable - sleeping"
    sleep 1
done

DATABASE_EXISTS=$(PGPASSWORD=$DATABASE_PASSWORD psql -h "$DATABASE_HOST" -U "$DATABASE_USER" -tAc "SELECT 1 FROM pg_database WHERE datname='${DATABASE_NAME}_${RAILS_ENV}'")
if [ "$DATABASE_EXISTS" = "1" ]; then
  echo "Database exists"
else
  rails db:setup
fi

exec "$@"
