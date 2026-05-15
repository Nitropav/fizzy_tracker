# Cactus Bug Tracker UI URL Map

This document describes the main Cactus Bug Tracker pages inside Fizzy: where to go, who normally uses each page, what the page is responsible for, and what to do there.

## How To Read URLs

- Local base URL: `http://localhost:3006`
- Account-scoped URL: `http://localhost:3006/<account_slug>`
- Current dev account example: `http://localhost:3006/897362094`
- Replace `<account_slug>` with the real account slug, for example `897362094`.
- Replace `:id`, `:board_id`, `:training_example_id`, and `:export_id` with real IDs from the UI.

## Main Cactus Flow

| URL | Used By | Purpose | What To Do |
| --- | --- | --- | --- |
| `/<account_slug>` | All roles | Account root page. Currently routes to Cactus Home. | Use as the main product entry point after login. |
| `/<account_slug>/cactus_home` | All roles | Cactus Home: product navigation hub. | Open issue intake, queue, my work, dashboard, training examples, and integrations. Review quick workflow counts. |
| `/<account_slug>/cactus_issues/new` | Reporter, Support, Admin | Focused issue intake instead of the generic Fizzy card form. | Create a new issue/bug, choose project, fill title, description, priority, and Gate 1 fields: problem, repro steps, expected, actual, environment. Save sparse/draft issues if details are incomplete. |
| `/<account_slug>/cactus_queues` | Support, Developer, Admin | Main Cactus issue queue. | Review issues by state, triage, assign, claim, classify, and open card detail pages. |
| `/<account_slug>/cactus_queues?state=needs_info` | Support, Reporter, Admin | Issues with incomplete Gate 1. | Ask the reporter for missing information or fill Gate 1 fields. |
| `/<account_slug>/cactus_queues?state=open` | Support, Developer, Admin | Gate 1 complete, issue ready for triage. | Assign a developer, select a workflow column, clarify category/domain/severity/priority. |
| `/<account_slug>/cactus_queues?state=in_progress` | Developer, Support, Admin | Issues being worked on, Gate 2 still incomplete. | Developer fills root cause, fix summary, verification steps, commit SHAs, and PR URLs. |
| `/<account_slug>/cactus_queues?state=needs_review` | Developer, Support, Admin | Gate 2 complete, issue ready to be resolved. | Review structured data and close the issue through the guarded resolve action. |
| `/<account_slug>/cactus_queues?state=resolved` | Reviewer, Admin | Resolved issues whose training example is not approved yet. | Review the generated training example and move it toward approval. |
| `/<account_slug>/cactus_queues?state=closed` | Reviewer, Admin | Issues with approved training examples. | Use as the archive of high-quality completed issues. |
| `/<account_slug>/cactus_work` | Developer | Focused Developer Work page. | Review assigned work, issues missing Gate 2, ready-to-claim work, and recently resolved work. |
| `/<account_slug>/cards/:id` | Any role with project/card access | Issue/card detail page. | Read context, comments, Gate 1/Gate 2 blocks, AI suggestions, and code evidence. Fill fields allowed by role. |
| `/<account_slug>/cards/:id/resolution_record/edit` | Developer, Support, Reviewer, Admin | Focused form for structured training data. | Fill or edit Gate 1, classification, and Gate 2. Use for the developer resolution workflow. |

## Projects / Boards

In Cactus UI, `Board` is functionally used as `Project`.

| URL | Used By | Purpose | What To Do |
| --- | --- | --- | --- |
| `/<account_slug>/boards` | Support, Developer, Admin | Project/board list. | Find a project, open a board, verify available project spaces. |
| `/<account_slug>/boards/new` | Admin | Create project/board. | Create a new project for a group of issues. |
| `/<account_slug>/boards/:board_id` | Roles with access | Project board with columns and cards. | View issues inside a project. Prefer Cactus Queue for the main Cactus workflow, but use board view for visual overview. |
| `/<account_slug>/boards/:board_id/edit` | Admin / project owner | Project settings. | Change name, users, publication, and board-level settings. |
| `/<account_slug>/boards/:board_id/bug_report/new` | Reporter / legacy Fizzy flow | Old board-scoped bug report form. | Use only when the legacy Fizzy path is needed. Prefer `cactus_issues/new` for Cactus. |

## Training Data Review

