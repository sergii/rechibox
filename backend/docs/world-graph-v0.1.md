# World Graph v0.1

World Graph is a deterministic read model over typed World State claims. It answers physical-structure and relationship questions without an LLM call and without changing the underlying claim contract.

## Relation semantics

Raw typed relations keep the original claim direction:

```text
subject --predicate--> object
```

Supported graph predicates in v0.1:

```text
contains
location
ownership
custody
```

The physical graph normalizes only `contains` and `location` into a parent-to-child view:

```text
contains(container, item)  => container -> item
location(item, place)      => place -> item
```

This makes nested physical structure traversable as one graph:

```text
garage
└─ shelf
   └─ box
      └─ cables
```

Ownership and custody remain associations and are not treated as physical containment.

## API

Return all active typed relationship edges:

```text
GET /api/worlds/:id/graph
GET /api/worlds/:id/graph?predicates=ownership,custody
```

Return the physical subtree under one durable entity:

```text
GET /api/worlds/:id/graph?root_id=<entity-id>
GET /api/worlds/:id/graph?root_id=<entity-id>&max_depth=4
```

Resolve all known physical ancestry paths for one entity:

```text
GET /api/worlds/:id/entities/:entity_id/physical_location
```

Example ancestry:

```text
cables -> blue box -> shelf -> garage
```

`physical_location` never guesses between conflicting active parents. If multiple active paths exist it returns all paths with:

```json
{"ambiguous": true}
```

Cycles are detected rather than recursively followed forever. Traversal depth is bounded to 32 and defaults to 8.

## Guarantees

- active claims only
- entity-valued objects only
- merged entity tombstones are excluded
- no model calls
- no inference from free text
- no World State mutation
- cycle-safe traversal
- ambiguity is surfaced rather than resolved heuristically

## Persistence

The graph uses `WorldState::ReadModel`, so PostgreSQL-backed deployments read from the relational `world_entities` and `world_claims` projection. The JSON-directory compatibility adapter continues to work through the same public read model.

v0.1 intentionally does not add a separate graph database or duplicate relation table. Typed claims remain the source of truth.
