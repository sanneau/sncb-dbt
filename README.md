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
- irail-ingestion cloned in the same parent folder as sncb-dbt, with the silver data generated (`data/silver/`).

### 1. Install dependencies
```bash
uv sync
```

### 2. Configure the connection (not versioned)
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

### 3. Run
```bash
cd sncb_dbt               # required: the paths to the silver files are relative to the folder of dbt_project.yml
uv run dbt deps           # installs the packages (dbt_utils)
uv run dbt debug          # checks the connection
uv run dbt build          # runs models and tests in DAG order
uv run dbt show --select stg_departures   # previews 5 rows
uv run dbt docs generate && uv run dbt docs serve   # documentation + lineage graph
```
