# Studying the logical replication with PostgreSQL 10

## Setup the publisher

```
docker compose up --build publisher
```

## Setup the subscriber

```
docker compose up --build subscriber
```

## Setup pgbench

Let's create a database for benchmarking.

```
docker compose exec publisher createdb bench
docker compose exec publisher pgbench  -i -s 100 -q bench
```

Then, let's run the bench.

```
docker compose up bench
```
