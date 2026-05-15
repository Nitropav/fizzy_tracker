# Cactus Bug Tracker - Manual Test Cases

This document is a manual QA checklist for Cactus Bug Tracker after auth, roles, Cactus UI, and training-data pipeline changes.

## How To Read URLs

- Local base URL: `http://localhost:3006`
- Dev account example: `http://localhost:3006/897362094`
- Replace `<account_slug>` with the real account slug, for example `897362094`.
- Replace `:id`, `:board_id`, `:training_example_id`, and `:export_id` with real values from the UI.
- Role testing requires users with account role `admin/owner/member` and Cactus role `reporter/developer/support/reviewer`.
- Empty local DB bootstrap creates admin login `admin@cactus.local` / `CactusAdmin123!` unless overridden in `.env`.

## 1. Auth, Login, Logout

| ID | URL | Role | Action | Expected Result |
| --- | --- | --- | --- | --- |
| AUTH-01 | `/` | Guest | Open the app without a session. | Redirects to `/session/new`, not projects/boards/account menu. |
| AUTH-02 | `/session/new` | Guest | Sign in with email + password, for example local bootstrap admin `admin@cactus.local` / `CactusAdmin123!`. | After successful login, user lands in account-scoped Cactus Home: `/<account_slug>`. |
| AUTH-03 | `/session/new` | Guest | Enter a wrong password. | Shows safe message `Check your email and password.`, no session is created. |
| AUTH-04 | Any authenticated page | Any | Click `Sign out` in the header. | Session is destroyed and user returns to the login page. |
| AUTH-05 | `/session/menu` | Auth user without selected account | Open account chooser. | If there is one account, auto-redirects into it; signup link is hidden when signups are disabled. |
| AUTH-06 | `/<account_slug>` | Any | Open account root URL after login. | Opens Cactus Home, not a board/project. |

## 2. Admin Account, Users, Roles

| ID | URL | Role | Action | Expected Result |
| --- | --- | --- | --- | --- |
| ADMIN-01 | `/<account_slug>/cactus_home` | Admin/Owner | Open Cactus Home. | Shows `Users and roles` card with `Invite people` and `Manage users`. |
| ADMIN-02 | `/<account_slug>/account/join_code` | Admin/Owner | Open invite page. | Shows the `Add people` page and can view or create a join code for inviting users. |
| ADMIN-03 | `/<account_slug>/account/settings` | Admin/Owner | Open users section. | Active users, account role controls, and Cactus role controls are visible. |
| ADMIN-04 | `/<account_slug>/account/settings` | Admin/Owner | Create a user with email/password, account role, and Cactus role. Then change the user's Cactus role to `reporter`, `developer`, `support`, `reviewer`. | User can sign in with the created password; roles are saved and persist after reload. |
| ADMIN-05 | `/<account_slug>/account/settings` | Admin/Owner | Change another user's account role `member/admin`, where allowed. | Admin cannot change owner or self; permitted changes work. |
| ADMIN-06 | `/<account_slug>/account/settings` | Member | Open settings. | Role controls are disabled/unavailable; non-admin cannot manage users. |

## 3. Navigation And Role Visibility

| ID | URL | Role | Action | Expected Result |
| --- | --- | --- | --- | --- |
| NAV-01 | `/<account_slug>/my/menu` | Reporter | Open menu. | Shows `Cactus Home`, `New Issue`; hides `Projects`, `Training Examples`, `Integrations`, `Cactus Dashboard`. |
| NAV-02 | `/<account_slug>/my/menu` | Developer | Open menu. | Shows `Cactus Home`, `New Issue`, `My Work`; no admin-only Fizzy UI. |
| NAV-03 | `/<account_slug>/my/menu` | Support | Open menu. | Shows `Cactus Queue`, `Import Asana Tasks`, `Legacy Asana Issues`; no Projects unless user is admin. |
| NAV-04 | `/<account_slug>/my/menu` | Reviewer | Open menu. | Shows `Training Examples`, `Cactus Dashboard`; no project management controls. |
| NAV-05 | `/<account_slug>/my/menu` | Admin/Owner | Open menu. | Shows admin sections: `Projects`, `Integrations`, `Training Examples`, users/settings. |
| NAV-06 | `/<account_slug>/cactus_home` | Non-admin | Open home. | Does not show `Projects` card or `Users and roles`. |
| NAV-07 | `/<account_slug>/cactus_home` | Admin/Owner | Open home. | Shows admin pipeline and users/roles management links. |

## 4. Issue Intake And Gate 1

