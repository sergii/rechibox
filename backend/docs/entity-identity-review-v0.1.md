# Entity Identity Review v0.1

Entity Resolution v0.1 can resolve a request-local Situation Model entity to a durable World State entity, or leave it ambiguous/unresolved. Entity Identity Review adds an explicit product-facing decision boundary for cases where identity should be confirmed rather than guessed.

## Goals

- let the product confirm that two durable entities are the same entity;
- let the product confirm that two durable entities are different entities;
- preserve history and provenance instead of silently deleting records;
- keep World State mutation deterministic and model-free;
- avoid automatic destructive merge behavior;
- make identity corrections reviewable and auditable.

## Identity decisions

An identity review has one of two decisions:

- `same_entity`
- `different_entities`

`same_entity` requires a canonical entity and an alias entity. The alias entity becomes inactive and points at the canonical entity through `merged_into_entity_id`. Its canonical label and aliases are folded into the canonical entity aliases. Claims that reference the alias entity are rewritten to reference the canonical entity while preserving the original claim IDs and adding merge provenance.

`different_entities` records an explicit non-identity constraint between two durable entity IDs.

## Safety

Identity decisions are explicit user/product actions. Automatic Entity Resolution never performs a merge or split.

A merge is rejected when:

- the two IDs are identical;
- either entity does not exist;
- either entity is already merged into another entity;
- the entities have incompatible kinds unless one side is `other`;
- the pair is explicitly marked `different_entities`.

A `different_entities` decision is rejected when the pair has already been merged.

## API

```text
POST /api/worlds/:id/identity_reviews
GET  /api/worlds/:id/identity_reviews
```

Create a same-entity decision:

```json
{
  "decision": "same_entity",
  "canonical_entity_id": "<uuid>",
  "alias_entity_id": "<uuid>",
  "reason": "User confirmed that Box 3 and the cable box are the same physical box."
}
```

Create a different-entities decision:

```json
{
  "decision": "different_entities",
  "left_entity_id": "<uuid>",
  "right_entity_id": "<uuid>",
  "reason": "User confirmed these are two separate boxes."
}
```

## Persistence

Identity reviews are stored inside the World State document under `identity_reviews`. This keeps the v0.1 file-backed state atomic with entity mutation and avoids a second persistence adapter for a small deterministic contract.
