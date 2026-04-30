# Cactus Bug Tracker Master Roadmap

## Purpose

This document is the master implementation roadmap for implementing the Cactus Bug Tracker inside the `fizzy_tracker` interface.

It combines:

- the functional and technical target from [cactus_bug_tracker_mvp.pdf](/D:/work/fizzy_tracker/docs/cactus_bug_tracker_mvp.pdf)
- the already completed PostgreSQL stabilization work
- the previously discussed AI/training-data direction

This is not just a bug tracker plan.
The system goal is:

1. track real customer issues,
2. enforce structured issue resolution,
3. connect fixes to code evidence,
4. generate reviewable training data,
5. continuously improve the ES Windows operator model from real production issues.

## Implementation Frame

The PDF is the source of truth for the desired product behavior:

- structured bug intake
- Gate 1 reporter-side enforcement
- Gate 2 developer-side enforcement
- LLM-assisted clarification and resolution drafting
- Git commit linking through ticket tags
- training example generation
- review and JSONL corpus export

The implementation target for this project is the Fizzy interface and Fizzy data model.

That means:

- we keep the customer/support/developer/admin experiences inside Fizzy-style screens
- we use Fizzy primitives where they fit
- we extend `Card` instead of building a separate parallel ticket tracker
- we preserve Fizzy navigation, account scoping, permissions, comments, events, and board workflow
- we still follow the PDF's technology direction: PostgreSQL, async LLM jobs, and git webhook ingestion

The PDF mentions a Rails engine for the existing ES Windows codebase. For this project, that requirement is interpreted as portability and clean boundaries, not as a mandate to abandon Fizzy UI. If the feature later needs to move into ES Windows directly, the structured models and services should be separable enough to extract.

## Final Product Definition

The target system is a structured bug-resolution and training-data pipeline presented through the Fizzy UI and built on top of Fizzy primitives.

Core mapping inside Fizzy:

- `Ticket` -> `Card`
- `TicketComment` -> `Comment`
- `TicketEvent` -> `Event`
- `Queue / project / product area` -> `Board`
- `TrainingExample` -> new model
- `Gate 1 / Gate 2 resolution data` -> new structured model(s) around `Card`

Three main user-facing surfaces:

- customer-facing Fizzy portal for creating tickets, answering LLM questions, and verifying fixes
- support queue inside Fizzy for triage, assignment, and communication
- developer view inside Fizzy for claiming tickets, linking commits, and completing Gate 2

Three admin/ops surfaces:

- training example review queue
- export/corpus management
- model quality / pipeline health dashboard

Technology target:

- Fizzy Rails app as the current UI host
- PostgreSQL for persistent data
- async jobs for LLM work and external API calls
- git/GitHub webhook endpoint for commit and PR parsing
- JSONL export for approved training examples

## Product Rules From MVP Definition

The MVP definition in the PDF gives the non-negotiable product rules:

- Every ticket must become structured.
- Gate 1 is required before the ticket enters the queue.
- Gate 2 is required before the ticket can be closed.
- LLM is not the source of truth; humans review and approve.
- Commits should be linked automatically through ticket tags when possible.
- Completed tickets should generate reviewable training examples.
- Historical imports are allowed, but must be marked as legacy and treated differently.

Gate 1 fields:

- problem description
- reproduction steps
- expected behavior
- actual behavior
- environment context

Gate 2 fields:

- root cause
- fix description
- linked commit SHA(s)
- verification steps

Target lifecycle:

- `draft`
- `needs_info`
- `open`
- `in_progress`
- `needs_review`
- `resolved`
- `closed`

## What Is Already Done

The platform/foundation layer has already moved substantially:

- local Docker runtime with `web + jobs + db`
- PostgreSQL-backed development/test path
- PostgreSQL UUID adaptation
- adapter-safe migration/schema fixes
- PostgreSQL search fallback backend
- green standard test pass on PostgreSQL
- structured `Card::ResolutionRecord` data layer started for Gate 1 / Gate 2 fields
- `Card::Resolvable` association layer added so Fizzy `Card` remains the ticket primitive
- completeness checker service added for structured gate status and missing-field reporting

