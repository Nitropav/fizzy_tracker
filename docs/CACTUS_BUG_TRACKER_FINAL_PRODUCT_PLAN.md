# Cactus Bug Tracker Final Product Plan

## Purpose

Cactus Bug Tracker is a focused bug/task tracker for the ES Windows product team.

The current team workflow is:

- managers, support, and testers use the product and find bugs or product tasks;
- they create issues in Asana;
- developers pick those issues up, implement fixes or tasks, and report what changed;
- useful resolved issues should become structured training data for the ES Windows operator model.

The final product should replace this Asana-centered workflow inside the Fizzy interface, while keeping only the Fizzy primitives that help this goal.

This is not a generic project-management product.
It is a structured bug/task workflow plus a training-data pipeline.

## Product Goal

Build a clean workflow:

1. Reporter creates a bug/task in a project.
2. System guides the reporter to provide complete problem context.
3. Support or manager triages the issue.
4. Developer claims or receives the issue.
5. Developer fills resolution details and links code evidence.
6. Issue is reviewed, resolved, and closed.
7. Completed high-quality issues become reviewable training examples.
8. Approved training examples are exported as JSONL.

## Core Product Concepts

### Project

Represents a product area, customer area, or engineering queue.
Implemented with Fizzy `Board`.

The UI should call this `Project` unless there is a strong reason to keep `Board`.

### Issue

Represents a bug, task, feature request, support investigation, or configuration problem.
Implemented with Fizzy `Card`.

The UI should call this `Issue` or `Bug/Task`, not `Card`.

### Comment

Conversation around an issue.
Implemented with Fizzy `Comment`.

Comments are discussion only.
They are not the source of truth for structured Gate 1 / Gate 2 data.

### Activity

Audit trail for issue changes, comments, assignments, state changes, and integrations.
Implemented with Fizzy `Event` where possible.

### Training Example

Structured, reviewable dataset item generated from a completed issue.
Implemented with `TrainingExample`.

## Roles

### Reporter

Typical users:

- manager
- support agent
- tester
- customer-facing operator

Can:

- create issues;
- answer Gate 1 questions;
- comment;
- verify a fix if required;
- see issues they are allowed to access.

Should not need:

- generic Fizzy board customization;
- advanced workspace settings;
- training export access.

### Developer

Can:

- view assigned/open issues;
- claim issues;
- move issues into active work;
- fill Gate 2 fields;
- link commits and PRs;
- mark issue ready for review/resolution.

Should see:

- issue context;
- reproduction details;
- expected/actual behavior;
- environment;
- linked code evidence;
- missing resolution fields.

### Support / Manager

Can:

- view intake queue;
- triage issues;
- assign developers;
- request more info from reporters;
- set category/domain/severity;
- manage issue priority.

### Reviewer / Admin

Can:

- review training examples;
- approve/reject examples;
- export JSONL;
- manage integrations;
- view pipeline dashboard;
- configure projects and roles.

## Target Issue Lifecycle

The visible lifecycle should be:

1. `Draft`
2. `Needs info`
3. `Open`
4. `Triaged`
5. `In progress`
6. `Needs review`
7. `Resolved`
8. `Closed`

### Draft

Issue is being created.

### Needs info

Gate 1 is incomplete.
System should clearly show what information is missing.

### Open

Gate 1 is complete.
Issue is ready for support/manager triage.

### Triaged

Issue has priority/category/owner/project context and is ready for developer work.

### In progress

Developer has claimed or been assigned the issue.

### Needs review

Gate 2 is complete.
Issue can be reviewed before resolution.

### Resolved

Fix is complete and a training example candidate has been generated.

### Closed

Training example review is complete, or product policy says the issue can be archived.

## Gate 1: Reporter Side

Gate 1 is required before the issue enters the normal work queue.

Required fields:

- problem description;
- reproduction steps;
- expected behavior;
- actual behavior;
- environment context.

Recommended fields:

- category;
- domain;
- severity;
- affected customer/account;
- affected product area;
- screenshots/attachments;
- suspected component.

Behavior:

- sparse submissions are allowed;
- incomplete issues enter `Needs info`;
- UI asks for one missing item at a time;
- LLM can suggest what is missing, but the saved fields remain structured.

## Gate 2: Developer Side

Gate 2 is required before an issue can be resolved.

Required fields:

