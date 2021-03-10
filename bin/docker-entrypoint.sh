#!/bin/sh
set -e

# Make sure common volume points have the app permission
chown -fR spotlight:spotlight /spotlight/app/tmp
chown -fR spotlight:spotlight /spotlight/app/public

mkdir -p /spotlight/app/tmp/pids
rm -f /spotlight/app/tmp/pids/*

while ! bundle exec rake spotlight:db_ready
do
  echo "waiting for db migrations"
  sleep 5s
done

# Run the command
exec "$@"
