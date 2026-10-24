# sncb-dbt

## What is this?
dbt is a command-line tool that handles the T (Transform) part of an ELT pipeline.
The Extract and Load parts stay in Python, in [irail-ingestion](https://github.com/sanneau/irail-ingestion):
it calls the iRail API and loads the raw data into PostgreSQL. This project transforms that data with SQL.

## Why dbt?
- **Order**: dbt runs the models in the right order, based on their dependencies (`ref()` builds the DAG).
- **Less boilerplate**: each model is a single `SELECT`; dbt writes the `CREATE VIEW` / `CREATE TABLE` for us.
- **Tests**: dbt tests the models, and a failing test stops the models that depend on it.
- **Documentation**: dbt generates the documentation and the lineage graph.

## Project structure
```
sncb_dbt/models/
├── staging/
│   ├── _sources.yml            # declares the raw tables from irail-ingestion (public schema)
│   ├── _stg_models.yml         # describes the models and their columns, and the tests to run on them
│   └── stg_stations.sql        # view on stg_station: selects and renames the columns
└── marts/
    └── station_departures.sql  # table: number of departures per station
```

- **staging**: one model per source table, cleaned (renamed, typed), with no business logic. Materialized as views.
- **marts**: final tables used by BI tools or analysts. Materialized as tables.

## How to run

### Prerequisites
- [uv](https://docs.astral.sh/uv/) installed
- The PostgreSQL database from [irail-ingestion](https://github.com/sanneau/irail-ingestion) running
  (`docker compose up -d`) and loaded (tables `stg_station`, `dim_station`, `fact_departure` in schema `public`)

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
      type: postgres
      host: localhost
      port: 5432
      user: irail
      password: "{{ env_var('DBT_PASSWORD') }}"
      dbname: sncb_bruxelles
      schema: dbt_dev
      threads: 4
```
The password is never written in a file; it is read from an environment variable:
```bash
export DBT_PASSWORD="<your database password>"
```

### 3. Run
```bash
cd sncb_dbt
uv run dbt debug          # checks the connection
uv run dbt build          # runs models and tests in DAG order
uv run dbt docs generate && uv run dbt docs serve   # documentation + lineage graph
```
