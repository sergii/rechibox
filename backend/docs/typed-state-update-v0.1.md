# Typed State Update v0.1

Typed State Update is the explicit mutation contract for durable Rechibox World State.

It is intentionally separate from Situation Model extraction. Situation Models may contain uncertain or request-local interpretations. Typed State Updates represent deliberate durable assertions or transitions.

## Contract

```json
{
  "contract_version": "0.1",
  "operation": "assert | correct | supersede",
  "predicate": "ownership | custody | location | disposition | contains | attribute",
  "subject_id": "<world entity UUID>",
  "object": { "entity_id": "<world entity UUID>" },
  "key": null,
  "target_claim_id": null,
  "source": "user",
  "confidence": 1.0,
  "provenance": {}
}
```

`object` can instead contain a scalar value:

```json
{ "value": "sell" }
```

`attribute` requires `key`, for example `key: "color"` with `object: {"value":"blue"}`.

## Operations

`assert` means the system is adding a claim without saying an earlier claim was wrong or outdated.

`correct` means the target claim was wrong. The target becomes `corrected`, receives `ended_at` and `replaced_by_claim_id`, and a new active claim points back with `replaces_claim_id`.

`supersede` means the target claim used to be true but the world changed. The target becomes `superseded`, and a new active claim replaces it.

This distinction matters for history. "The box was never in the garage, it was on the shelf" is a correction. "I moved the box from the garage to the shelf" is a supersession.

## Conflict policy

`custody`, `location`, `disposition`, and each keyed `attribute` are singleton slots in v0.1. Reasserting the exact same value is idempotent. Trying to assert a conflicting active value is rejected; callers must choose `correct` or `supersede` explicitly.

`ownership` and `contains` are not forced to be single-valued because co-ownership and multiple contained objects are legitimate.

## Boundary

This PR does not ask an LLM to invent Typed State Updates from prose. The contract is deterministic and model-free. A later extractor may propose updates, but durable mutation should remain separately reviewable/validatable and should preserve provenance.