Reference:

- [POSTGRES_ADAPTATION_PLAN.md](/D:/work/fizzy_tracker/docs/POSTGRES_ADAPTATION_PLAN.md)
- [stabilization.md](/D:/work/fizzy_tracker/docs/stabilization.md)

This means the project is no longer blocked on basic runtime viability.

## Delivery Strategy

The correct delivery order is:

1. finish platform confidence,
2. add structured data layer around cards,
3. add review/export pipeline,
4. add GitHub enrichment,
5. add AI as a read-only assistant,
6. only then expand into automation and broader imports.

Do not start with AI UI first.
Do not dump everything into comments.
Do not build a second tracker beside Fizzy.

## Phase 0: Confirm Product and Constraints

### Goal

Lock the exact product contract before more coding.

### Decisions to Freeze

- `Card` is the ticket primitive.
- Fizzy is the UI and workflow host.
- The PDF defines the functional target.
- Gate data is structured and not stored only in comments.
- `TrainingExample` is a separate lifecycle object.
- GitHub commit/PR linkage is part of the MVP path, not a vague future extra.
- Legacy imports are allowed but flagged.
- AI is read-only at first.
- Services should be written with enough boundaries that future extraction into an ES Windows Rails engine remains possible.

### Deliverables

- this master roadmap
- a short ADR or notes file for frozen model choices

### Exit Criteria

- no open disagreement about card-vs-new-ticket model
- no open disagreement that Fizzy UI is the implementation surface
- no open disagreement about Gate 1 / Gate 2 being structured

## Phase 1: Platform Stabilization and Environment Confidence

### Goal

Make the Fizzy fork predictable for daily development.

### Scope

- PostgreSQL runtime remains the main local path
- jobs boot reliably
- smoke UI path works
- system/integration confidence is acceptable

### Tasks

- verify login flow end-to-end
- verify boards open
- verify cards create/edit/move
- verify comments/events
- verify attachments
- verify background jobs
- verify seeded account/user/dev flow
- document any remaining intentional skips

### Exit Criteria

- team can develop on the fork without environment ambiguity
- "how do I run this?" is answered by docs, not tribal memory

## Phase 2: Technical Assessment of Fizzy Internals

### Goal

Understand where to extend Fizzy without fighting its architecture.

### What to Study

- `Card`
- `Board`
- `Comment`
- `Event`
- `Account`, `User`, `Identity`
- permissions/authorization
- account scoping and slug behavior
- import/export hooks
- activity/event generation
- existing UI/table patterns
- test conventions

### Questions to Answer

- where should structured bug data live?
- how should account-scoped admin/reviewer pages be implemented?
- how do we keep changes aligned with existing Fizzy patterns?
- where should AI runs and suggestions be stored?

### Deliverables

- a short tech map document
- list of extension points and constraints

### Exit Criteria

- implementation can start without guessing where data belongs

## Phase 3: Domain Model Mapping

### Goal

Translate the product into concrete Rails models.

### Proposed Model Set

- `Card` remains the ticket
- `CardResolutionRecord` or `CardTrainingRecord` stores Gate 1 + Gate 2 structured fields
- `TrainingExample` stores review/export lifecycle
- `AiRun` or `AiSuggestion` stores LLM execution artifacts
- optional `CardCodeLink` stores commit/PR metadata if direct association is cleaner

### Key Decisions

- one structured record around `Card` vs separate Gate 1 and Gate 2 tables
- whether draft LLM suggestions live on the resolution record or separate suggestion table
- whether training example snapshots denormalize card data at generation time

### Recommended Direction

Use:

- one structured `CardResolutionRecord` around `Card`
- one separate `TrainingExample`
- one separate `AiRun` / `AiSuggestion`

This avoids over-normalizing too early while keeping review/export independent.

### Exit Criteria

