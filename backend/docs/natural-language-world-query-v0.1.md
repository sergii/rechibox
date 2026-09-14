# Natural Language World Query v0.1

Natural Language World Query is a narrow AI boundary in front of the deterministic World Query service.

It does not let the model answer from World State directly. The model may only classify one supported query intent and extract one entity mention.

## Pipeline

```text
user message
  -> query interpreter
  -> bounded intent + entity mention
  -> deterministic entity resolution
  -> stop if ambiguous or unresolved
  -> WorldState::Query
  -> deterministic result
```

Supported intents are inherited from World Query v0.1:

```text
where_is
what_is_in
contents_recursive
who_owns
who_has_custody
```

## Endpoint

```text
POST /api/worlds/:id/natural_query
```

Request:

```json
{
  "message": "Де мої кабелі?"
}
```

## Fail-closed default

The interpreter is disabled unless explicitly enabled:

```sh
AI_WORLD_QUERY_INTERPRETER=disabled
```

This is also the default when the variable is absent. In disabled mode the endpoint performs no model call and returns no interpreted query.

RubyLLM is opt-in:

```sh
AI_WORLD_QUERY_INTERPRETER=ruby_llm
AI_WORLD_QUERY_MODEL=<provider-model-name>
```

Provider credentials continue to use the existing RubyLLM configuration.

Optional accounting rates:

```sh
AI_WORLD_QUERY_INPUT_USD_PER_1M_TOKENS=...
AI_WORLD_QUERY_OUTPUT_USD_PER_1M_TOKENS=...
```

No provider pricing is hardcoded.

## Interpretation contract

The model output is constrained to:

```json
{
  "intent": "where_is",
  "entity": {
    "ref": "E1",
    "kind": "item",
    "label": "кабелі"
  }
}
```

The entity ref is request-local. It is never accepted as a durable World State entity ID.

Rails passes the mention through `WorldState::ResolveEntities`. Only a `resolved` result is allowed to execute `WorldState::Query`.

For `ambiguous` or `unresolved`, `query_result` remains null. The model cannot pick a candidate by itself.

## Safety boundary

The model cannot:

- answer the world question directly
- mutate World State
- invent durable entity IDs
- execute arbitrary query types
- bypass entity resolution
- choose among ambiguous entity candidates
- infer missing ownership, custody, location, containment, or disposition facts

The deterministic query layer remains the source of execution semantics.

## Next integration

A later conversation integration can translate ambiguous resolution into the existing clarification lifecycle rather than returning raw candidates. That should reuse the durable clarification/turn machinery instead of adding a second ambiguity workflow.