- root cause;
- fix summary;
- verification steps;
- linked commit SHA or explicit manual explanation if no commit exists.

Recommended fields:

- linked PR URL;
- rollout notes;
- affected files/components;
- regression risk;
- test evidence.

Behavior:

- developer cannot mark resolved until Gate 2 is complete;
- if commits/PRs are tagged with issue id, system links them automatically;
- if automatic linking is missing, UI shows clear call-to-action.

## Main UI Surfaces

### 1. Issue Intake

Purpose:

- create a new bug/task quickly;
- guide the reporter through Gate 1.

Required UI:

- project selector;
- title;
- description;
- Gate 1 fields;
- attachment upload;
- save as draft;
- submit issue.

Nice-to-have:

- AI "what is missing?" helper;
- suggested severity/domain;
- duplicate issue suggestions.

### 2. My Issues

Purpose:

- let reporters and developers see relevant issues.

Required UI:

- assigned to me;
- reported by me;
- waiting on me;
- recently updated.

### 3. Cactus Queue

Purpose:

- support/manager operational queue.

Required filters:

- Needs info;
- Open;
- Triaged;
- In progress;
- Needs review;
- Resolved;
- Closed.

Required actions:

- ask for missing info;
- assign developer;
- set priority;
- set category/domain;
- move to active work;
- review resolution.

### 4. Developer Work View

Purpose:

- give developers a focused work queue.

Required sections:

- assigned to me;
- unassigned ready issues;
- needs Gate 2;
- needs review;
- recently resolved.

Required actions:

- claim;
- fill Gate 2;
- link commit/PR;
- mark ready for review;
- mark resolved when allowed.

### 5. Issue Detail

Purpose:

- single source of truth for one issue.

Required layout:

- title and status;
- reporter and assignee;
- priority/category/domain;
- Gate 1 panel;
- Gate 2 panel;
- linked commits/PRs;
- comments;
- activity history;
- attachments;
- training example status if generated.

### 6. Training Examples

Purpose:

- review dataset candidates.

Required UI:

- pending review;
- approved;
- rejected;
- exported;
- approve/reject with notes;
- inspect generated JSONL preview;
- export approved examples.

### 7. Admin / Settings

Purpose:

- configure only what the product needs.

Required UI:

- users and roles;
- projects;
- GitHub webhook settings;
- Asana import;
- export settings;
- pipeline dashboard.

## Fizzy Features To Keep

Keep and adapt:

- account scoping;
- users and identities;
- boards as projects;
- cards as issues;
- comments;
- events/activity;
- assignments;
- tags if useful for category/domain;
- attachments;
- search;
- notifications if not too noisy;
- import/export foundations;
- webhook foundations.

## Fizzy Features To Hide Or De-Emphasize

Hide from primary Cactus UI unless needed:

- generic "Maybe?" terminology;
- generic card-board vocabulary;
- broad board customization for non-admins;
- pins stack;
- watching controls for basic users;
- advanced hotkeys;
- public board publishing;
- generic social/collaboration features not related to bug workflow;
- visual board features that distract from issue triage.

The code does not need to delete these immediately.
The first step is to route normal users into focused Cactus screens and hide unnecessary navigation.

## Data Model Direction

Use Fizzy primitives where possible:

- `Board` as project;
- `Card` as issue;
- `Comment` as conversation;
- `Event` as activity;
- `User` as actor.

Add Cactus-specific structured models:

- `Card::ResolutionRecord` for Gate 1 / Gate 2 data;
- `TrainingExample` for dataset lifecycle;
- `TrainingExampleExport` for JSONL export batches and repeatable download history;
- `Card::CodeLink` for commits and PRs;
- `AiRun` / `AiSuggestion` for AI output and audit;
- optional role/permission model if Fizzy roles are too broad.

## Integrations

### Asana

Purpose:

- import historical tasks;
- preserve old context;
- mark imported issues as legacy.

Rules:

- imported issues should not pretend to be fully structured;
- legacy issues should be marked `needs_structuring` until reviewed;
- LLM may help structure legacy issues;
- human approval is still required before training export.

### GitHub

Purpose:

- link code evidence automatically.

Rules:

- parse issue references like `CT-1234`;
- link commits and PRs to issues;
- make webhook ingestion idempotent;
- expose linked code evidence in Gate 2 and training examples.

### AI Service

Purpose:

