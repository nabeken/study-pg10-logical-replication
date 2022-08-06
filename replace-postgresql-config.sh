#!/bin/sh

echo "Copying the local postgresql.conf..." >&2

cp /etc/postgresql-local.conf /var/lib/postgresql/data/postgresql.conf