- schema plan is explicit enough to start migrations/models

## Phase 4: Structured Resolution Data Layer

### Goal

Add the structured data the normal card model does not contain.

### Status

In progress. Initial storage, association, and completeness-checking layer is implemented:

- `card_resolution_records` table
- `Card::ResolutionRecord`
- `Card::Resolvable`
- `CardResolutionRecords::CompletenessChecker`
- card detail form and scoped update endpoint for maintaining structured Gate 1 / Gate 2 data
- close workflow guard for cards that already participate in the structured resolution flow
- triage workflow guard for cards that already participate in the structured resolution flow

### Fields

Gate 1:

- problem description
- repro steps
- expected behavior
- actual behavior
- environment/product context
- severity
- category
- domain
- suspected primitives/components

Gate 2:

- root cause
- fix summary
- linked commits
- linked PRs
- verification steps
- verified by
- verified at

### Rules

- Gate 1 cannot be considered complete until required fields are filled
- Gate 2 cannot be considered complete until required fields are filled
- comments remain discussion, not structured storage

### Exit Criteria

- one card can reach a fully structured state without relying on freeform comments

## Phase 5: Card State Machine and Workflow Enforcement

### Goal

Make lifecycle rules explicit and enforceable.

### Status

In progress. Initial Cactus workflow state layer is implemented without replacing native Fizzy `Card.status`:

- `Card::CactusWorkflow`
- computed states: `draft`, `needs_info`, `open`, `in_progress`, `needs_review`, `resolved`, `closed`
- workflow state badge in the structured training-data card UI
- AI context includes `cactus_workflow_state`
- training example metadata includes `cactus_workflow_state`

Native Fizzy `Card.status` remains scoped to `drafted/published`; Cactus workflow is derived from card publication, Gate 1/Gate 2 completeness, triage/column state, close state, and approved training examples.

### States

- `draft`
- `needs_info`
- `open`
- `in_progress`
- `needs_review`
- `resolved`
- `closed`

### Rules

- reporter cannot bypass Gate 1
- developer cannot close without Gate 2
- support can triage only after Gate 1 completeness
- reporter verification can be required before true closure if product chooses

### Implementation

- model-level transition guards
- service objects for state transitions
- UI should not offer invalid actions
- event history should record transition reason

### Exit Criteria

- lifecycle is deterministic in code, not just UI convention

## Phase 6: Customer Intake Experience

### Goal

Give the customer a simple bug submission flow that collects training-quality data.

### Status

In progress. Initial Gate 1 guidance is implemented:

- `CardResolutionRecords::GateOneGuidance`
- `CardResolutionRecords::IntakeSeeder`
- deterministic prompts for missing reporter-side fields
- automatic structured intake record creation when a draft is published or a card is created through JSON
- initial `problem_description` seeding from card title and description
- board-scoped guided bug report form for creating cards with structured Gate 1 data
- board UI entry point for `Report bug`
- sparse customer submissions are accepted when they contain a title or any Gate 1 detail
- empty submissions are rejected before creating a card
- incomplete submissions stay in `needs_info` until Gate 1 is complete
- card detail guidance panel when a card is in `needs_info`
- next-question display plus full missing Gate 1 checklist
- one-question answer flow for filling the next missing Gate 1 field from the card detail screen
- narrow `Cards::GateOneAnswersController` endpoint that only updates allowed reporter-side fields
- Gate 1 answer responses expose the derived workflow state so UI/API clients can tell when the card becomes `open`

This is intentionally non-destructive and does not let AI silently write final structured fields. It gives support/customer-facing users a clear next question while keeping the saved structured record human-controlled.

### UI Capabilities

- create bug report from customer portal
- answer follow-up questions
- view status changes
- verify fixes

### LLM Behavior

- on initial submission, inspect content for Gate 1 completeness
- ask only for what is missing
- ask incrementally, not as one giant questionnaire

### Important Constraint

The LLM should assist the intake, but the structured record should be the stored result.

### Exit Criteria

