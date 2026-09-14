# Relational World State v0.1

World State remains the durable model of a user's physical world, but its highest-value records are now queryable relational data instead of being embedded only inside one JSONB aggregate.

## Scope

v0.1 normalizes only:

- durable world entities
- durable world claims

The rest of the World State document remains JSONB metadata. Conversations, turns, proposals, and clarifications also remain document-oriented for now.

This is deliberate. The goal is to make physical-world identity and relations searchable without rewriting every persistence boundary at once.

## Tables

### `world_entities`

Indexed fields:

- `world_id`
- `position`
- `kind`
- `label`
- `status`

The complete public entity contract is preserved in `payload` JSONB.

### `world_claims`

Indexed fields:

- `world_id`
- `position`
- `predicate`
- `subject_id`
- `status`
- `source`

The normalized claim object is stored in `object` JSONB and the complete public claim contract remains in `payload` JSONB.

## Public contract

`WorldState::Store` still reads and writes the same document shape:

```json
{
  "contract_version": "0.1",
  "id": "...",
  "entities": [],
  "claims": []
}
```

Callers do not need to know whether entities and claims are physically stored inside JSON or relational tables.

The Active Record adapter assembles the public document on read and splits it back into metadata, entities, and claims on write.

## Ordering

Both relational tables contain `position`. This preserves the existing array order of the public World State contract and avoids making persistence order depend on UUID or timestamp ordering.

## Migration

The migration backfills existing `world_documents`:

1. reads `entities` and `claims` from the old JSONB payload,
2. inserts relational rows preserving their IDs and order,
3. removes those arrays from the stored document payload.

No durable entity or claim IDs are changed.

## Query API

Entities:

```text
GET /api/worlds/:id/entities?kind=container&status=active
```

Supported filters:

- `kind`
- `status`
- `label`

Claims:

```text
GET /api/worlds/:id/claims?predicate=location&status=active&subject_id=<uuid>
```

Supported filters:

- `predicate`
- `status`
- `source`
- `subject_id`
- `object_entity_id`
- `object_value`

Examples this makes cheap and explicit:

- all containers in a world
- all active location claims for an item
- all claims pointing at a given shelf or room
- all completed disposition claims
- all explicit user-sourced ownership claims

## Concurrency

The Active Record World State adapter locks the parent `world_documents` row and synchronizes the relational child rows inside the same database transaction.

This keeps the existing aggregate mutation semantics while exposing the most useful parts as relational read models.

## Compatibility

`PERSISTENCE_ADAPTER=json_directory` remains supported. `WorldState::ReadModel` falls back to filtering the public in-memory World State document when the JSON-directory adapter is selected.

## Non-goals

v0.1 does not yet:

- normalize aliases into a separate table,
- add a dedicated containment edge table,
- add recursive graph queries,
- add fuzzy/full-text search,
- add user/account scoping,
- remove the aggregate World State store boundary.

Those can be added incrementally once real query patterns justify them.
