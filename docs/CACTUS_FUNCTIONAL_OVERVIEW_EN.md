# Cactus Bug Tracker: Functional Overview

Updated: 2026-05-08

This document describes the current Cactus Bug Tracker functionality inside Fizzy. The product goal is to replace Asana for bugs/tasks while also collecting structured data that can be reviewed, turned into training examples, and exported as JSONL.

## 1. Product Concept

Cactus Bug Tracker is a bug tracker where every issue moves through two mandatory structured stages:

- Gate 1 - reporter side: what is broken, how to reproduce it, what was expected, what actually happened, and the environment context.
- Gate 2 - developer side: root cause, fix summary, verification steps, and linked commits/PRs.

Comments remain a discussion thread. Gate 1 and Gate 2 are separate structured records used by queues, AI review, training examples, and JSONL export.

## 2. Roles

### Reporter

Creates issues and fills Gate 1.

Can:

- open Cactus Home;
- create a new issue;
- fill reporter-side fields;
- view cards available to them.

Should not see:

- Cactus Queue;
- My Work;
- developer-only Gate 2 data;
- training review/export;
- integrations or admin screens.

### Developer

Claims work and fills Gate 2.

Can:

- open My Work;
- claim ready issues;
- view assigned issues;
- fill root cause, fix summary, and verification steps;
- add commit SHAs and PR URLs;
- mark an issue resolved when Gate 2 and code evidence are complete.

Should not:

- manage Asana imports;
- manage GitHub integrations;
- review/export training examples unless they also have reviewer/admin permissions.

### Support

Owns triage, queue management, and legacy import preparation.

Can:

- open Cactus Queue;
- view workflow health;
- classify issues;
- assign developers;
- import Asana tasks;
- structure legacy issues.

Should not:

- close developer work without the required permissions;
- review/export training examples unless they also have reviewer/admin permissions.

### Reviewer

Owns training data quality.

Can:

- open Training Examples;
- approve/reject examples;
- view JSONL previews;
- export approved examples;
- view dashboard metrics.

Should not:

- run support triage;
- do Gate 2 developer work unless they also have developer/admin permissions.

### Admin / Owner

Cactus superuser.

Can:

- access all Cactus screens;
- manage users and roles;
- manage projects;
- configure integrations;
- view audit logs;
- perform support/developer/reviewer actions.

## 3. Login And Account Setup

The application uses production-style email/password login.

Supported:

- email/password sign in;
- forgot password;
- user creation from admin/account settings;
- account role and Cactus role assignment;
- Cactus account/admin/project bootstrap through seed/rake flow.

Passkey login has been removed from the Cactus login UI so the browser does not open the Windows Security/WebAuthn prompt.

## 4. Cactus Home

URLs:

- `/<account_slug>`
- `/<account_slug>/cactus_home`

Cactus Home is the main landing page after sign in.

It only shows actions available to the current role:

- Create issue;
- Cactus Queue;
- My Work;
- Projects;
- Operations pipeline;
- Training Examples;
- Dashboard;
- Asana import;
- Users and roles;
- Audit log.

Generic Fizzy sections and admin-only links are hidden from non-admin users.

## 5. Projects

In the Cactus UI, Fizzy `Board` is used as `Project`.

Functionality:

- project list;
- project board with columns;
- admin-only project creation;
- project access settings;
- project columns;
- issue creation from project context through Cactus intake.

Admins manage projects. Normal users only see projects and issues they can access.

## 6. Issue Intake

URL:

- `/<account_slug>/cactus_issues/new`

This is the focused issue creation form replacing the generic Fizzy card form.

Fields:

- project;
- title;
- priority;
- problem description;
- reproduction steps;
- expected behavior;
- actual behavior;
- environment context;
- additional evidence;
- attachments/files/screenshots.

Behavior:

- users can create a complete issue;
- users can save sparse/draft issues when they do not have all data yet;
- UI shows Gate 1 readiness;
- UI shows missing Gate 1 fields;
- attachments and additional evidence stay separate from required Gate 1 fields.

## 7. Card / Issue Detail

URL:

- `/<account_slug>/cards/:id`

Issue detail shows:

- title and description;
- discussion/comments;
- workflow state;
- Gate 1 status;
- Gate 2 status;
- structured training data;
- Asana source context for imported issues;
- attachments;
- code evidence;
- AI suggestions;
- duplicate suggestions;
- role-specific actions.

Reporters see reporter-oriented data. Developers/support/reviewers/admins see internal Cactus context.

## 8. Gate 1 - Reporter Side

Gate 1 is complete when these fields are filled:

- problem description;
- reproduction steps;
- expected behavior;
- actual behavior;
- environment context.

