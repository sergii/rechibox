# Conversation Turn State v0.1

Conversation Turn State makes each user turn a durable workflow object instead of deriving state only from an API response.

## States

- `processing` - turn has been created and work is in progress
- `awaiting_clarification` - identity ambiguity blocks safe continuation or a resolved clarification is awaiting proposal finalization
- `ready_for_review` - one or more state update proposals are ready for explicit review
- `completed` - the turn finished without pending clarification or proposal review work
- `failed` - processing raised an error after turn creation

## State machine

`Conversations::TurnState` is the single deterministic transition policy for turn lifecycle changes. Services may decide the desired next state, but they must not assign `turn["status"]` directly.

Legal transitions are:

```text
processing
  -> awaiting_clarification
  -> ready_for_review
  -> completed
  -> failed

awaiting_clarification
  -> ready_for_review
  -> completed

ready_for_review
  -> completed

completed
  -> nowhere

failed
  -> nowhere
```

Applying the current state again is an idempotent no-op, which lets proposal review leave a turn in `ready_for_review` while other proposals remain pending. Any other transition fails closed with `ArgumentError`.

The state machine also owns terminal lifecycle timestamps: entering `completed` records `completed_at`, and entering `failed` records `failed_at`.

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

Clarification resume context carries the originating `turn_id`. A turn may contain more than one identity clarification. The full `clarification_ids` set is a barrier: answering one clarification does not resume proposal generation while any sibling clarification remains pending.

```text
awaiting_clarification
  -> answer clarification A
  -> clarification B still pending? yes -> awaiting_clarification
  -> answer clarification B
  -> all clarifications resolved? yes -> prepare proposals
  -> proposals? yes -> ready_for_review
  -> proposals? no  -> completed
```

When the final clarification is answered, `Conversations::ResumeClarification` reconstructs one entity-resolution set from every selected clarification before calling the state update proposer. This prevents the last answer from discarding selections made for earlier ambiguous entities.

`resolved` and `none_of_above` are terminal clarification states. If any clarification closes as `none_of_above`, the turn still waits for its pending siblings, but proposal generation remains blocked after the barrier closes because the original entity set is not fully resolved. The turn then completes without inferred state updates.

The resume response includes `pending_clarification_ids` for turn-backed clarifications so clients can render the remaining work without deriving it from the transcript.

Legacy clarification records without a `turn_id` keep the pre-turn resume behavior for compatibility.

### Two-phase turn-backed finalization

With the default ActiveRecord/PostgreSQL adapter, turn-backed clarification resume uses the conversation turn row as the serialization point for sibling answers, but it does not hold that row lock across proposal computation.

Phase one is a short transaction:

```text
lock conversation turn
  -> re-read clarification and resume context
  -> answer clarification
  -> read sibling clarification states
  -> enforce the clarification barrier
  -> commit
```

This prevents concurrent sibling answers from both observing each other as pending. Once the barrier closes, proposal computation runs outside the transaction:

```text
resolved Situation + World snapshot
  -> State Update Proposer
  -> prepared proposal plan
```

`WorldState::ProposeUpdates#prepare` performs this computation without durable proposal writes. If `AI_STATE_UPDATE_PROPOSER=ruby_llm` is explicitly enabled, provider latency happens here without holding the turn row lock.

Phase two is another short transaction:

```text
lock conversation turn
  -> verify turn is still awaiting finalization
  -> persist prepared proposals
  -> record proposal_ids
  -> ready_for_review | completed
  -> commit
```

`WorldState::ProposeUpdates#persist` only writes a previously prepared plan. A concurrent duplicate finalizer rechecks the turn under lock; once another request has moved it to `ready_for_review` or `completed`, the duplicate does not persist a second proposal set.

There is an intentional recovery boundary between the two phases. If proposal computation fails after the clarification answer commits, the clarification remains resolved and the turn remains `awaiting_clarification` with no `proposal_ids`. Retrying the same clarification answer is idempotent and resumes proposal computation. Retrying with a different option or action fails closed instead of rewriting the persisted identity decision.

The legacy JSON-directory adapter keeps its compatibility behavior. `Persistence.transaction` is a no-op there, so cross-file atomicity and PostgreSQL row-lock serialization guarantees do not apply.

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

Clarification answers are deterministic identity selections. They do not mutate World State or grant the proposer permission to infer missing identity decisions.

Proposal review does not infer completion from UI behavior. Only persisted terminal proposal states can close a `ready_for_review` turn.

## Cost

Clarification barrier and persistence phases are deterministic and model-free. The State Update Proposer remains disabled by default. This change does not enable RubyLLM or any paid model/provider call; it only makes the opt-in model path safe from holding a database row lock during provider latency.
