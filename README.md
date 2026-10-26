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
├── packages.yml                    # dbt packages used by the project (dbt_utils)
├── package-lock.yml                # exact package versions (like uv.lock)
└── models/
    ├── staging/
    │   ├── _sources.yml            # declares the silver Parquet files as sources
    │   ├── _stg_models.yml         # describes the models and their columns, and the tests to run on them
    │   ├── stg_stations.sql        # view on the silver stations: selects and renames the columns
    │   └── stg_departures.sql      # view on the silver departures (one row = one departure seen at a collection)
    └── marts/
        └── station_departures.sql  # table: number of departures per station (disabled during the migration)
```

- **staging**: one model per source table, cleaned (renamed, typed), with no business logic. Materialized as views.
- **marts**: final tables used by BI tools or analysts. Materialized as tables.

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

### 4. Run
`--env-file` is an option of `uv run` (it loads `.env` before starting dbt), so it goes **before** `dbt`.
```bash
cd sncb_dbt               # the folder of dbt_project.yml; sncb.duckdb is created here
uv run --env-file ../.env dbt deps           # installs the packages (dbt_utils)
uv run --env-file ../.env dbt debug          # checks the connection
uv run --env-file ../.env dbt build          # runs models and tests in DAG order
uv run --env-file ../.env dbt show --select stg_departures   # previews 5 rows
uv run --env-file ../.env dbt docs generate && uv run --env-file ../.env dbt docs serve   # documentation + lineage graph
```
