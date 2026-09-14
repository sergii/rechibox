# Proposal lifecycle v0.1

State Update Proposals are durable review objects between AI interpretation and World State mutation.

```text
Situation Model + World State
  -> proposer
  -> deterministic validation
  -> persisted proposal: pending
  -> review
      -> accepted -> ApplyUpdate mutates World State
      -> rejected -> no mutation
      -> stale    -> no mutation; proposal no longer validates against current World State
```

A proposal record contains a stable UUID, `world_id`, typed `update`, proposer mode, reason, validation result, timestamps, and lifecycle status.

Statuses:

- `pending`: generated and awaiting review.
- `accepted`: explicitly accepted and successfully applied.
- `rejected`: explicitly rejected without mutating World State.
- `stale`: acceptance was attempted after World State changed and the update no longer passed the real deterministic validator.

Proposal acceptance always revalidates against the current World State immediately before mutation. Validation uses the same `WorldState::ApplyUpdate` semantics on an in-memory copy, so a proposal that was valid when generated cannot silently overwrite newer state.

API:

```text
POST /api/worlds/:id/proposals
GET  /api/worlds/:id/proposals
GET  /api/worlds/:id/proposals/:proposal_id
POST /api/worlds/:id/proposals/:proposal_id/accept
POST /api/worlds/:id/proposals/:proposal_id/reject
```

Reject optionally accepts a `reason`. Accepting or rejecting anything other than a pending proposal fails rather than replaying the decision.

The spike stores proposal files under `tmp/world-proposals` by default. Override with:

```sh
WORLD_STATE_PROPOSAL_STORE_PATH=tmp/world-proposals
```

The proposal store is a replaceable persistence boundary. It can move to ActiveRecord/PostgreSQL with the rest of product persistence later.

AI proposal generation remains fail-closed and separate from review. `AI_STATE_UPDATE_PROPOSER=disabled` remains the default, so CI and normal development make no proposal model calls.