If Gate 1 is incomplete:

- the issue remains in `needs_info`;
- UI shows missing fields;
- AI/review can suggest what is missing;
- the issue is not considered ready for normal triage/developer flow.

## 9. Cactus Queue

URL:

- `/<account_slug>/cactus_queues`

Cactus Queue is the main support/triage queue.

Workflow filters:

- draft;
- needs_info;
- open;
- in_progress;
- needs_review;
- resolved;
- closed.

Main actions:

- view issues by state;
- see missing Gate fields;
- triage;
- assign a developer;
- claim an issue;
- classify an issue;
- move to Gate 2;
- mark resolved when ready.

The queue uses a responsive card layout instead of wide tables so actions stay usable on different screen sizes.

## 10. Classification

Issues support structured classification fields:

- priority;
- category;
- domain;
- severity;
- suggested primitives.

These fields are used in:

- queue;
- My Work;
- AI context;
- dashboard metrics;
- training metadata.

## 11. My Work

URL:

- `/<account_slug>/cactus_work`

Developer-focused workflow page.

Shows:

- assigned active issues;
- issues needing Gate 2;
- ready-to-claim issues;
- needs-review issues;
- recently resolved issues.

Actions:

- claim issue;
- open Gate 2 form;
- fill root cause/fix/verification;
- add code evidence;
- mark resolved.

## 12. Gate 2 - Developer Side

URL:

- `/<account_slug>/cards/:id/resolution_record/edit`

Gate 2 contains:

- root cause;
- fix summary;
- verification steps;
- linked commit SHAs;
- linked PR URLs.

An issue cannot be correctly resolved until:

- root cause is filled;
- fix summary is filled;
- verification steps are filled;
- code evidence exists through GitHub code links or manual commit/PR fields.

This friction is intentional: the system should produce high-quality training examples, not only closed tasks.

## 13. Resolve Flow

Normal resolve path:

1. Gate 1 is complete.
2. Issue is triaged and assigned.
3. Developer fills Gate 2.
4. Developer adds code evidence.
5. Issue reaches needs_review.
6. Developer/support/admin clicks Mark resolved.
7. The system creates a TrainingExample in `pending_review`.

## 14. Training Examples

URLs:

- `/<account_slug>/training_examples`
- `/<account_slug>/training_examples/:id`

TrainingExample is a separate reviewable dataset entity.

Statuses:

- draft;
- pending_review;
- approved;
- rejected;
- exported.

Contains:

- input context;
- Gate 1 problem data;
- Gate 2 resolution data;
- code evidence;
- metadata;
- review notes;
- reviewer;
- timestamps.

Reviewer/Admin can:

- open an example;
- inspect structured context;
- inspect JSONL preview;
- approve;
- reject;
- leave review notes.

## 15. JSONL Export

URLs:

- `/<account_slug>/training_example_exports`
- `/<account_slug>/training_example_exports/:id`

Export only works with approved examples.

Behavior:

- approved examples are reserved for an export batch;
- export runs as an async job;
- a TrainingExampleExport batch is created;
- the batch stores filename, count, status, user, and timestamp;
- completed exports can be downloaded again;
- failed exports show a recovery state;
- examples are released on failure so export can be retried.

Export format is JSONL: one line equals one training example.

## 16. Asana Import

URLs:

- `/<account_slug>/legacy_imports/asana/new`
- `/<account_slug>/legacy_imports/asana/issues`

Asana import brings historical tasks into Cactus.

Supported:

- JSON export upload;
- destination project selection;
- async import job;
- import status page;
- created/skipped/failed counters;
- idempotent re-import;
- duplicate detection by account/source/external id;
- source metadata;
- original Asana task link;
- imported reporter/assignee;
- comments;
- attachments;
- GitHub links from notes/comments;
- legacy status.

Legacy issues can be:

- `needs_structuring`;
- `structured`;
- `training_candidate`.

Unresolved legacy tasks can be structured with Gate 1 only. Training data requires a real developer resolution/Gate 2.

## 17. Legacy Structuring

On the legacy review queue, users can:

- view original Asana context;
- view missing Gate fields;
- apply AI structuring suggestions;
- manually fill Gate 1/Gate 2;
- create a training candidate if all data is complete;
- open the normal card detail page.

The system does not pretend historical tasks are clean data. Legacy data is explicitly marked and requires structuring/review.

## 18. GitHub Integration

URLs:

- `/<account_slug>/cactus_integrations`
- `/<account_slug>/github/webhook`

GitHub integration links real code changes to issues.

Functionality:

