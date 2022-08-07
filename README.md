# Studying the logical replication with PostgreSQL 10

## Setup roles

- `postgres` -- A super user (used for replication and its administrative work)
- `dbowner` -- A user who owns tables (used for database management)
- `app` -- A user that an application (pgbench) uses for read and write

**dbowner**:
```sh
docker compose exec publisher createuser --login --no-createrole --no-superuser --createdb dbowner
docker compose exec subscriber createuser --login --no-createrole --no-superuser --createdb dbowner
```

**app**:
```sh
docker compose exec publisher createuser --login --no-createrole --no-superuser --no-createdb --pwprompt app
docker compose exec subscriber createuser --login --no-createrole --no-superuser --no-createdb --pwprompt app
```

## Setup the publisher and subscriber

```
docker compose up --build publisher subscriber
```

## Setup pgbench

Let's create a database for benchmarking.

```
docker compose exec publisher createdb -U dbowner bench
docker compose exec publisher pgbench -U dbowner  -i -s 10 -q bench

docker compose exec publisher psql -U dbowner -c "GRANT ALL ON pgbench_accounts TO app;" bench
docker compose exec publisher psql -U dbowner -c "GRANT ALL ON pgbench_branches TO app;" bench
docker compose exec publisher psql -U dbowner -c "GRANT ALL ON pgbench_history TO app;" bench
docker compose exec publisher psql -U dbowner -c "GRANT ALL ON pgbench_tellers TO app;" bench

docker compose exec publisher pg_dump --schema-only --create -f /data/bench-schema.sql bench
```

Then, let's run the bench.

```
docker compose up bench
```

## Setup the logical replication

Replicate the schema on the subscriber:
```
docker compose exec subscriber psql -f /data/bench-schema.sql
```

Create a publisher on the publisher:
```
docker compose exec publisher psql bench

CREATE PUBLICATION bench FOR ALL TABLES;
select * from pg_replication_slots;
select * from pg_publication;
```

Create a subscription on the subscriber:
```
docker compose exec subscriber psql bench

CREATE SUBSCRIPTION bench
CONNECTION 'dbname=bench host=publisher user=postgres password=postgres'
PUBLICATION bench
;

SELECT * FROM pg_stat_subscription;
```

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
```

## Pause write

```sh
docker compose exec publisher psql -U dbowner -c "REVOKE ALL ON pgbench_accounts FROM app;" bench
docker compose exec publisher psql -U dbowner -c "REVOKE ALL ON pgbench_branches FROM app;" bench
docker compose exec publisher psql -U dbowner -c "REVOKE ALL ON pgbench_history FROM app;" bench
docker compose exec publisher psql -U dbowner -c "REVOKE ALL ON pgbench_tellers FROM app;" bench
```

## Grant write

```
docker compose exec publisher psql -U dbowner -c "GRANT ALL ON pgbench_accounts TO app;" bench
docker compose exec publisher psql -U dbowner -c "GRANT ALL ON pgbench_branches TO app;" bench
docker compose exec publisher psql -U dbowner -c "GRANT ALL ON pgbench_history TO app;" bench
docker compose exec publisher psql -U dbowner -c "GRANT ALL ON pgbench_tellers TO app;" bench
```
