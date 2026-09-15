# Natural Language World Query v0.1

Natural Language World Query is a narrow interpretation boundary in front of the deterministic World Query service.

The interpreter never answers from World State directly. It may only classify one supported query intent and extract one entity mention.

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

## Default mode

The default interpreter is deterministic and makes zero model calls:

```sh
AI_WORLD_QUERY_INTERPRETER=deterministic
```

It recognizes a deliberately small set of Ukrainian, Russian, and English forms for the five bounded intents. Unsupported wording fails closed with no query.

The interpreter can still be disabled explicitly:

```sh
AI_WORLD_QUERY_INTERPRETER=disabled
```

RubyLLM remains opt-in:

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

An interpreter produces the same bounded shape:

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

For `ambiguous` or `unresolved`, `query_result` remains null. No interpreter can pick a candidate by itself.

## Safety boundary

The interpreter cannot:

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
