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
