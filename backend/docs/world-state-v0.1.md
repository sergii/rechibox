# World State v0.1

World State is Rechibox-owned persistent personal state. It is deliberately separate from both Organized knowledge and conversation history.

```text
Organized       = reusable domain knowledge
Conversation    = what was said in one thread
Situation Model = interpretation of the current request
World State     = durable facts about this user's physical world
```

## Contract

A world document has:

```json
{
  "contract_version": "0.1",
  "id": "uuid",
  "created_at": "...",
  "updated_at": "...",
  "entities": [],
  "claims": []
}
```

### Entities

An entity is a durable reference to a physical-world thing:

```json
{
  "id": "uuid",
  "kind": "space | item | container | furniture | person | collection | other",
  "label": "blue box",
  "attributes": {},
  "first_seen_message_id": "uuid",
  "last_seen_message_id": "uuid"
}
```

Situation Model refs such as `E1` are request-local and are never reused as durable world IDs.

### Claims

Claims represent durable assertions. v0.1 persists explicit user/observed facts conservatively:

```json
{
  "id": "uuid",
  "predicate": "fact",
  "value": "The blue box belongs to my brother.",
  "status": "active",
  "source": "user",
  "confidence": 1.0,
  "provenance": {
    "conversation_id": "uuid",
    "message_id": "uuid"
  }
}
```

The model intentionally reserves typed predicates for later normalization:

- `ownership`
- `custody`
- `location`
- `disposition`
- `contains`
- `attribute`
- `fact`

Ownership, custody, location, and disposition are separate concepts. A thing can belong to one person, be physically held by another, be located elsewhere, and already have a planned disposition.

## Promotion policy

World State is not a dump of model output.

`WorldState::ProjectSituation` currently promotes only:

- lightweight entities from the Situation Model;
- facts whose source is explicitly `user` or `observed`.

It does **not** persist hypotheses or recommendations. It also does not infer typed ownership/location/disposition relationships from prose yet. That should happen only through a dedicated typed state-update contract with conflict handling.

Repeated identical facts are deduplicated. Entity matching in v0.1 is intentionally simple (`kind + label`) and will need stronger identity resolution before the inventory grows large.

## Conversation relationship

Every conversation has a `world_id`. Creating a conversation without one creates a new world. Supplying an existing `world_id` allows multiple conversations to share the same persistent state.

Before each reply Rechibox loads the world and provides it to both SituationExtractor and ContextComposer. After extraction, explicit facts from the current turn are projected back into the world for future turns.

This makes cross-conversation reference resolution possible without treating chat transcripts as the canonical inventory.
