# Cactus Bug Tracker

Cactus Bug Tracker is a bug/task tracker built on top of Fizzy. The product goal is to replace the current Asana-based bug workflow while capturing structured training data from real production issues.

Every issue is designed around two required gates:

- Gate 1, reporter side: problem description, reproduction steps, expected behavior, actual behavior, and environment context.
- Gate 2, developer side: root cause, fix summary, verification steps, and linked commit/PR evidence.

Completed issues can generate reviewable training examples and JSONL exports for model training.

This repository still contains the original Fizzy foundation, but the main product surface is the Cactus workflow: issue intake, triage queue, developer work, Asana legacy import, training review, JSONL export, dashboard, integrations, and account/user administration.

## Requirements

Use the Docker setup for a new machine.

- Docker Desktop
- Git
- PowerShell, Git Bash, or another shell capable of running Docker Compose

The Docker setup runs:

- Rails web server on port `3006`
- PostgreSQL 16
- background jobs container

## Quick Start On A New Device

Clone the repository and enter the project folder:

```powershell
git clone <repo-url> fizzy_tracker
cd fizzy_tracker
```

Create local environment config:

```powershell
Copy-Item .env.example .env
```

Start the full local stack:

```powershell
docker compose up --build
```

On first boot, the web container runs:

- `bin/rails db:prepare`
- `bin/rails db:seed`, only when there are no accounts yet

The seed uses `Cactus::Bootstrapper` and creates the required local foundation:

- account: `Cactus Bug Tracker`
- project: `Cactus Product Bugs`
- owner/admin user: `Cactus Admin`
- admin email: `admin@cactus.local`
- admin password: `CactusAdmin123!`

Open the app:

```text
http://localhost:3006
```

Sign in at `/session/new` with:

```text
Email: admin@cactus.local
Password: CactusAdmin123!
```

After login, the app redirects to the account-scoped Cactus home page, for example:

```text
http://localhost:3006/897362095
```

The exact account slug can vary if the database already has accounts. The bootstrap output prints the created account URL.

## Environment Variables

The most important local variables are in `.env.example`:

```dotenv
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=fizzy_development
POSTGRES_CABLE_DB=fizzy_development_cable
POSTGRES_CACHE_DB=fizzy_development_cache
POSTGRES_QUEUE_DB=fizzy_development_queue

CACTUS_ACCOUNT_NAME=Cactus Bug Tracker
CACTUS_DEFAULT_PROJECT_NAME=Cactus Product Bugs
CACTUS_ADMIN_NAME=Cactus Admin
CACTUS_ADMIN_EMAIL=admin@cactus.local
CACTUS_ADMIN_PASSWORD=CactusAdmin123!
CACTUS_UPDATE_ADMIN_PASSWORD=false
ENABLE_DEVELOPMENT_LOGIN=false
SEED_SAMPLE_DATA=false
```

Use a real password outside local development. Do not commit `.env`.

## Database, Migrations, And Seed Data

Schema changes belong in migrations. Local bootstrap/demo data belongs in seeds or explicit rake tasks.

For a new local database, the normal Docker startup is enough:

```powershell
docker compose up --build
```

To run database setup manually:

```powershell
docker compose run --rm web bin/rails db:prepare
docker compose run --rm web bin/rails db:seed
```

To re-run only the Cactus foundation bootstrap:

```powershell
docker compose run --rm web bin/rails cactus:bootstrap
```

`cactus:bootstrap` is idempotent. It creates the Cactus account, admin login, system user, and default project if they are missing. It does not rotate an existing admin password unless `CACTUS_UPDATE_ADMIN_PASSWORD=true`.

To reset local Docker data completely:

```powershell
docker compose down -v
docker compose up --build
```

This deletes the local PostgreSQL volume.

## Demo And Test Data

The default seed intentionally creates only the minimum Cactus account, admin user, and default project. This keeps a new environment clean.

For manual demo data, use the Asana import UI with the sample file:

```text
docs/asana_export.json
```

Import page:

```text
/<account_slug>/legacy_imports/asana/new
```

Example local URL:

```text
http://localhost:3006/897362095/legacy_imports/asana/new
```

If you explicitly need the old Fizzy sample accounts/cards in development, set this in `.env` before seeding:

```dotenv
SEED_SAMPLE_DATA=true
```

Most Cactus testing should use the Cactus bootstrap account plus imported Asana sample tasks, not the old Fizzy sample data.

## Main Local URLs

Replace `897362095` with your actual account slug if it differs.

```text
http://localhost:3006/session/new
http://localhost:3006/897362095
http://localhost:3006/897362095/cactus_issues/new
http://localhost:3006/897362095/cactus_queues
http://localhost:3006/897362095/cactus_work
http://localhost:3006/897362095/training_examples
http://localhost:3006/897362095/training_example_exports
http://localhost:3006/897362095/legacy_imports/asana/new
http://localhost:3006/897362095/cactus_dashboard
http://localhost:3006/897362095/account/settings
```

Detailed page maps:

- `docs/CACTUS_UI_URL_MAP_EN.md`
- `docs/CACTUS_UI_URL_MAP_RU.md`

## Roles

Cactus role controls the product workflow:

- `reporter`: creates issues and fills Gate 1.
- `developer`: claims assigned work, fills Gate 2, links code evidence, and resolves issues.
- `support`: triages, classifies, assigns, imports Asana tasks, and structures legacy issues.
- `reviewer`: reviews training examples and exports approved JSONL.

Account role controls account administration:

- `member`: normal account user.
- `admin`: can manage users, projects, imports, integrations, dashboard, and training review.

Admin users can create production-style email/password logins from:

```text
/<account_slug>/account/settings
```

## Common Development Commands

Run Rails commands inside Docker:

```powershell
docker compose exec web bin/rails routes
docker compose exec web bin/rails console
docker compose exec web bin/rails test
```

Run a focused test file:

```powershell
docker compose exec web bin/rails test test/integration/cactus_full_workflow_test.rb
```

Restart containers:

```powershell
docker compose restart web jobs
```

View logs:

```powershell
docker compose logs -f web
docker compose logs -f jobs
```

## Useful Documentation

- `docs/CACTUS_FUNCTIONAL_OVERVIEW_EN.md`
- `docs/CACTUS_FUNCTIONAL_OVERVIEW_RU.md`
- `docs/CACTUS_BUG_TRACKER_FINAL_PRODUCT_PLAN.md`
- `docs/CACTUS_LOCAL_BOOTSTRAP_AND_LOGIN.md`
- `docs/CACTUS_MANUAL_TEST_CASES_EN.md`
- `docs/CACTUS_MANUAL_TEST_CASES_RU.md`
- `docs/CACTUS_SECURITY_PERMISSION_MATRIX.md`

## Original Fizzy

This project is based on [Fizzy](https://fizzy.do/), the Kanban tracking tool by [37signals](https://37signals.com).

Original Fizzy documentation is still present where useful:

- `docs/docker-deployment.md`
- `docs/kamal-deployment.md`
- `docs/development.md`
- `STYLE.md`
- `LICENSE.md`
