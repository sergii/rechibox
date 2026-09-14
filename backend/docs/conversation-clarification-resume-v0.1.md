# Conversation Clarification Resume v0.1

A conversation turn can now pause before State Update Proposal generation when entity identity is ambiguous.

```text
user turn
  -> Situation Model
  -> Entity Resolution
  -> ambiguity
  -> persisted Clarification
  -> conversation_status: awaiting_clarification
  -> user selects one presented entity
  -> original turn resumes
  -> selected durable entity is injected into the original resolution
  -> State Update Proposal generation continues
```

This keeps ambiguity from being guessed merely to keep the pipeline moving.

## Resume context

Clarifications created from a conversation carry a bounded `resume_context` containing:

- `conversation_id`
- original user `message_id`
- original Situation Model
- original Entity Resolution result

The resume endpoint refuses to resume a clarification that belongs to another conversation.

## API

```text
POST /api/conversations/:id/clarifications/:clarification_id/answer
```

Select one of the options that was originally presented:

```json
{
  "action": "select",
  "option_id": "2"
}
```

The response includes:

```json
{
  "conversation_status": "resumed",
  "clarification": {
    "status": "resolved",
    "selected_entity_id": "..."
  },
  "entity_resolution": {
    "resolutions": [
      {
        "status": "resolved",
        "durable_entity_id": "...",
        "resolved_by": {
          "type": "clarification",
          "clarification_id": "..."
        }
      }
    ]
  },
  "state_update_proposals": []
}
```

Rejecting all candidates is explicit:

```json
{
  "action": "none_of_above"
}
```

That returns `conversation_status: clarification_unresolved` and does not generate proposals.

## Safety semantics

- A turn with a generated clarification does not generate State Update Proposals until the ambiguity is resolved.
- The user can select only an option that was actually presented.
- `AnswerClarification` rechecks that the selected durable entity still exists and is not merged.
- Clarification selection is local to this mention. It does not create a global alias or merge durable entities.
- Identity Review remains the only boundary that can merge two durable entities.
- The original Situation Model is reused on resume, so the system does not reinterpret the user turn with a second model call.

## Cost

The resume path is deterministic. With the default `AI_STATE_UPDATE_PROPOSER=disabled`, resolving a clarification performs zero model calls. Model-backed proposal generation remains opt-in and fail-closed.