| ID | URL | Role | Action | Expected Result |
| --- | --- | --- | --- | --- |
| ISSUE-01 | `/<account_slug>/cactus_issues/new` | Reporter | Create issue with only title/description. | Issue is created as incomplete/sparse; workflow state indicates Gate 1 needs data. |
| ISSUE-02 | `/<account_slug>/cactus_issues/new` | Reporter | Create issue with complete Gate 1: problem, repro steps, expected, actual, environment. | Issue is ready for triage/open flow, data appears on card detail. |
| ISSUE-03 | `/<account_slug>/cactus_issues/new` | Reporter | Check project selector. | User can select an accessible project; non-admin does not see project management. |
| ISSUE-04 | `/<account_slug>/cards/:id` | Reporter | Open created card. | Shows Gate 1 fields, comments/activity, no developer-only Gate 2 actions. |
| ISSUE-05 | `/<account_slug>/cards/:id/resolution_record/edit` | Reporter | Try updating Gate 1. | Reporter can update reporter-side fields, but cannot update Gate 2. |

## 5. Queue, Triage, Assignment

| ID | URL | Role | Action | Expected Result |
| --- | --- | --- | --- | --- |
| QUEUE-01 | `/<account_slug>/cactus_queues` | Support/Admin | Open queue. | Table is responsive, filters/states are available, rows open card detail. |
| QUEUE-02 | `/<account_slug>/cactus_queues?state=needs_info` | Support/Admin | Find incomplete issue. | Shows which Gate 1 data is missing; issue should not move forward without data. |
| QUEUE-03 | `/<account_slug>/cactus_queues?state=open` | Support/Admin | Assign developer, category/domain/severity/priority. | Values persist, issue is ready for developer workflow. |
| QUEUE-04 | `/<account_slug>/cactus_queues?state=open` | Developer | Claim issue, if available. | Issue appears in `My Work`. |
| QUEUE-05 | `/<account_slug>/cactus_queues` | Reporter | Open queue. | Reporter cannot see support/admin triage controls. |

## 6. Developer Workflow And Gate 2

| ID | URL | Role | Action | Expected Result |
| --- | --- | --- | --- | --- |
| DEV-01 | `/<account_slug>/cactus_work` | Developer | Open My Work. | Shows assigned issues, missing Gate 2 fields, claimable work, recently resolved work. |
| DEV-02 | `/<account_slug>/cards/:id/resolution_record/edit` | Developer | Fill root cause, fix summary, verification steps. | Gate 2 is saved and displayed on card detail. |
| DEV-03 | `/<account_slug>/cards/:id/resolution_record/edit` | Developer | Add commit SHA and/or PR URL. | Code evidence appears in card detail. |
| DEV-04 | `/<account_slug>/cards/:id` | Developer | Try `Mark resolved` without complete Gate 2. | Resolve is blocked and missing fields are shown. |
| DEV-05 | `/<account_slug>/cards/:id` | Developer | Click `Mark resolved` after complete Gate 2. | Issue moves into resolved/review pipeline, training candidate is created or updated. |

## 7. GitHub Integration And Code Evidence

| ID | URL | Role | Action | Expected Result |
| --- | --- | --- | --- | --- |
| GITHUB-01 | `/<account_slug>/cactus_integrations` | Admin | Open integrations. | Shows GitHub webhook settings/health and delivery status. |
| GITHUB-02 | `/<account_slug>/cactus_integrations` | Admin | Check failed deliveries. | Failed delivery can be retried through UI and status updates. |
| GITHUB-03 | `/<account_slug>/cards/:id` | Developer/Admin | Check card with linked commit/PR. | Commit SHA/PR URL appears as Gate 2 evidence. |
| GITHUB-04 | `/<account_slug>/github/webhook` | GitHub endpoint | Do not open manually as a page. | Endpoint is for signed POST requests from GitHub; manual GET is not a product scenario. |

## 8. Training Examples Review And Export

| ID | URL | Role | Action | Expected Result |
| --- | --- | --- | --- | --- |
| TRAIN-01 | `/<account_slug>/training_examples?status=pending_review` | Reviewer/Admin | Open pending review. | Shows generated examples after resolved issues. |
| TRAIN-02 | `/<account_slug>/training_examples/:training_example_id` | Reviewer/Admin | Open example detail. | Shows input context, problem, root cause, resolution, verification, metadata, JSONL preview. |
| TRAIN-03 | `/<account_slug>/training_examples/:training_example_id` | Reviewer/Admin | Approve example. | Status changes to `approved`, example leaves pending list. |
| TRAIN-04 | `/<account_slug>/training_examples/:training_example_id` | Reviewer/Admin | Reject example with notes. | Status changes to `rejected`, notes persist. |
| TRAIN-05 | `/<account_slug>/training_examples?status=approved` | Reviewer/Admin | Export approved examples. | Export batch is created; approved examples move to or are marked as exported. |
| TRAIN-06 | `/<account_slug>/training_example_exports` | Reviewer/Admin | Open export history. | Shows `Training Export History`, batches, count, user, timestamps, repeat download. |
| TRAIN-07 | `/<account_slug>/training_example_exports/:export_id` | Reviewer/Admin | Download batch again. | JSONL downloads; each line is a valid JSON object. |