- assist, not silently mutate.

Rules:

- read-only first;
- store AI output separately;
- user applies suggestions explicitly;
- all AI runs are auditable.

## Training Data Pipeline

The training pipeline is downstream of the issue workflow.

Flow:

1. Issue reaches `Resolved`.
2. Gate 1 and Gate 2 are complete.
3. System generates a `TrainingExample`.
4. Example enters `pending_review`.
5. Reviewer approves or rejects.
6. Approved examples are exported as JSONL.
7. Exported examples are marked `exported`.

Nothing unresolved or unreviewed should enter the final corpus.

## Required MVP

The minimum product that is worth testing with real users:

1. focused issue intake;
2. roles for reporter, developer, admin/reviewer;
3. Cactus Queue with clear states;
4. developer Gate 2 workflow;
5. assignment/claim flow;
6. GitHub code linking;
7. training example generation;
8. review queue;
9. JSONL export;
10. Asana import for historical data.

## Implementation Phases

### Phase 1: Product Navigation Cleanup

Goal:

- make the app feel like Cactus Bug Tracker, not generic Fizzy.

Status:

- Done for the primary Cactus navigation surface.
- Done: Cactus-focused home screen at `/cactus_home`.
- Done: root path now opens Cactus Home instead of the generic activity feed.
- Done: dedicated Cactus menu section with Cactus Home, Cactus Queue, My Work, Projects, and admin pipeline links.
- Done: moved Cactus-specific links out of generic Settings.
- Done: primary Cactus screens link back to Cactus Home instead of generic Fizzy home.
- Done: visible board navigation labels now use Project terminology where safe.
- Done: non-admin menu hides generic Fizzy sections such as Tags, People, and Shortcuts.
- Done: the project board primary action routes to structured `New issue` intake instead of generic blank card creation.
- Done: login/account/menu/search labels now use Cactus wording on the primary web UI.

Tasks:

- rename visible concepts where safe: Cards -> Issues, Boards -> Projects; DONE
- create Cactus-focused home/dashboard; DONE
- simplify primary navigation; DONE
- hide unnecessary Fizzy menu entries for non-admins; DONE
- add clear links to Issues, Queue, My Work, Training Examples, Admin; DONE

Exit criteria:

- a new user can understand where to create, triage, work, and review issues.

### Phase 2: Roles And Permissions

Goal:

- align access with real team responsibilities.

Status:

- Done for the primary Cactus roles and project management boundaries.
- Done: added Cactus-specific `cactus_role` on users without replacing Fizzy owner/admin/member/system roles.
- Done: supported Cactus roles are `reporter`, `developer`, `support`, and `reviewer`; Fizzy admins/owners remain Cactus superusers.
- Done: Account Settings can update each user's Cactus role.
- Done: backend guards protect Cactus Queue, My Work, Training Examples, Dashboard, Integrations, Asana import, triage, assignment, claim, Gate 1, Gate 2, and resolve actions.
- Done: Cactus navigation/home hides actions the current role cannot use.
- Done: project creation, project settings, project columns, publication, and webhook configuration are restricted to Cactus project/admin roles.
- Done: reporter-facing issue detail hides internal developer-only Gate 2, code evidence, and AI review controls.
- Done: role enforcement is covered by controller/model tests.

Tasks:

- define reporter/developer/support/admin/reviewer behavior; DONE
- map existing Fizzy roles where possible; DONE
- restrict training export to admins/reviewers; DONE
- restrict project settings to admins; DONE
- ensure reporters cannot access internal developer-only data if not allowed. DONE

Exit criteria:

- each role sees the right screens and actions.

### Phase 3: Issue Intake UI

Goal:

- replace Asana issue creation with structured Cactus intake.

Status:

- Done for the primary structured issue intake flow.
- Done: focused `New Issue` flow at `/cactus_issues/new`.
- Done: Cactus Home and Cactus menu route users to the focused issue intake flow.
- Done: issue intake lets reporters select a project and submit full or sparse Gate 1 data.
- Done: project-level `New issue` and Cactus `New Issue` share one issue creation service.
- Done: focused issue intake supports saving empty or partial issues as drafts.
- Done: intake shows Gate 1 readiness and missing-field prompts before submit.
- Done: intake supports rich-text additional evidence and explicit multi-file evidence uploads so reporters can add screenshots, logs, files, links, and context without polluting required Gate 1 fields.
- Done: issue detail shows all missing Gate 1 items inline while the next reporter answer remains actionable.
- Done: focused issue intake is covered by controller tests.

