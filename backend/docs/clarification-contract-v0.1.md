# Clarification Contract v0.1

Clarifications turn uncertain entity resolution into an explicit product interaction instead of an AI guess.

```text
Situation Model entity
        ↓
Entity Resolution
        ↓
ambiguous / unresolved with plausible candidates
        ↓
persisted clarification
        ↓
user selects one candidate or none of the above
        ↓
resolved clarification record
```

A clarification is not a durable identity assertion. Selecting `blue box` for the mention `box` resolves that mention only. It does not automatically add `box` as a global alias because generic wording may refer to a different entity later.

## Record

```json
{
  "contract_version": "0.1",
  "id": "<uuid>",
  "world_id": "<uuid>",
  "status": "pending",
  "situation_entity_ref": "E1",
  "mention": {
    "kind": "container",
    "label": "box"
  },
  "question": "Which 'box' do you mean: blue box / red box?",
  "options": [
    {
      "option_id": "1",
      "entity_id": "<uuid>",
      "label": "blue box",
      "kind": "container",
      "score": 0.5
    }
  ],
  "created_at": "...",
  "updated_at": "..."
}
```

The `question` is a presentation hint, not canonical localized copy. Clients may render their own localized question from `mention` and `options`.

## Lifecycle

```text
pending
  ├─ select option      → resolved
  └─ none_of_above      → none_of_above
```

A selected option is rechecked against the current World State. If its entity has disappeared from active identity because it was merged, the answer is rejected as stale instead of silently redirecting identity.

## API

```text
GET  /api/worlds/:id/clarifications
GET  /api/worlds/:id/clarifications/:clarification_id
POST /api/worlds/:id/clarifications/:clarification_id/answer
```

Selection:

```json
{
  "action": "select",
  "option_id": "2"
}
```

None of the candidates:

```json
{
  "action": "none_of_above"
}
```

Conversation replies also expose newly generated `identity_clarifications` after deterministic Entity Resolution.

## Safety rules

- Entity Resolution never chooses an ambiguous candidate merely to avoid asking a question.
- Clarification answers can select only candidates that were presented in that clarification.
- Selection does not mutate World State identity or create aliases.
- Identity merges remain behind the separate explicit Identity Review contract.
- Clarification generation and review are deterministic and model-free.
