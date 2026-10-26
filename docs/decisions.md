# Decisions

## 001 — Source of the departures for dbt (2026-10-24)

**Status**: Implemented (branch `feat/duckdb`)

**Context**: The silver layer of [irail-ingestion](https://github.com/sanneau/irail-ingestion) is a set of
Parquet files (`data/silver/departures/date=YYYY-MM-DD/`). dbt only reads tables from the database it is
connected to, so we need a way for dbt to read the silver data and build the Data Vault and the star schema
from it.

**Options considered**:
- **A.** A Python job loads all the silver files into a raw PostgreSQL table (`raw.departures`, insert-only).
- **B.** Keep `stg_departure` as the source. It is truncated on every load and only holds the last loaded day.
- **C.** Switch to `dbt-duckdb`: DuckDB reads the Parquet files directly.

**Decision**: C

**Reasons**:
1. **Rebuild in one command.** The Parquet files are the source of truth and survive a
   `docker compose down -v`. With C, `dbt build` rebuilds every model from all the days; there is no load step
   to run first (A) and no day-by-day reload (B).
2. **Same pattern as a lakehouse.** On Databricks, SQL runs directly on files (Delta/Parquet) without copying
   them into a database first. DuckDB reproduces this pattern locally.
3. **No new tool.** DuckDB already reads the silver files for the analyses in irail-ingestion. Parquet is a
   columnar format, so queries only read the columns they need.

**Accepted drawbacks**:
1. **The dbt models no longer run on PostgreSQL.** The current sources (`public.stg_station`,
   `public.fact_departure`) must be replaced by the silver files, and the results are queried with DuckDB
   instead of pgAdmin. The PostgreSQL star schema and Data Vault stay in irail-ingestion.
2. **More setup.** A new adapter (`dbt-duckdb`), a new `profiles.yml` target, and a few SQL details that
   differ between PostgreSQL and DuckDB.
3. **Local only.** DuckDB is a single file with one writer at a time, not a shared server. In production this
   role would be played by Databricks or Snowflake.

## 002 — Departures seen on both sides of midnight UTC (2026-10-26)

**Status**: Accepted

**Context**: The silver job of irail-ingestion runs one day at a time (`irail-transform <day>`): it reads the
bronze of that day only, keeps the latest snapshot of each departure, and writes one partition
(`date=YYYY-MM-DD`, the UTC day of the collection). Since 2026-10-23, the collection runs 24 hours a day.
A departure collected at 23:57 UTC and again at 00:12 UTC is therefore kept in **two** partitions, and the
grain test of `stg_departures` (departure station, vehicle, scheduled time) failed with 5 duplicates.
Before 2026-10-23, the collection never ran around midnight UTC, so the bug existed but never showed.

**Options considered**:
- **A.** Fix it in the silver job: when transforming a day, also read the bronze of the previous day.
- **B.** Fix it in `stg_departures`: keep only the latest collection of each departure, across all days
  (`QUALIFY row_number() OVER (PARTITION BY <grain> ORDER BY snapshot_at DESC) = 1`).
- **C.** Lower the grain test to a warning.

**Decision**: B

**Reasons**:
1. **The silver job stays simple and idempotent.** One day of bronze gives one partition of silver; a day can
   be rerun alone, without depending on the day before.
2. **Staging is the cleaning layer.** dbt sees all the days at once, so it is the first place where a
   duplicate across days can be detected and removed. Deduplicating in staging is a common dbt practice.
3. **The latest collection is the most accurate.** It holds the final delay, a late cancellation or a
   platform change (example: a train at 4,200 s of delay at 23:56 UTC, back to 0 at 00:06 UTC).

C was rejected: it hides the problem, and every mart would count these departures twice.

**Accepted drawbacks**:
1. **The silver layer is not unique on the grain.** Any other reader of the silver files must deduplicate too,
   or read from dbt. The PostgreSQL loader of irail-ingestion is already protected: its
   `ON CONFLICT (departure_station_key, scheduled_at, vehicle_id) DO UPDATE` keeps the last day loaded.
   The DuckDB analyses that read the Parquet files directly are not.
2. **The deduplication needs all the days.** It is computed on every `dbt build`; with an incremental model
   later, the window must include the previous day.
