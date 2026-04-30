# Fizzy Stabilization Notes

This fork is being stabilized as the Cactus Bug Tracker foundation.

## Current Runtime

- Rails uses PostgreSQL only through `config/database.postgres.yml`.
- Docker development runs `web`, `jobs`, and `db` services against PostgreSQL.
- UUID primary keys use PostgreSQL `uuid` columns.
- Search records are stored in 16 PostgreSQL-backed shards.

## Development Path

Use the Docker stack for local development:

```sh
docker compose up db web
```

For database setup:

```sh
bin/rails db:prepare
```

## Stabilization Checklist

1. Keep application, test, and CI database paths PostgreSQL-only.
2. Keep generated schema files aligned with PostgreSQL.
3. Validate Solid Cable, Solid Cache, and Solid Queue schemas after database changes.
4. Run the full test suite before merging infrastructure changes.