Tasks:

- build focused "New Issue" screen; DONE
- make Gate 1 fields first-class; DONE
- support sparse issue creation; DONE
- show next missing Gate 1 item; DONE
- support attachments; DONE
- create clear submit/save draft actions; DONE

Exit criteria:

- manager/tester can create a useful issue without understanding the training pipeline.

### Phase 4: Queue And Triage

Goal:

- make support/manager triage fast.

Status:

- Done for the primary developer close guard.
- Done: queue filters are available for Cactus workflow states.
- Done: open issues expose inline triage into project columns.
- Done: projects with no columns show a setup CTA instead of a broken triage form.
- Done: in-progress issues show current assignees and an inline assign-developer action.
- Done: queue rows expose inline priority/category/domain/severity controls backed by structured resolution data.
- Done: priority/category/domain/severity use controlled preset selectors while preserving legacy/custom values.
- Done: priority is a first-class field on resolution records and is visible in intake, queue, My Work, AI context, and training metadata.
- Done: in-progress queue rows expose a direct Claim action for unassigned ready issues.
- Done: queue rows use responsive issue cards instead of a wide table, so classification and next actions stay visible on narrow screens.
- Done: resolve actions are only available when an issue is actually in review state.

Tasks:

- improve Cactus Queue layout; DONE
- add priority/category/domain controls; DONE
- add assign developer action; DONE
- add claim action; DONE
- handle boards/projects with no columns gracefully; DONE
- add project setup CTA where needed. DONE

Exit criteria:

- open issue can be moved to developer work without manual DB setup.

### Phase 5: Developer Workflow

Goal:

- make developer work explicit and hard to close incorrectly.

Status:

- Done for the primary developer close guard.
- Done: focused `My Work` page at `/cactus_work`.
- Done: assigned active issues, Gate 2 work, needs-review work, ready-to-claim issues, and recently resolved issues are visible in one developer-oriented screen.
- Done: ready-to-claim issues expose a claim action.
- Done: `My Work` uses Postgres-safe association loading and is covered by controller tests.
- Done: claim action supports normal HTML redirects from the developer workflow.
- Done: focused Gate 2 resolution page at `/cards/:card_id/resolution_record/edit`.
- Done: queue and My Work `Fill/Review` actions route developers to the focused Gate 2 page.
- Done: Gate 2 form supports root cause, fix summary, verification steps, commit SHAs, and PR URLs.
- Done: resolving is blocked unless Gate 2 text fields are complete and code evidence exists through linked GitHub code or manual commit/PR fields.

Tasks:

- build `My Work` / Developer Queue; DONE
- show assigned issues; DONE
- show missing Gate 2 fields; DONE
- add focused Gate 2 form; DONE
- add commit/PR linking UI; DONE
- block resolve until Gate 2 is complete. DONE

Exit criteria:

- developer can take an issue from assignment to resolved with structured fix data.

### Phase 6: GitHub Integration

Goal:

- ground resolutions in real code changes.

Status:

- Done for the primary GitHub webhook flow.
- Done: GitHub webhook/parsing foundation links commits and pull requests to issues through `Card::CodeLink`.
- Done: linked code evidence is visible on issue detail.
- Done: linked code evidence is visible on the focused Gate 2 developer page.
- Done: code links are included in AI/training context.
- Done: admin integrations page documents GitHub webhook URL, secret status, events, and issue reference format.
- Done: incoming GitHub webhook deliveries are recorded with delivery id, event, status, linked reference count, payload digest, processed timestamp, and error state.
- Done: GitHub webhook processing is idempotent by `X-GitHub-Delivery`; duplicate processed deliveries return the stored result without relinking code.
- Done: Cactus Integrations shows recent GitHub delivery status for operational visibility.
- Done: Cactus Integrations now provides a setup checklist, required GitHub events, CT reference examples, delivery health cards, payload digests, and a dedicated failed-deliveries section.
- Done: failed GitHub deliveries keep a payload snapshot and can be retried from the integrations UI.

Tasks:

- finalize webhook settings UI; DONE
- parse issue references from commits/PRs; DONE
- display linked code on issue detail; DONE
- include code links in training context; DONE
- add retry/idempotency behavior. DONE

