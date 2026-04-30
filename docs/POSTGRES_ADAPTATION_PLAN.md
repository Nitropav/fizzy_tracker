# PostgreSQL Runtime Plan

Fizzy is now treated as a PostgreSQL-only application for the Cactus Bug Tracker fork.

## Active Decisions

- `config/database.yml` always loads `config/database.postgres.yml`.
- The default Docker stack includes a PostgreSQL service.
- CI runs a single PostgreSQL test path.
- Rails models and migrations should not branch by database adapter.
- New data features must target PostgreSQL semantics directly.

## Ongoing Checks

1. Keep `Gemfile` free of non-PostgreSQL database drivers.
2. Keep Docker images free of unused database client packages.
3. Keep migrations PostgreSQL-safe and reversible where practical.
4. Keep search, UUID, Solid Queue, Solid Cache, and Solid Cable schemas aligned with PostgreSQL.
5. Run repository-wide adapter keyword audits before merge.
