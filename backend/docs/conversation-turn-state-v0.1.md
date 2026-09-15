# Conversation Turn State v0.1

Conversation Turn State makes each user turn a durable workflow object instead of deriving state only from an API response.

## States

- `processing` - turn has been created and work is in progress
- `awaiting_clarification` - identity ambiguity blocks safe continuation
- `ready_for_review` - one or more state update proposals are ready for explicit review
- `completed` - the turn finished without pending clarification or proposal review work
- `failed` - processing raised an error after turn creation

## Record

A turn contains a stable UUID plus:

- `conversation_id`
- `message_id`
- lifecycle `status`
- optional `clarification_ids`
- optional `resolved_clarification_ids`
- optional `proposal_ids`
- optional `trace_id`
- timestamps
- bounded error metadata for failed turns

The default persistence adapter is ActiveRecord/PostgreSQL. The JSON-directory adapter remains available as a compatibility path.

## API

```text
GET /api/conversations/:id/turns
GET /api/conversations/:id/turns/:turn_id
```

Message replies also return the current `turn` object and use the persisted turn status as `conversation_status`.

## Clarification resume

Clarification resume context carries the originating `turn_id`. When the user resolves a clarification, the same turn advances to `ready_for_review` or `completed` instead of creating a second interpretation turn.

## Proposal review completion

Proposals generated for a conversation turn persist `conversation_id`, `message_id`, and `turn_id`. This links the durable review object back to the workflow that created it without changing the typed World State update contract.

A turn remains `ready_for_review` while any linked proposal is still `pending`. Proposal terminal states are:

```text
accepted
rejected
stale
```

After each linked proposal review, `WorldState::ReviewProposal` rechecks every `proposal_id` recorded on the turn. When all linked proposals are terminal, the same turn transitions to `completed` and records `completed_at`.

```text
ready_for_review
  -> accept/reject/stale proposal A
  -> still pending proposal B? yes -> ready_for_review
  -> accept/reject/stale proposal B
  -> no pending proposals
  -> completed
```

With the default ActiveRecord adapter, World State mutation, proposal lifecycle update, and turn lifecycle update execute inside the same `Persistence.transaction`. The legacy JSON-directory adapter keeps its existing no-op transaction wrapper and therefore does not provide cross-file atomicity.

## Safety

Turn state is orchestration metadata. It does not grant the AI permission to mutate World State. Durable physical-world changes still require the existing State Update Proposal, review, validation, and apply boundaries.

Proposal review does not infer completion from UI behavior. Only persisted terminal proposal states can close a `ready_for_review` turn.

## Cost

Turn state is deterministic and model-free. It adds no model calls.
