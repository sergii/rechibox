# World Query v0.1

World Query is a deterministic semantic read layer over World State and the World Graph.

It does not interpret natural language and does not call an LLM. Callers must provide one bounded intent and one durable entity ID.

## Endpoint

```text
POST /api/worlds/:id/query
```

Example:

```json
{
  "intent": "where_is",
  "entity_id": "<durable-world-entity-id>"
}
```

Optional `max_depth` is accepted by recursive physical queries and follows the World Graph bounds.

## Intents

### `where_is`

Returns all active physical ancestry paths for an entity using `location` and `contains` relations.

If more than one active path exists, `ambiguous` is `true`. The query never chooses one path by guessing.

### `what_is_in`

Returns direct physical children of the supplied entity. Both forms are normalized:

```text
contains(container, item)
location(item, container)
```

### `contents_recursive`

Returns the bounded physical subtree rooted at the supplied entity.

### `who_owns`

Returns active `ownership` relation targets for the supplied entity.

### `who_has_custody`

Returns active `custody` relation targets for the supplied entity.

Ownership and custody intentionally remain separate concepts.

## Contract

Every successful response has:

```json
{
  "contract_version": "0.1",
  "world_id": "...",
  "intent": "where_is",
  "entity_id": "...",
  "result": {}
}
```

Intent-specific data is nested under `result`.

## Safety

World Query only reads persisted active World State relations. It does not infer missing relations, invent entities, resolve ambiguous identity, mutate World State, or turn recency/non-use into disposition decisions.

Merged entity tombstones are excluded from results.

This layer is deliberately suitable as the execution target for a future natural-language query interpreter:

```text
user text
  -> bounded query intent + resolved durable entity ID
  -> World Query
  -> deterministic result
```

The future interpreter must not bypass entity resolution or clarification when identity is ambiguous.