- webhook endpoint;
- signed webhook validation;
- delivery recording;
- idempotency by GitHub delivery id;
- issue reference parsing;
- commit and PR linking to cards;
- failed delivery status;
- retry failed delivery;
- webhook health dashboard metrics;
- code evidence on issue detail;
- code evidence on Gate 2 page;
- code evidence in AI/training context.

Code evidence can arrive automatically from GitHub or be added manually through Gate 2 fields.

## 19. AI Assistance

The AI layer is provider-agnostic: the product is not hard-wired to one AI provider.

AI actions are stored as `AiRun` records and run through jobs.

Supported:

- quality review;
- Gate 1 structuring suggestion;
- legacy Asana structuring suggestion;
- category/domain/severity suggestions;
- duplicate issue suggestions;
- Gate 2 draft resolution from code evidence;
- explicit apply suggestion action;
- dismiss suggestion;
- audit trail;
- auto-refresh for pending AI blocks.

Important rules:

- AI does not silently write final data;
- AI suggestions only fill blank fields where applicable;
- human control remains required;
- applied/dismissed suggestions stop showing as active.

## 20. Dashboard

URL:

- `/<account_slug>/cactus_dashboard`

Dashboard shows pipeline health.

Metrics:

- active backlog;
- Gate 1 completion;
- Gate 2 completion;
- GitHub evidence coverage;
- training export rate;
- AI suggestion acceptance;
- pending training review;
- failed GitHub deliveries;
- legacy import health;
- trend windows: 7/30/90 days.

Reviewer/Admin uses it for operational visibility.

## 21. Audit Log

URL:

- `/<account_slug>/cactus_audit_events`

Audit events record important actions:

- user/role changes;
- project changes;
- issue creation;
- Gate updates;
- triage;
- assignment;
- resolution;
- training review/export;
- Asana retry/import;
- GitHub retry/delivery events.

Audit log stores safe metadata and must not store raw passwords or large payloads.

## 22. Admin Settings

Admin can:

- create users;
- assign account role;
- assign Cactus role;
- manage project access;
- view integrations;
- view audit;
- manage account-level settings.

`Account Settings` is hidden from non-admin users because user and role management is admin-only.

## 23. Async Jobs

ActiveJob runs:

- Asana JSON import;
- JSONL training export;
- AI suggestion/review runs.

This prevents heavy operations from blocking web requests.

UI shows pending/processing/completed/failed states where needed.

## 24. Error States

Explicit error states exist for:

- invalid Asana JSON;
- per-task Asana import failure;
- duplicate/skipped Asana task;
- failed JSONL export;
- failed GitHub webhook delivery;
- invalid GitHub signature;
- missing GitHub secret;
- failed AI run.

Where possible, UI provides a recovery action: retry, corrected re-import, back to approved examples, or retry GitHub delivery.

## 25. Main Happy Path

1. Reporter creates an issue through New Issue.
2. Reporter fills Gate 1.
3. Support sees the issue in Queue.
4. Support classifies the issue and assigns a developer.
5. Developer sees the issue in My Work.
6. Developer fills Gate 2.
7. Developer adds a commit SHA or PR URL.
8. Developer clicks Mark resolved.
9. The system creates a TrainingExample in pending_review.
10. Reviewer opens Training Examples.
11. Reviewer checks JSONL preview.
12. Reviewer approves or rejects.
13. Approved examples are exported to JSONL.
14. Export batch is stored in history.
15. Dashboard shows pipeline health.

## 26. Main Asana Legacy Path

1. Admin/support opens Asana Import.
2. User uploads a JSON export.
3. The system imports tasks asynchronously.
4. Imported tasks appear as legacy issues.
5. Reviewer/support opens the legacy review queue.
6. The system shows original Asana notes, comments, attachments, and links.
7. User structures the legacy issue manually or through AI suggestion.
8. If Gate 1/Gate 2 are complete, a training candidate is created.
9. TrainingExample follows the normal review/export flow.

## 27. Test Coverage

The implementation has coverage for:

- login/password flow;
- user creation;
- role permissions;
- Cactus Home/menu visibility;
- issue intake;
- queue;
- My Work;
- Gate 1/Gate 2;
- resolve guard;
- GitHub webhook/security/idempotency/retry;
- Asana import/idempotency/retry;
- training review/export;
- dashboard metrics;
- audit events;
- async AI jobs;
- end-to-end happy path.

## 28. Important Notes

- Cactus is built on top of Fizzy, so some internal models are still named `Card` and `Board`.
- In the Cactus user-facing UI, these should be understood as `Issue` and `Project`.
- Comments do not replace structured data.
- Training corpus should only include reviewed/approved examples.
- AI assists users but should not silently overwrite human-entered fields.
- Historical Asana tasks are useful, but they are not clean training data until they are structured and reviewed.
