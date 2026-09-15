# Natural Language World Query v0.1

Natural Language World Query is a narrow interpretation boundary in front of the deterministic World Query service.

The interpreter never answers from World State directly. It may only classify one supported query intent and extract one entity mention.

## Pipeline

```text
user message
  -> query interpreter
  -> bounded intent + entity mention
  -> deterministic entity resolution
  -> resolved: WorldState::Query -> deterministic answer
  -> ambiguous: durable clarification -> explicit user selection -> resume same query
```

Supported intents are inherited from World Query v0.1:

```text
where_is
what_is_in
contents_recursive
who_owns
who_has_custody
```

## Endpoints

Start a query:

```text
POST /api/worlds/:id/natural_query
```

Request:

```json
{
  "message": "Де мої кабелі?"
}
```

When entity resolution is ambiguous, the response includes a durable pending `clarification` with up to three resolver candidates. The query is not executed.

Resume after an explicit selection:

```text
POST /api/worlds/:id/natural_query/clarifications/:clarification_id/answer
```

```json
{
  "action": "select",
  "option_id": "1"
}
```

Or close the ambiguity without guessing:

```json
{
  "action": "none_of_above"
}
```

The resume context stores the original bounded query, message, and optional depth. A selected option is revalidated by the existing `AnswerClarification` service before its durable entity ID is used. The interpreter is not called again.

## Default mode

The default interpreter is deterministic and makes zero model calls:

```sh
AI_WORLD_QUERY_INTERPRETER=deterministic
```

It recognizes a deliberately small set of Ukrainian and English forms for the five bounded intents. Other wording and languages are outside this deterministic contract and fail closed with no query.

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

Rails passes the mention through `WorldState::ResolveEntities`. Only a `resolved` result, either direct or explicitly selected through a clarification, is allowed to execute `WorldState::Query`.

## Safety boundary

The interpreter cannot:

- answer the world question directly
- mutate World State
- invent durable entity IDs
- execute arbitrary query types
- bypass entity resolution
- choose among ambiguous entity candidates
- infer missing ownership, custody, location, containment, or disposition facts

The clarification path cannot merge identities or mutate World State claims. It only records the user's selection for this query and resumes the deterministic read.

The deterministic query layer remains the source of execution semantics.