Exit criteria:

- tagged commit or PR appears on the issue automatically.

### Phase 7: Training Review And Export

Goal:

- make dataset generation usable by admins/reviewers.

Status:

- Done for the primary reviewer/export workflow.
- Done: pending/rejected examples expose approve/reject review actions.
- Done: approved/exported examples hide review actions and display stored review notes read-only.
- Done: direct review POSTs are blocked after an example leaves review.
- Done: training example detail includes a JSONL preview for reviewer inspection.
- Done: training example detail now separates issue overview, Gate 1 reporter context, Gate 2 developer resolution, code evidence, and export metadata.
- Done: approved examples show clear export readiness and a disabled export state when nothing is ready.
- Done: JSONL exports are stored as export batches with filename, exported examples, user, count, timestamp, and repeat download.
- Done: training example list links to export history and recent export batches.

Tasks:

- improve training example list and detail UI; DONE
- add JSONL preview; DONE
- add approve/reject notes; DONE
- add export confirmation/status; DONE
- add exported history. DONE

Exit criteria:

- reviewer can confidently approve examples and export corpus.

### Phase 8: Asana Migration

Goal:

- bring historical work into Cactus without pretending it is clean data.

Status:

- In progress.
- Done: Asana JSON import creates legacy issues with source, external id, original metadata, legacy status, and `needs_structuring`.
- Done: duplicate Asana tasks are skipped by account/source/external id.
- Done: Cactus Home, Cactus menu, and import summary link to a dedicated legacy Asana review queue.
- Done: legacy Asana review queue filters `needs_structuring`, `structured`, and `all` imported issues.
- Done: legacy review rows show project, Asana source id, original task link, Gate 1/Gate 2 status, missing fields, and direct `Structure issue` action.
- Done: fully structured legacy issues show `Ready for training candidate`.
- Done: reviewers/admins can generate a pending-review `TrainingExample` from a fully structured legacy Asana issue.
- Done: incomplete legacy issues are blocked from training example generation with explicit missing Gate field messaging.
- Done: repeated generation reuses existing draft/pending candidates instead of creating duplicates.

Tasks:

- finalize Asana import UI; DONE
- map Asana fields to issue/Gate fields; DONE
- mark legacy imports; DONE
- expose `needs_structuring` queue; DONE
- allow AI-assisted structuring; DONE
- allow human review before training example generation. DONE

Exit criteria:

- old Asana tasks can become structured Cactus issues or training candidates.

### Phase 9: AI Assistance

Goal:

- reduce manual effort without losing human control.

Status:

- In progress.
- Done: AI assistance remains provider-agnostic through service boundaries and `AiRun` audit records.
- Done: card quality review already records read-only AI/deterministic output without auto-writing to issues.
- Done: legacy Asana issues can generate deterministic structuring suggestions into `AiRun` with `run_type = legacy_issue_structuring`.
- Done: legacy structuring suggestions show suggested fields, warnings, provenance, and generated timestamp in the review queue.
- Done: users must explicitly apply a legacy structuring suggestion before any Gate fields are changed.
- Done: regular Cactus issues can generate deterministic Gate 1 and classification suggestions into `AiRun` with `run_type = issue_structuring`.
- Done: card detail shows the latest issue structuring suggestion with suggested fields, warnings, provenance, generated timestamp, and an explicit apply action.
- Done: Gate 2 can generate deterministic resolution drafts from linked code evidence and structured issue context into `AiRun` with `run_type = resolution_draft`.
- Done: card detail and Gate 2 edit page show the latest resolution draft with evidence-aware warnings, provenance, generated timestamp, and explicit apply action.
- Done: regular Cactus issues can run a read-only duplicate check into `AiRun` with `run_type = duplicate_issue_suggestion`.
- Done: card detail shows duplicate candidates with score, reason, project, workflow state, and direct issue links without changing the issue.
- Done: applying any structuring suggestion only fills blank structured fields, respects the user's role permissions, and does not overwrite existing human-entered data.
- Done: AI suggestions can be explicitly dismissed without deleting audit history; dismissed/applied suggestions stop showing as active suggestions.

Tasks:

- Gate 1 completeness review; DONE
- Gate 2 completeness review; DONE
- category/domain/severity suggestions; DONE
- duplicate issue suggestions; DONE
- draft resolution from linked code evidence; DONE
- suggestion apply/reject flow; DONE

