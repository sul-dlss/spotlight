#!/bin/sh
set -e

wait_for () {
  host=$(printf "%s\n" "$1"| cut -d : -f 1)
  port=$(printf "%s\n" "$1"| cut -d : -f 2)

  shift 1

  while ! nc -z "$host" "$port"
  do
    echo "waiting for $host:$port"
    sleep 1
  done
}

wait_for "$DB_HOST:$DB_PORT"
wait_for "$SOLR_HOST:$SOLR_PORT"

bundle exec rails db:migrate
if [ "${RAILS_ENV}" = "development" ]; then
  bundle exec rails db:seed
  bundle exec rake spotlight:seed_admin_user
fi
