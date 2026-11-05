# sncb-dbt

## What is this?
dbt is a command-line tool that handles the T (Transform) part of an ELT pipeline.
The Extract and Load parts stay in Python, in [irail-ingestion](https://github.com/sanneau/irail-ingestion):
it calls the iRail API and writes the cleaned data as Parquet files (the silver layer).
This project reads those files directly with DuckDB and builds the staging views and the mart tables.
Why DuckDB: see [docs/decisions.md](docs/decisions.md).

## Why dbt?
- **Order**: dbt runs the models in the right order, based on their dependencies (`ref()` builds the DAG).
- **Less boilerplate**: each model is a single `SELECT`; dbt writes the `CREATE VIEW` / `CREATE TABLE` for us.
- **Tests**: dbt tests the models, and a failing test stops the models that depend on it.
- **Documentation**: dbt generates the documentation and the lineage graph.

## Project structure
```
sncb_dbt/
├── dbt_project.yml                 # project settings, including the materialization of each folder
├── packages.yml                    # dbt packages used by the project (dbt_utils)
├── package-lock.yml                # exact package versions (like uv.lock)
├── models/
│   ├── staging/
│   │   ├── _sources.yml            # declares the silver Parquet files as sources
│   │   ├── _stg_models.yml         # describes the models and their columns, and the tests to run on them
│   │   ├── stg_stations.sql        # view on the silver stations: selects and renames the columns
│   │   └── stg_departures.sql      # table: one row per departure, deduplicated (the latest collection wins)
│   ├── marts/
│   │   ├── _marts_models.yml       # descriptions and tests of the marts
│   │   ├── dim_stations.sql        # table: one row per version of a station (SCD 2, built from the snapshot)
│   │   ├── fct_departures.sql      # incremental table: one row per departure, linked to the station version of that time
│   │   └── station_punctuality.sql # table: one row per station, with its current name and punctuality figures
│   └── vault/
│       ├── _vault_models.yml       # descriptions and tests of the Data Vault models
│       ├── hub_station.sql         # table: one row per station (business key + hash key)
│       └── sat_station.sql         # table: one row per version of a station's attributes
├── snapshots/
│   └── snp_stations.yml            # snapshot of stg_stations: keeps every version of every station
├── macros/
│   └── hash_key.sql                # md5 hash of one or more columns (trimmed, upper case), used by the vault
└── analyses/
    └── collection_gaps.sql         # ad hoc query (never built): gaps of more than 15 min between collections
```

- **staging**: one model per source table, cleaned (renamed, typed), with no business logic. Materialized as views
  (except `stg_departures`, a table: the reason is in a comment in the model).
- **marts**: final tables used by BI tools or analysts. Materialized as tables.
- **vault**: a small Data Vault for the stations: a hub (one row per station, its business key) and a satellite
  (one row per version of its attributes, with a `hash_diff`). It reads the snapshot and keeps the full history,
  which is useful for audit. No mart reads it yet: the star schema reads the snapshot directly.
- **snapshots**: `dbt snapshot` compares the current stations with the last version it stored, and keeps every
  change as a new version (SCD 2).
- **No intermediate layer**: an intermediate model holds logic shared by several marts, so that it is written once.
  No logic is shared today; we will add one when two marts need the same step.

## Snapshot
- `snp_stations` captures every change of `stg_stations` (strategy `check` on all columns): a new station adds a row,
  a changed name or position closes the old version and opens a new one.
- It is **never rebuilt**: dbt only appends to it. If `sncb.duckdb` is deleted, the history is lost
  (it could only be rebuilt by replaying the dated bronze files).
- So run `dbt snapshot` right after each collection of the stations, or the changes in between are missed.

## Incremental model
- On a normal build, `fct_departures` only reprocesses the departures from the last loaded day onwards (`>=`, not `>`,
  so a day loaded halfway is completed), and replaces them by their grain (`delete+insert`). This keeps the build fast
  when the table grows.
- `--full-refresh` rebuilds `fct_departures` from all the silver data. It does **not** touch the snapshot, so the
  history of the stations is kept.

## Data quality
- A test checks that every `station_id` follows the documented iRail format (`BE.NMBS.` + 9 digits). Two stations
  from the source do not (`BE.NMBS.8814217`, `BE.NMBS.8860012`), and the iRail liveboard knows neither of them,
  in either form.
- The test is a **warning**, not an error: no departure can point to these stations, so blocking the whole pipeline
  for them would be a false alarm. We do not pad the ids with zeros either: iRail says ids must never be built by hand.

## How to run

### Prerequisites
- [uv](https://docs.astral.sh/uv/) installed
- The silver data of [irail-ingestion](https://github.com/sanneau/irail-ingestion) generated somewhere on the machine
  (`data/silver/`)

### 1. Install dependencies
```bash
uv sync
```

### 2. Configure the silver path
```bash
cp .env.example .env
```
Then set the **absolute** path of the silver folder in `.env`:
```
IRAIL_SILVER_DIR=/home/<you>/projects/irail-ingestion/data/silver
```
The location of the silver data depends on the machine (a laptop, a CI runner, a cloud storage), so it is
configuration, not code. `.env` is ignored by Git; `.env.example` documents the variable.
If the variable is missing, dbt stops with `Env var required but not provided: 'IRAIL_SILVER_DIR'`.

### 3. Configure the connection (not versioned)
Create `~/.dbt/profiles.yml`:
```yaml
sncb_dbt:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: sncb.duckdb
      threads: 4
```
No password: DuckDB is a single file (`sncb.duckdb`), created on the first run and ignored by Git.

Optional, a second target to test changes without touching the real database:
```yaml
    test:
      type: duckdb
      path: sncb_test.duckdb
      threads: 4
```

### 4. Run
Every command has the same shape: `uv run --env-file ../.env dbt <command>`, run from `sncb_dbt/`.
`--env-file` is an option of `uv run` (it loads `.env` before starting dbt), so it goes **before** `dbt`.
```bash
cd sncb_dbt               # the folder of dbt_project.yml; sncb.duckdb is created here
uv run --env-file ../.env dbt deps           # installs the packages (dbt_utils)
uv run --env-file ../.env dbt debug          # checks the connection
uv run --env-file ../.env dbt snapshot       # records the new versions of the stations (after each collection)
uv run --env-file ../.env dbt build          # runs models and tests in DAG order
uv run --env-file ../.env dbt build --full-refresh   # rebuilds the incremental model from scratch
uv run --env-file ../.env dbt build --target test    # same, on sncb_test.duckdb
uv run --env-file ../.env dbt show --select stg_departures   # previews 5 rows
uv run --env-file ../.env dbt docs generate && uv run --env-file ../.env dbt docs serve   # documentation + lineage graph
```

### 5. Before committing
```bash
cd ..                     # back to the repository root
uv run sqlfmt sncb_dbt/models sncb_dbt/macros sncb_dbt/analyses   # formats the SQL (lower-case keywords)
```
