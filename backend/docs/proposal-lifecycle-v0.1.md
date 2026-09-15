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

When a proposal originates from a conversation turn it also carries:

```text
conversation_id
message_id
turn_id
```

These fields are orchestration provenance. They do not change update semantics or grant the proposal additional authority.

Statuses:

- `pending`: generated and awaiting review.
- `accepted`: explicitly accepted and successfully applied.
- `rejected`: explicitly rejected without mutating World State.
- `stale`: acceptance was attempted after World State changed and the update no longer passed the real deterministic validator.

Proposal acceptance always revalidates against the current World State immediately before mutation. Validation uses the same `WorldState::ApplyUpdate` semantics on an in-memory copy, so a proposal that was valid when generated cannot silently overwrite newer state.

For proposals linked to a conversation turn, `accepted`, `rejected`, and `stale` are terminal review states. After every review, the turn checks all of its `proposal_ids`. It remains `ready_for_review` while any proposal is pending and becomes `completed` only when every linked proposal is terminal.

With the default ActiveRecord/PostgreSQL adapter, World State mutation, proposal status, and linked turn status participate in the same `Persistence.transaction`. The legacy JSON-directory adapter remains supported but does not provide cross-file atomicity.

API:

```text
POST /api/worlds/:id/proposals
GET  /api/worlds/:id/proposals
GET  /api/worlds/:id/proposals/:proposal_id
POST /api/worlds/:id/proposals/:proposal_id/accept
POST /api/worlds/:id/proposals/:proposal_id/reject
```

Reject optionally accepts a `reason`. Accepting or rejecting anything other than a pending proposal fails rather than replaying the decision.

The proposal store is a replaceable persistence boundary. ActiveRecord/PostgreSQL is the default adapter. The JSON-directory store remains available for compatibility and local testing.

AI proposal generation remains fail-closed and separate from review. `AI_STATE_UPDATE_PROPOSER=disabled` remains the default, so CI and normal development make no proposal model calls.
