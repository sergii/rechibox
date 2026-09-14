# Entity Resolution v0.1

Entity Resolution maps request-local Situation Model entities such as `E1` to durable World State entity IDs without silently merging uncertain mentions.

## Boundary

```text
Situation Model entity
  -> Entity Resolution
  -> resolved | ambiguous | unresolved
  -> World State projection / State Update Proposal
```

Situation Model refs remain request-local. Durable World State IDs remain stable across conversations.

## Contract

`WorldState::ResolveEntities` returns:

```json
{
  "contract_version": "0.1",
  "world_id": "...",
  "resolutions": [
    {
      "situation_entity_ref": "E1",
      "kind": "container",
      "label": "ця синя коробка",
      "status": "resolved",
      "durable_entity_id": "...",
      "candidates": [
        {
          "entity_id": "...",
          "label": "синя коробка",
          "kind": "container",
          "score": 1.0,
          "match": "token_overlap"
        }
      ]
    }
  ]
}
```

Statuses:

- `resolved`: one candidate is strong enough and clearly better than alternatives.
- `ambiguous`: multiple strong candidates are too close to choose safely.
- `unresolved`: no candidate is strong enough.

## Matching policy

v0.1 is deterministic and model-free.

It uses:

- entity kind filtering;
- canonical labels;
- durable aliases;
- Unicode-normalized token matching;
- small English/Ukrainian stopword removal;
- conservative thresholds and ambiguity margins.

Exact label or alias matches score highest. A generic one-token mention such as `коробка` is kept as a weak candidate rather than treated as an identity match.

The score is a local lexical matching score, not a probability.

## Projection safety

`WorldState::ProjectSituation` uses a `resolved` mapping to update the existing durable entity and records a newly seen label as an alias.

When resolution is `ambiguous`, projection does not create a new durable entity.

When resolution is `unresolved` but weak candidates exist, projection also does not create a new durable entity. This prevents a vague reference from creating a duplicate.

A new durable entity is created only when the Situation Model entity is unresolved and there are no plausible existing candidates.

## Proposal integration

Conversation replies attach the resolution result to the situation passed to `StateUpdateProposer`:

```text
Situation Model
+ entity_resolutions
+ current World State
  -> State Update Proposal
```

The proposer still cannot invent durable IDs. It should use only resolved IDs or choose not to propose an update.

## API

```text
POST /api/worlds/:id/resolve_entities
```

Request:

```json
{
  "situation": {
    "entities": [
      {
        "ref": "E1",
        "kind": "container",
        "label": "ця синя коробка",
        "attributes": {}
      }
    ]
  }
}
```

## Non-goals for v0.1

v0.1 does not:

- use an LLM for identity decisions;
- merge durable entities;
- infer pronouns from conversation history by itself;
- mutate claims;
- automatically accept ambiguous matches.

A later resolver may add contextual or model-assisted candidate ranking, but deterministic identity validation should remain a separate boundary.