Exit criteria:

- AI helps users complete structured data, but all final writes are explicit.

### Phase 10: Dashboard And Operations

Goal:

- make the system measurable.

Status:

- In progress.
- Done: dashboard shows action-oriented operational alerts for reporter info gaps, pending training review, export-ready examples, failed GitHub webhooks, and active AI suggestions.
- Done: dashboard shows top KPI cards for active backlog, Gate 1 completion, Gate 2 completion, GitHub evidence coverage, training export rate, and AI suggestion acceptance.
- Done: `CactusPipelineMetrics` calculates backlog health, bottleneck state, Gate completion rates, training export metrics, GitHub webhook health, AI suggestion usage, and operational alerts.
- Done: dashboard includes detailed Backlog Health, Training Exports, GitHub Webhooks, and AI Suggestion Types sections.
- Done: dashboard supports activity windows for the last 7, 30, and 90 days.
- Done: dashboard shows daily trends for new issues, Gate completions, training example creation/export, GitHub webhook failures, and AI suggestion completion.
- Done: metrics service memoizes repeated snapshot calculations to avoid duplicate dashboard queries.
- Done: dashboard metrics are covered by service/controller tests.

Tasks:

- pipeline metrics dashboard; DONE
- Gate 1 completion rate; DONE
- Gate 2 completion rate; DONE
- unresolved queue health; DONE
- training approval/rejection rates; DONE
- export history; DONE
- GitHub linkage coverage; DONE
- AI suggestion usefulness; DONE
- trend charts / time-window filters; DONE
- slow query review for production-sized datasets; PARTIAL

Exit criteria:

- team can see if the tracker is producing useful issues and useful training data.

### Phase 11: Production Hardening

Goal:

- make the product reliable for real use.

Status:

- In progress.
- Done: GitHub webhook endpoint returns explicit JSON errors for missing server secret, missing signature, invalid signature, missing delivery id, missing event, invalid JSON, and unexpected processing failures.
- Done: signed but invalid/failed GitHub deliveries are recorded as failed deliveries so admins can inspect and retry them from Integrations.
- Done: GitHub integrations page documents webhook security and error behavior for admins.
- Done: webhook hardening is covered by controller tests.
- Done: production email/password login path is standardized with generic credential errors, safe missing-parameter handling, 12-character password policy for new/reset passwords, password confirmation for signup/reset, reset-session invalidation, and consistent join-code onboarding policy.
- Done: production login/onboarding behavior is covered by session, password reset, signup, join-code, identity, signup model, mailer, and flat JSON API tests.
- Done: full happy-path integration coverage verifies issue intake -> Gate 1 -> triage -> claim -> Gate 2 -> resolve -> training review -> JSONL export.

Tasks:

- pagination and performance for large issue volume;
- async jobs for AI/import/export;
- robust error states; PARTIAL
- audit logs;
- webhook security; PARTIAL
- production email/password login; DONE
- backup/restore expectations;
- seed/setup flow for new accounts/projects;
- system tests for the full happy path. PARTIAL

Exit criteria:

- product can be used by the team without manual developer intervention.

## Immediate Next Implementation Steps

Recommended next steps from the current state:

1. Build a focused Cactus home/dashboard that routes users to Projects, Issues, Queue, My Work, Training Examples, and Admin. DONE
2. Rename or wrap visible `Card` and `Board` terminology in Cactus screens. DONE
3. Add first-class role/permission rules for reporter/developer/reviewer/admin. DONE
4. Improve issue intake UI so managers/testers do not use generic board/card screens. DONE
5. Improve Cactus Queue assignment and claim actions. DONE
6. Add a focused Developer Work page. DONE
7. Finish GitHub settings UI and code-link visibility.
8. Continue polishing training review/export. IN PROGRESS

## Definition Of Done

The final product is done when:

- managers/testers can create issues without Asana;
- developers can work assigned issues without guessing what to fill;
- unresolved/blocked states are visible and actionable;
- every resolved issue has structured Gate 1 and Gate 2 data;
- commits/PRs are linked when available;
- high-quality resolved issues generate training examples;
- reviewers can approve/reject/export examples;
- normal users are not exposed to unnecessary Fizzy complexity;
- admins can configure projects, users, integrations, and exports.
