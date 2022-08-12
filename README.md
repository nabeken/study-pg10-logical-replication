# Studying the logical replication with PostgreSQL 10

## Launch the publisher and subscriber

```
docker compose up --build publisher subscriber subscriber14
```

## Setup roles

- `postgres` -- A super user (used for replication and its administrative work)
- `app` -- A user that an application (pgbench) uses for read and write

**app**:
```sh
docker compose exec publisher createuser --login --no-createrole --no-superuser --no-createdb --pwprompt app
```

## Setup pgbench

Let's create a database for benchmarking.

```
docker compose exec publisher createdb bench
docker compose exec publisher pgbench -i -s 10 -q bench

cat <<EOF | docker compose exec --no-TTY publisher psql bench
GRANT ALL ON pgbench_accounts TO app;
GRANT ALL ON pgbench_branches TO app;
GRANT ALL ON pgbench_history TO app;
GRANT ALL ON pgbench_tellers TO app;
EOF

docker compose exec publisher pg_dump --schema-only --create -f /data/bench-schema.sql bench
docker compose exec publisher pg_dumpall --roles-only -f /data/roles.sql
```

## Setup the logical replication

Replicate the schema on the subscriber:
```
docker compose exec subscriber psql -f /data/roles.sql
docker compose exec subscriber psql -f /data/bench-schema.sql

docker compose exec subscriber14 psql -f /data/roles.sql
docker compose exec subscriber14 psql -f /data/bench-schema.sql
```

Create a publisher on the publisher:
```
cat << EOF | docker compose exec --no-TTY publisher psql bench
ALTER TABLE pgbench_history REPLICA IDENTITY FULL;

CREATE PUBLICATION bench FOR ALL TABLES;
select * from pg_replication_slots;
select * from pg_publication;
ALTER TABLE pgbench_history REPLICA IDENTITY FULL;

EOF
```

Create a subscription on the subscriber:
```
cat <<EOF | docker compose exec --no-TTY subscriber psql bench
CREATE SUBSCRIPTION bench
CONNECTION 'dbname=bench host=publisher user=postgres password=postgres'
PUBLICATION bench
;

SELECT * FROM pg_stat_subscription;
EOF

cat <<EOF | docker compose exec --no-TTY subscriber14 psql bench
CREATE SUBSCRIPTION bench14
CONNECTION 'dbname=bench host=publisher user=postgres password=postgres'
PUBLICATION bench
;

SELECT * FROM pg_stat_subscription;
EOF
```

Then, let's run the bench.

```
docker compose up bench
```

Please note that if you run the bench again, `pgbench_history` will be no longer identical across the cluster because `pgbench` issues `truncate` command against the history table, which won't be replicated to subscribers.

## How to confirm the latest WAL is applied to the subscriber?

TBD: how to read the following?

On the publisher:
```
SELECT *, pg_current_wal_lsn() from pg_replication_slots;
 slot_name |  plugin  | slot_type | datoid | database | temporary | active | active_pid | xmin | catalog_xmin | restart_lsn | confirmed_flush_lsn | pg_current_wal_lsn
-----------+----------+-----------+--------+----------+-----------+--------+------------+------+--------------+-------------+---------------------+--------------------
 bench     | pgoutput | logical   |  16384 | bench    | f         | t      |        114 |      |       128926 | 0/1C940520  | 0/1C940558          | 0/1C940558
(1 row)
```

On the subscriber:
```
SELECT * FROM pg_stat_subscription;
bench=# SELECT * FROM pg_stat_subscription;
 subid | subname | pid | relid | received_lsn |      last_msg_send_time      |     last_msg_receipt_time     | latest_end_lsn |       latest_end_time
-------+---------+-----+-------+--------------+------------------------------+-------------------------------+----------------+------------------------------
 16403 | bench   | 106 |       | 0/13A48328   | 2022-08-06 06:59:10.65531+00 | 2022-08-06 06:59:10.655399+00 | 0/13A48328     | 2022-08-06 06:59:10.65531+00
(1 row)
```

## Monitor

On the publisher:
```sh
docker compose exec publisher bash -c "while true; do psql bench -c 'SELECT *, pg_current_wal_lsn() from pg_replication_slots;'; sleep 1; done"
```

On the subscriber:
```sh
docker compose exec subscriber bash -c "while true; do psql bench -c 'SELECT * from pg_stat_subscription;'; sleep 1; done"
docker compose exec subscriber14 bash -c "while true; do psql bench -c 'SELECT * from pg_stat_subscription;'; sleep 1; done"
```

## Pause write

```sh
cat <<EOF | docker compose exec --no-TTY publisher psql -U postgres
REVOKE CONNECT ON DATABASE bench FROM PUBLIC;

SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE
      pid <> pg_backend_pid()
  AND usename <> 'postgres' -- skip replication slots
  AND datname = 'bench'
;
EOF
```

## Grant write

```
docker compose exec publisher psql -c "GRANT CONNECT ON DATABASE bench TO PUBLIC;" bench
```