- customer can submit sparse text and be guided to a complete Gate 1

## Phase 7: Support Queue and Triage Workflow

### Goal

Allow support/ops to process incoming reports efficiently.

### Status

In progress. Initial workflow queue UI is implemented:

- `Cards::CactusWorkflowQuery`
- `CactusQueuesController`
- `Cactus Queue` menu entry
- queue filters for `draft`, `needs_info`, `open`, `in_progress`, `needs_review`, `resolved`, `closed`
- account/access-scoped card list with Gate 1/Gate 2 status columns
- `needs_info` rows show the next reporter-side question support should ask
- `open` rows expose an inline triage action for moving complete Gate 1 cards into a board column

### UI Capabilities

- list/filter cards needing info
- list/filter open bug cards
- assign to developer
- re-categorize if necessary
- communicate with reporter
- inspect structured Gate 1 summary

### Enhancements

- severity badge
- affected domain badge
- account/customer visibility
- duplicate suspicion

### Exit Criteria

- support can triage without reading giant unstructured threads

## Phase 8: Developer Resolution Workflow

### Goal

Give developers a clean path for claiming, resolving, and verifying tickets.

### Status

In progress. Initial explicit resolution flow is implemented:

- `Card#resolve` product-language wrapper around the guarded close flow
- `Cards::ResolutionsController`
- `Mark resolved` action appears when Cactus workflow reaches `needs_review`
- resolving creates a pending review training example through the existing generator
- resolved cards link directly to the generated training example review page
- `in_progress` queue rows show missing Gate 2 fields and link directly to the structured resolution form
- `needs_review` queue rows expose review and mark-resolved actions

### UI Capabilities

- claim/assign ticket
- inspect structured Gate 1
- fill Gate 2
- link commits/PRs
- request more info if needed
- mark ready for review

### Rules

- cannot resolve without Gate 2 completeness
- if no commit is linked automatically, manual fix description is mandatory

### Exit Criteria

- developer can move a ticket from `open` to `resolved` using structured data

## Phase 9: GitHub Integration

### Goal

Connect cards to code evidence automatically.

### Status

In progress. Initial webhook-based GitHub linkage is implemented:

- `card_code_links` table
- `Card::CodeLink` model
- account-scoped signed GitHub webhook endpoint
- CT-style reference parser, e.g. `CT-1234`
- push commit linking
- pull request linking
- idempotent repeated webhook delivery handling
- card UI code evidence section
- AI context and training metadata include automatic code links

### Scope

- commit SHA linkage
- PR linkage
- optional branch linkage
- webhook ingestion

### Expected Behavior

- developer tags commit/PR with ticket id like `CT-1234`
- webhook receives commit/PR event
- system extracts ticket reference
- code link is attached to the card automatically

### Future Value

- AI can read real diffs
- root cause and fix summary can be grounded in code
- training example metadata becomes much more useful

### Implementation Pieces

- webhook endpoint
- parser for ticket references
- persistence model for linked code artifacts
- UI section on card for commits/PRs

### Exit Criteria

- a tagged GitHub commit links to the right card without manual admin work

## Phase 10: Card Context Builder

### Goal

Create a single structured payload for AI and export flows.

### Status

In progress. Initial read-only context builder is implemented:

- `Ai::CardContextBuilder`
- structured payload for card, account, board, column, assignees, tags, comments, events, attachments, and `Card::ResolutionRecord`
- coverage for cards with and without structured resolution records

### Service

- `Ai::CardContextBuilder`

### Should Include

- card title/body/status
- board context
- assignees
- tags
- comments
- events
- attachments metadata
- structured Gate 1/Gate 2 fields
- linked commits/PRs
- account metadata

### Why It Matters

- AI review
- training export
- future insights
- debugging AI decisions

### Exit Criteria

- one stable context payload exists for any candidate card

## Phase 11: AI Gate Assistance

### Goal

Use AI to assist structured completeness, not to silently mutate records.

### Status

In progress. Initial read-only review foundation is implemented:

