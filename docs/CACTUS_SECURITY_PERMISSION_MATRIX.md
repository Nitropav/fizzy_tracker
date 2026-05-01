# Cactus Security and Permission Matrix

This matrix documents the current MVP permission boundaries for the Cactus Bug Tracker layer inside Fizzy.

## Roles

- `member`: can use normal account-scoped Fizzy cards and Cactus Queue actions for cards they can access.
- `admin`: can access training review/export, legacy imports, and pipeline dashboard.
- `owner`: inherits normal account access. Owner-specific Cactus privileges are not separate yet.
- `system`: internal account user, not intended for interactive Cactus UI.

## Account Boundary

All interactive Cactus data is scoped to the current account.

- Card actions use `Current.user.accessible_cards`.
- Training examples are loaded through `Current.account.training_examples`.
- Legacy imports use boards visible to the current user and current account.
- Dashboard metrics are computed from `Current.account`.
- GitHub webhooks are unauthenticated by session, but must be signed and resolve through the account slug/context.

## Surface Matrix

| Surface | Member | Admin | Account scoped | Notes |
| --- | --- | --- | --- | --- |
| Cactus Queue | Yes | Yes | Yes | Uses accessible cards only. |
| Gate 1 answer | Yes | Yes | Yes | Only allowed Gate 1 fields can be updated. |
| Resolution record edit | Yes | Yes | Yes | Updates structured Gate 1 / Gate 2 data for accessible cards. |
| Triage card | Yes | Yes | Yes | Model guard blocks incomplete Gate 1. |
| Resolve card | Yes | Yes | Yes | Model guard blocks incomplete Gate 2. |
| AI quality review | Yes | Yes | Yes | Read-only output stored as `AiRun`. |
| Training examples | No | Yes | Yes | Review/export is admin-only. |
| Legacy Asana import | No | Yes | Yes | Imported cards are marked legacy. |
| Cactus Dashboard | No | Yes | Yes | Aggregates account-local pipeline metrics. |
| GitHub webhook | Signed webhook only | Signed webhook only | Yes | Requires HMAC signature. |

## Current Audit Sources

- `Card::ResolutionRecord` timestamps and reviewer/verification fields.
- `TrainingExample#reviewed_by`, `review_notes`, `reviewed_at`, and `exported_at`.
- `AiRun` input/output/status metadata.
- `Card::CodeLink` linked commit and PR metadata.
- Fizzy card events for triage, close, reopen, and board movement.

## Known Follow-Ups

- Add explicit support/developer/customer roles if product needs stricter separation than Fizzy `member/admin`.
- Add first-class audit events for training example approve/reject/export.
- Add first-class audit events for legacy import batches.
- Add acceptance tracking for AI suggestions once suggestions become applyable actions.
