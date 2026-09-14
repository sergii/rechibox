# Conversation Turn State v0.1

Conversation Turn State makes each user turn a durable workflow object instead of deriving state only from an API response.

## States

- `processing` - turn has been created and work is in progress
- `awaiting_clarification` - identity ambiguity blocks safe continuation
- `ready_for_review` - one or more state update proposals are ready for explicit review
- `completed` - the turn finished without pending review work
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

The default store is JSON-directory based and can be replaced later behind `Conversations::TurnStore`.

```sh
CONVERSATION_TURN_STORE_PATH=tmp/conversation-turns
```

## API

```text
GET /api/conversations/:id/turns
GET /api/conversations/:id/turns/:turn_id
```

Message replies also return the current `turn` object and use the persisted turn status as `conversation_status`.

## Clarification resume

Clarification resume context carries the originating `turn_id`. When the user resolves a clarification, the same turn advances to `ready_for_review` or `completed` instead of creating a second interpretation turn.

## Safety

Turn state is orchestration metadata. It does not grant the AI permission to mutate World State. Durable physical-world changes still require the existing State Update Proposal, review, and apply boundaries.

## Cost

Turn state is deterministic and model-free. It adds no model calls.
