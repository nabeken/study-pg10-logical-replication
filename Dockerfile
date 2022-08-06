FROM postgres:10.21

COPY postgresql.conf /etc/postgresql-local.conf
COPY replace-postgresql-config.sh /docker-entrypoint-initdb.d/