## 9. Asana Legacy Import

| ID | URL | Role | Action | Expected Result |
| --- | --- | --- | --- | --- |
| ASANA-01 | `/<account_slug>/legacy_imports/asana/new` | Support/Admin | Open import page. | Shows project selector and Asana JSON upload. |
| ASANA-02 | `/<account_slug>/legacy_imports/asana/new` | Support/Admin | Upload a small valid Asana JSON file. | Creates legacy issues marked `legacy/asana/needs_structuring`. |
| ASANA-03 | `/<account_slug>/legacy_imports/asana/issues?status=needs_structuring` | Support/Admin/Reviewer | Open imported issue. | Can structure Gate 1/Gate 2 manually or with AI suggestion. |
| ASANA-04 | `/<account_slug>/legacy_imports/asana/issues?status=structured` | Reviewer/Admin | Create training example from structured legacy issue. | Training example appears in review queue. |
| ASANA-05 | `/<account_slug>/legacy_imports/asana/issues?status=all` | Support/Admin/Reviewer | Review all legacy issues. | Filters and statuses are correct; imported data does not break the normal queue. |

## 10. AI Assistance

| ID | URL | Role | Action | Expected Result |
| --- | --- | --- | --- | --- |
| AI-01 | `/<account_slug>/cards/:id` | Support/Developer/Reviewer | Click `Review quality`. | AI review is read-only, shows missing fields/suggestions, and does not auto-write. |
| AI-02 | `/<account_slug>/cards/:id` | Support/Admin | Run Gate 1/classification suggestion. | Suggestion can be reviewed/applied manually; fields are not applied without confirmation. |
| AI-03 | `/<account_slug>/cards/:id` | Developer | Run draft resolution. | Draft Gate 2 appears as a suggestion; developer manually applies/edits it. |
| AI-04 | `/<account_slug>/cards/:id` | Support/Developer | Run duplicate suggestion. | Similar issues are shown and suggestion can be dismissed. |
| AI-05 | `/<account_slug>/legacy_imports/asana/issues` | Support/Admin/Reviewer | Run AI structuring for legacy issue. | Suggestion helps fill structure, but persists only after user action. |

## 11. Dashboard And Operations

| ID | URL | Role | Action | Expected Result |
| --- | --- | --- | --- | --- |
| OPS-01 | `/<account_slug>/cactus_dashboard` | Reviewer/Admin | Open dashboard. | Shows backlog health, Gate completion, GitHub linkage, export metrics, AI metrics. |
| OPS-02 | `/<account_slug>/cactus_dashboard?period=7` | Reviewer/Admin | Check 7-day period. | Trends recalculate for 7 days. |
| OPS-03 | `/<account_slug>/cactus_dashboard?period=30` | Reviewer/Admin | Check 30-day period. | Trends recalculate for 30 days. |
| OPS-04 | `/<account_slug>/cactus_dashboard?period=90` | Reviewer/Admin | Check 90-day period. | Trends recalculate for 90 days. |
| OPS-05 | `/up` | Ops | Open health check. | Returns successful health response. |

## 12. Negative And Permission Checks

| ID | URL | Role | Action | Expected Result |
| --- | --- | --- | --- | --- |
| NEG-01 | `/<account_slug>/training_examples` | Reporter/Developer | Open directly. | Access is denied or reviewer actions are not visible. |
| NEG-02 | `/<account_slug>/cactus_integrations` | Non-admin | Open directly. | Access is denied. |
| NEG-03 | `/<account_slug>/account/settings` | Member | Try changing another user's role. | Change is not allowed. |
| NEG-04 | `/<account_slug>/boards/new` | Non-admin | Open directly. | Project creation is forbidden. |
| NEG-05 | `/<account_slug>/cards/:id` | Reporter | Try resolving an issue. | Resolve action is unavailable or blocked. |
| NEG-06 | `/<account_slug>/cards/:id` | Developer | Try approving a training example. | Training review action is unavailable unless user is reviewer/admin. |

## 13. Recommended End-To-End Smoke

1. Guest opens `/` and lands on `/session/new`.
2. Admin signs in and opens `/<account_slug>/cactus_home`.
3. Admin creates/checks a user in `/<account_slug>/account/settings` and assigns Cactus roles.
4. Reporter creates issue in `/<account_slug>/cactus_issues/new`.
5. Support opens `/<account_slug>/cactus_queues?state=open`, classifies issue, and assigns developer.
6. Developer opens `/<account_slug>/cactus_work`, fills Gate 2 and code evidence.
7. Developer clicks `Mark resolved`.
8. Reviewer opens `/<account_slug>/training_examples?status=pending_review`, checks JSONL preview, and approves.
9. Reviewer exports approved examples.
10. Admin checks `/<account_slug>/training_example_exports`, `/<account_slug>/cactus_dashboard`, and `/<account_slug>/cactus_integrations`.
