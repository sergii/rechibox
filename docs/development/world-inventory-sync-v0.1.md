# Local Inventory -> World State v0.1

This slice makes confirmed on-device Rechibox inventory queryable through the existing World State pipeline without requiring a model call.

## Runtime flow

```text
confirmed local SQLite/localStorage inventory
  -> inventory snapshot
  -> POST /api/worlds/:id/inventory_snapshot
  -> durable World entities + imported location claims
  -> deterministic natural-query interpreter
  -> deterministic entity resolution
  -> WorldState::Query
  -> QueryAnswerRenderer
  -> mobile chat answer
```

The mobile app refreshes the snapshot during World bootstrap and immediately before each World Query. The stored World id remains device-local and backend-URL-scoped.

## Snapshot contract

```json
{
  "snapshot": {
    "contract_version": "0.1",
    "entities": [
      {
        "source_ref": "mobile_inventory:box:1",
        "kind": "container",
        "label": "Синя коробка"
      },
      {
        "source_ref": "mobile_inventory:item:1",
        "kind": "item",
        "label": "Кабелі",
        "location_ref": "mobile_inventory:box:1"
      }
    ]
  }
}
```

`source_ref` is unique only inside one World State. v0.1 deliberately matches the current device-local World identity boundary. It is not a cross-device identity.

Imports are idempotent. Durable World entity ids survive repeated snapshots. Renaming a local record updates the imported entity label and preserves the previous label as an alias.

An item assignment is represented as a typed `location` claim from item to container. Moving an imported item supersedes the previous imported location. Unassigning closes the imported location without inventing a synthetic "nowhere" value.

The importer does not delete World entities that are absent from a later snapshot. Destructive synchronization is out of scope for v0.1.

## Precedence

Imported local inventory must not silently overwrite stronger World State evidence. If an item already has an active non-imported location claim, a conflicting imported location is reported in `conflicts` and the explicit claim remains active.

## Natural query mode

The default `AI_WORLD_QUERY_INTERPRETER` is `deterministic`. It recognizes a deliberately small set of Ukrainian and English forms for the existing five bounded intents. Unsupported wording fails closed with no query.

```sh
AI_WORLD_QUERY_INTERPRETER=deterministic
```

The existing opt-in RubyLLM mode remains available:

```sh
AI_WORLD_QUERY_INTERPRETER=ruby_llm
AI_WORLD_QUERY_MODEL=<provider-model-name>
```

`disabled` also remains available explicitly.

The deterministic interpreter never answers directly, mutates World State, invents durable ids, or selects among ambiguous entities. It only produces a bounded intent and request-local entity label.

Entity resolution includes a small Cyrillic token-prefix normalization so common Ukrainian inflections such as `синя коробка` vs `синій коробці` can still reach the deterministic ambiguity checks. It is not a general morphological analyzer.

## Cost

The complete default path is model-free. No OpenAI/provider call is enabled by this slice or its tests.