| URL | Used By | Purpose | What To Do |
| --- | --- | --- | --- |
| `/<account_slug>/training_examples` | Reviewer, Admin | Training example review queue. | Filter examples by status, open examples for review, export approved examples. |
| `/<account_slug>/training_examples?status=pending_review` | Reviewer, Admin | Examples waiting for review. | Check problem/resolution/context quality and approve/reject. |
| `/<account_slug>/training_examples?status=approved` | Reviewer, Admin | Examples ready for export. | Review final export set before JSONL export. |
| `/<account_slug>/training_examples?status=rejected` | Reviewer, Admin | Rejected examples. | Review rejection reasons and notes. |
| `/<account_slug>/training_examples?status=exported` | Reviewer, Admin | Already exported examples. | Audit training corpus material. |
| `/<account_slug>/training_examples/:training_example_id` | Reviewer, Admin | Training example detail page. | Review structured context, JSONL preview, approve/reject, and review notes. |
| `/<account_slug>/training_examples/export` | Reviewer, Admin | Action URL for exporting approved examples. | Usually use the Export button in UI. Open directly only when downloading approved examples intentionally. |
| `/<account_slug>/training_example_exports` | Reviewer, Admin | Export batch history. | See when exports happened, who ran them, and how many examples were included. |
| `/<account_slug>/training_example_exports/:export_id` | Reviewer, Admin | Repeat download for an export batch. | Download the same JSONL batch again. |

## Dashboard And Operations

| URL | Used By | Purpose | What To Do |
| --- | --- | --- | --- |
| `/<account_slug>/cactus_dashboard` | Reviewer, Admin | Operational dashboard for pipeline health. | Review alerts, backlog health, Gate completion, GitHub evidence coverage, training export rate, and AI suggestion acceptance. |
| `/<account_slug>/cactus_dashboard?period=7` | Reviewer, Admin | Dashboard with 7-day activity trends. | Check recent movement quickly. |
| `/<account_slug>/cactus_dashboard?period=30` | Reviewer, Admin | Dashboard with 30-day activity trends. | Main weekly/monthly review window. |
| `/<account_slug>/cactus_dashboard?period=90` | Reviewer, Admin | Dashboard with 90-day activity trends. | Review longer-term trend and training corpus growth. |

## Integrations

| URL | Used By | Purpose | What To Do |
| --- | --- | --- | --- |
| `/<account_slug>/cactus_integrations` | Admin | Admin screen for external integrations. | Configure GitHub webhook, inspect delivery health, review failed deliveries, retry failures, and open Asana import. |
| `/<account_slug>/github/webhook` | GitHub, not humans | Webhook endpoint. | Do not open manually. GitHub sends signed `POST` requests with `X-Hub-Signature-256`. |
| `/<account_slug>/github/webhook_deliveries/:webhook_delivery_id/retry` | Admin action | Retry failed GitHub delivery. | Usually use the Retry button on the integrations page. |

## Asana Legacy Import

| URL | Used By | Purpose | What To Do |
| --- | --- | --- | --- |
| `/<account_slug>/legacy_imports/asana/new` | Admin / Importer | Import Asana JSON export as legacy issues. | Choose project, upload JSON, import historical tasks as legacy records. |
| `/<account_slug>/legacy_imports/asana/issues` | Admin / Importer / Reviewer | Review queue for imported Asana issues. | Structure legacy issues, apply AI suggestions, prepare candidates for training examples. |
| `/<account_slug>/legacy_imports/asana/issues?status=needs_structuring` | Admin / Importer / Reviewer | Legacy issues with incomplete structure. | Fill Gate 1/Gate 2 manually or through AI suggestions. |
| `/<account_slug>/legacy_imports/asana/issues?status=structured` | Admin / Importer / Reviewer | Legacy issues whose structure is ready. | Generate training example candidates when Gate 1 and Gate 2 are complete. |
| `/<account_slug>/legacy_imports/asana/issues?status=all` | Admin / Importer / Reviewer | All Asana legacy issues. | Audit import state and overall legacy issue coverage. |

## AI Assistance Screens And Actions

Most AI actions are launched by buttons on card or legacy import pages. They should not usually be opened directly.

| URL | Used By | Purpose | What To Do |
| --- | --- | --- | --- |
| `/<account_slug>/cards/:id/ai_review` | Support, Developer, Reviewer | Read-only quality review for a card. | Click `Review quality` on a card to see missing data and suggestions. |
| `/<account_slug>/cards/:id/structuring_suggestion` | Support/Admin action | AI suggestion for Gate 1/classification. | Generate a suggestion on the card and manually apply only useful fields. |
| `/<account_slug>/cards/:id/structuring_suggestion/apply` | Support/Admin action | Apply active structuring suggestion. | Used through UI form/button. |
| `/<account_slug>/cards/:id/resolution_draft` | Developer action | AI draft for Gate 2. | Click `Draft resolution`, then review/apply manually. |
| `/<account_slug>/cards/:id/resolution_draft/apply` | Developer action | Apply active resolution draft. | Used through UI form/button. |
| `/<account_slug>/cards/:id/duplicate_suggestion` | Support/Developer action | Find similar issues. | Run duplicate suggestion on a card. |
| `/<account_slug>/cards/:card_id/ai_runs/:ai_run_id/dismissal` | User with access to the suggestion | Dismiss AI suggestion. | Dismiss suggestions that are not useful. |