- `ai_runs` audit table
- `AiRun` lifecycle model
- `Ai::CardQualityReviewService`
- generic HTTP JSON review client behind `AI_REVIEW_ENDPOINT`
- provider resolver with deterministic local fallback
- OpenAI Responses API adapter kept as an optional fallback behind `OPENAI_API_KEY`
- card-level review endpoint
- card UI action for training quality review
- deterministic output for missing Gate fields, missing code evidence, and next-step suggestions

This is intentionally not a hidden writer. The current service creates review output only. Local/dev runs work without external credentials through deterministic review; environments with `AI_REVIEW_ENDPOINT` can use the custom Cactus AI service while keeping the same `AiRun` audit trail. The OpenAI adapter is intentionally optional and can be removed once the custom service is finalized.

### Use Cases

- Gate 1 completeness review
- category/domain suggestion
- severity suggestion
- suspected primitive suggestion
- Gate 2 draft summary from commits/comments

### Constraints

- read-only suggestions first
- explicit user confirmation before applying
- save AI output separately from user-confirmed fields

### Exit Criteria

- AI adds value without becoming a hidden writer

## Phase 12: TrainingExample Lifecycle

### Goal

Separate training data from live ticket data.

### Status

In progress. Initial lifecycle layer is implemented:

- `training_examples` table
- `TrainingExample` model with `draft`, `pending_review`, `approved`, `rejected`, `exported`
- review/export transition helpers
- `TrainingExamples::Generator` that snapshots `Ai::CardContextBuilder` output from complete Gate 1 + Gate 2 cards

### Model

- `TrainingExample`

### Example Fields

- `account_id`
- `card_id`
- `status`
- `input_context`
- `problem_summary`
- `root_cause`
- `resolution_summary`
- `verification_steps`
- `metadata`
- `review_notes`
- `reviewed_by_id`
- `reviewed_at`
- `exported_at`

### Statuses

- `draft`
- `pending_review`
- `approved`
- `rejected`
- `exported`

### Exit Criteria

- closed/resolved card can generate a reviewable training example snapshot

## Phase 13: Automatic Training Example Generation

### Goal

Generate candidate training examples from resolved tickets.

### Status

Done for the initial MVP path:

- closing a card with complete Gate 1 and Gate 2 automatically generates a pending review training example
- cards without complete structured data are not forced into the training pipeline
- existing approved/exported examples are preserved by the generator

### Trigger

- when Gate 2 is complete and workflow reaches `resolved`

### Inputs

- structured Gate 1
- structured Gate 2
- linked commits/PRs
- card context payload

### Outputs

- a `TrainingExample` record
- default `pending_review` status

### Exit Criteria

- ticket resolution automatically produces a review candidate

## Phase 14: Review Queue

### Goal

Ensure only good examples enter the corpus.

### Status

Done for the initial MVP path. Initial account-scoped admin review queue is implemented:

- `TrainingExamplesController`
- list and detail pages
- approve/reject actions with review notes
- account scoping and admin-only access

### UI Capabilities

- list training examples
- filter by status/domain/account/reviewer
- open full example
- approve
- reject
- add review notes

### Rules

- nothing is exported automatically unless approved
- review outcome is audited

### Exit Criteria

- dataset quality is governed, not accidental

## Phase 15: JSONL Export Pipeline

### Goal

Produce real training corpus artifacts.

### Status

Done for the initial MVP path:

- `TrainingExamples::JsonlExporter`
- account-scoped admin export endpoint
- approved-only JSONL corpus export
- exported examples are marked with `exported_at` and moved to `exported`
- review/export controller and service coverage
- admin menu entry for manual review/export testing

### Output Shape

- JSONL
- `messages`
- `metadata`

### Metadata Should Include

- ticket/card id
- account
- domain
- category
- severity
- linked commits/PRs
- reviewer info
- verification status

### Entry Points

- admin UI export action
- optional rake task

### Exit Criteria

- approved examples can be exported consistently for model training