## Account, Users, Access

| URL | Used By | Purpose | What To Do |
| --- | --- | --- | --- |
| `/session/new` | All users | Login page. | Sign in by email/passkey/dev login depending on environment. |
| `/<account_slug>/account/settings` | Admin / account owner | Account settings. | Configure account, export/import account data, cancellation, and other account-level options. |
| `/<account_slug>/account/join_code` | Admin | Invite/join code. | Create or view the join code for inviting users. |
| `/<account_slug>/users` | Admin | User list. | Review account users. |
| `/<account_slug>/users/:id` | Admin / user | User profile/settings. | Review user details, access tokens, avatar, and data export. |
| `/<account_slug>/users/:id/role` | Admin | Cactus role management. | Assign roles: reporter/support/developer/reviewer/admin. |
| `/<account_slug>/my/menu` | All users | Personal menu. | Navigate personal settings and shortcuts. |
| `/<account_slug>/my/access_tokens` | Developer/Admin | Personal API tokens. | Create/manage access tokens when API access is needed. |
| `/<account_slug>/notifications` | All users | Notifications list. | Review notifications. |
| `/<account_slug>/notifications/settings` | All users | Notification settings. | Configure notifications. |

## Search And Activity

| URL | Used By | Purpose | What To Do |
| --- | --- | --- | --- |
| `/<account_slug>/search` | All users | Search page. | Search cards/issues/comments/users/tags. |
| `/<account_slug>/events` | All users | Activity/events feed. | Review account activity. Usually less important for Cactus workflow than Queue/Dashboard. |
| `/<account_slug>/tags` | All users | Tags page. | Review and use tags. |

## System / Non-Product URLs

| URL | Used By | Purpose | What To Do |
| --- | --- | --- | --- |
| `/up` | Ops / health check | Rails health check. | Use to verify the app is alive. |
| `/manifest` | Browser/PWA | PWA manifest. | Do not open manually for Cactus workflow. |
| `/service-worker` | Browser/PWA | Service worker. | Do not open manually. |
| `/admin/jobs` | Admin/Ops | Mission Control Jobs dashboard. | Inspect background jobs if enabled and accessible. |

## Action-Only Endpoints

These URLs exist for buttons/forms/API calls. They should not usually be opened manually as pages.

| Endpoint | Method | Purpose |
| --- | --- | --- |
| `/<account_slug>/cactus_issues` | `POST` | Create Cactus issue. |
| `/<account_slug>/cards/:id/gate_one_answer` | `PATCH/PUT` | Update Gate 1 fields. |
| `/<account_slug>/cards/:id/resolution_record` | `PATCH/PUT` | Update structured training fields. |
| `/<account_slug>/cards/:id/triage` | `POST/DELETE` | Move issue into a triage column or send back to triage. |
| `/<account_slug>/cards/:id/assignments` | `POST` | Assign/unassign developer. |
| `/<account_slug>/cards/:id/self_assignment` | `POST` | Claim/unclaim issue as current developer. |
| `/<account_slug>/cards/:id/resolution` | `POST` | Mark resolved when Gate 2 and code evidence are ready. |
| `/<account_slug>/training_examples/:id/approve` | `POST` | Approve training example. |
| `/<account_slug>/training_examples/:id/reject` | `POST` | Reject training example. |
| `/<account_slug>/legacy_imports/asana` | `POST` | Upload Asana JSON import. |
| `/<account_slug>/legacy_imports/asana/issues/:issue_id/structuring_suggestion` | `POST` | Generate AI structuring suggestion for a legacy issue. |
| `/<account_slug>/legacy_imports/asana/issues/:issue_id/structuring_suggestion/apply` | `POST` | Apply AI structuring suggestion for a legacy issue. |
| `/<account_slug>/legacy_imports/asana/issues/:issue_id/training_example` | `POST` | Create training example from structured legacy issue. |

## Recommended Manual Happy Path

1. Open `/<account_slug>/cactus_issues/new`.
2. Create an issue with complete Gate 1.
3. Open `/<account_slug>/cactus_queues?state=open`.
4. Assign a developer and move the issue into a work column.
5. Open `/<account_slug>/cactus_work`.
6. Fill Gate 2 through card detail or `/<account_slug>/cards/:id/resolution_record/edit`.
7. Add commit SHA or PR URL.
8. Click `Mark resolved`.
9. Open `/<account_slug>/training_examples?status=pending_review`.
10. Open the training example, inspect JSONL preview, approve it.
11. Open `/<account_slug>/training_examples?status=approved`.
12. Export approved examples.
13. Check `/<account_slug>/training_example_exports`.
14. Check metrics on `/<account_slug>/cactus_dashboard`.