## Phase 16: Legacy Import and Historical Data Recovery

### Goal

Turn old issue systems into training candidates where possible.

### Sources

- Asana first
- others later if needed

### Rules

- imported cards are marked `legacy`
- Gate 1 bypass is explicit
- incomplete data is flagged
- AI may help structure the record
- human still reviews before export

### Exit Criteria

- historical tasks can be ingested without corrupting the structured workflow

## Phase 17: Model and Pipeline Observability

### Goal

Measure whether the system is actually useful.

### Dashboard Areas

- number of tickets by state
- Gate 1 completion friction
- Gate 2 completion rate
- training examples pending review
- approval/rejection rate
- categories/domains with strongest coverage
- GitHub linkage rate
- AI suggestion acceptance rate

### Exit Criteria

- team can see whether the pipeline is producing value or noise

## Phase 18: Security, Permissions, and Audit

### Goal

Make sure sensitive customer/engineering data is handled correctly.

### Scope

- account scoping
- role-based visibility
- customer vs support vs developer permissions
- admin-only review/export
- audit trail for AI suggestions and human approvals
- webhook verification for GitHub
- sensitive data redaction where needed

### Exit Criteria

- no ambiguity about who can see, edit, approve, or export what

## Phase 19: Hardening and Scale

### Goal

Prepare the system for real usage volume.

### Scope

- async AI jobs
- retry behavior
- webhook idempotency
- pagination for queues
- background export jobs
- AI cost/rate-limit handling
- failure-state recovery

### Exit Criteria

- pipeline remains stable under non-trivial ticket volume

## Phase 20: Post-MVP AI Expansion

### Goal

Expand only after the structured pipeline is proven.

### Candidates

- draft response suggestions
- duplicate issue clustering
- root cause suggestion from similar resolved tickets
- domain-specific troubleshooting assistant
- commit/diff summarizer
- customer-facing guided troubleshooting

### Constraint

Do not do this before the structured review/export pipeline works.

## Recommended Execution Order

### Track A: Foundation

1. Phase 0
2. Phase 1
3. Phase 2
4. Phase 3

### Track B: Structured Ticketing

5. Phase 4
6. Phase 5
7. Phase 6
8. Phase 7
9. Phase 8

### Track C: Code and AI Context

10. Phase 9
11. Phase 10
12. Phase 11

### Track D: Training Pipeline

13. Phase 12
14. Phase 13
15. Phase 14
16. Phase 15

### Track E: Expansion and Hardening

17. Phase 16
18. Phase 17
19. Phase 18
20. Phase 19
21. Phase 20

## Suggested MVP Cut Line

If a true MVP cut is needed, stop after:

- Phase 8
- Phase 9
- Phase 10
- Phase 12
- Phase 13
- Phase 14
- Phase 15

That gives:

- structured bug workflow
- GitHub linkage
- training example generation
- human review
- corpus export

This is the smallest version that still matches the PDF's real purpose.

## What Not To Do

- do not build a separate ticket model unless Fizzy `Card` proves impossible
- do not reinterpret the PDF as a request for a generic task tracker
- do not replace Fizzy UI with a separate standalone interface
- do not store Gate 1 / Gate 2 only in comments
- do not let AI auto-write final structured fields silently
- do not export unresolved or unreviewed examples
- do not make GitHub integration purely manual if webhooks are feasible
- do not start with dashboards before the data pipeline exists

## Definition of Success

The project is successful when:

- a customer can file a sparse issue and be guided to a complete Gate 1
- support can triage it cleanly
- a developer can resolve it with linked code evidence
- the system can generate a structured training example
- a reviewer can approve/reject it
- approved examples can be exported to JSONL
- the pipeline improves the operator model with real production failures

## Immediate Next Step

The next best step is:

1. wire automatic training example generation into the resolved/closed workflow,
2. add GitHub commit/PR linkage so Gate 2 can be grounded in real code evidence,
3. start the read-only AI review layer for Gate completeness and training-candidate quality.
