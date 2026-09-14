# Rechibox backend spike

This Rails API slice wires raw advice text to Organized retrieval, context composition, an optional final model-generated answer, optional reproducible run tracing, multi-turn conversations, and persistent World State v0.1.

```text
POST /api/advice
  -> SituationExtractor
  -> Situation Model v0.1
  -> deterministic Organized retrieval
  -> structured context composition
  -> optional AnswerGenerator
  -> optional TraceRecorder
  -> JSON response

POST /api/advice/dry_run
  -> caller-supplied Situation Model v0.1
  -> deterministic Organized retrieval
  -> structured context composition
  -> JSON response
```

The canonical knowledge remains in `sergii/organized`. Generate `dist/organized-v1.jsonl` there and point this app at it:

```sh
cd ../organized
bundle exec ruby scripts/export_runtime.rb dist/organized-v1.jsonl

cd ../rechibox/backend
bundle install
ORGANIZED_RUNTIME_PATH=../../organized/dist/organized-v1.jsonl bundle exec rails server
```

## Situation extraction

`Ai::SituationExtractor` is the extraction boundary. Two implementations exist:

- `Ai::SituationExtractors::Passthrough` is the default. It preserves the raw message and makes no model call.
- `Ai::SituationExtractors::RubyLlm` uses RubyLLM structured output to populate Situation Model v0.1.

Model-backed extraction is fail-closed and is enabled only when both are set explicitly:

```sh
AI_SITUATION_EXTRACTOR=ruby_llm
AI_SITUATION_MODEL=<provider-model-name>
```

When advice is generated inside a conversation, the extractor receives both earlier user/assistant turns and the persistent World State. The current user message remains the Situation Model `raw_input`; history and world state are context used to resolve references and carry forward still-relevant state. World State is explicitly treated as potentially stale or incomplete, so a direct correction in the current message wins.

## Final answer generation

`Ai::AnswerGenerator` is a separate boundary after retrieval and context composition.

- `Ai::AnswerGenerators::Disabled` is the default and returns no final answer.
- `Ai::AnswerGenerators::RubyLlm` turns the composed situation + selected Organized knowledge into the user-facing answer.

Model-backed answer generation is also fail-closed:

```sh
AI_ANSWER_GENERATOR=ruby_llm
AI_ANSWER_MODEL=<provider-model-name>
```

Configure provider credentials separately, for example `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, or `GEMINI_API_KEY`.

Enabling both RubyLLM situation extraction and RubyLLM answer generation performs two model calls per advice request. Leaving the defaults unchanged performs zero model calls, so CI and normal development do not spend model credits.

## Conversation contract v0.1

The product-facing conversation API is intentionally small:

```text
POST /api/conversations
GET  /api/conversations/:id
POST /api/conversations/:id/messages
```

Creating a conversation without a `world_id` creates a fresh World State and associates it with the conversation:

```sh
curl -X POST http://localhost:3000/api/conversations
```

To start another conversation against an existing world:

```sh
curl -X POST http://localhost:3000/api/conversations \
  -H 'Content-Type: application/json' \
  -d '{"world_id":"<world-id>"}'
```

Send the first turn:

```sh
curl -X POST http://localhost:3000/api/conversations/<id>/messages \
  -H 'Content-Type: application/json' \
  -d '{"message":"У мене маленька кімната і багато коробок.","limit":4}'
```

A later turn automatically passes the persisted earlier turns through SituationExtractor and ContextComposer:

```sh
curl -X POST http://localhost:3000/api/conversations/<id>/messages \
  -H 'Content-Type: application/json' \
  -d '{"message":"А що робити з тими, які я вже продав?","limit":4}'
```

Conversation records use `contract_version: "0.1"`, contain a `world_id`, and messages contain an immutable UUID, role, text, timestamp, and optional trace ID. The spike uses a file-backed JSON directory so the conversation boundary is real without forcing a database decision yet. Configure its location with:

```sh
CONVERSATION_STORE_PATH=tmp/conversations
```

The default is `tmp/conversations`. Writes are lock-protected and conversation IDs are validated before filesystem access. PostgreSQL/ActiveRecord can later replace this adapter behind `Conversations::Store`.

## World State v0.1

World State is Rechibox-owned durable personal state. It is separate from both the conversation transcript and Organized knowledge.

```text
Organized       = reusable domain rules
Conversation    = thread-local transcript
Situation Model = current-request interpretation
World State     = durable state of spaces, containers, items, people, and claims
```

API:

```text
POST /api/worlds
GET  /api/worlds/:id
```

By default worlds are persisted under:

```sh
WORLD_STATE_STORE_PATH=tmp/worlds
```

A world contains durable `entities` plus provenance-bearing `claims`. Situation Model entity refs such as `E1` remain request-local and are never reused as world IDs.

After each conversation turn `WorldState::ProjectSituation` conservatively promotes only explicit `user` or `observed` facts and lightweight entities. It does not persist hypotheses or recommendations. Repeated identical facts are deduplicated.

The contract reserves distinct predicates for `ownership`, `custody`, `location`, `disposition`, `contains`, `attribute`, and generic `fact`. v0.1 deliberately does not infer those typed relationships from prose yet; that requires a dedicated state-update contract with conflict handling. See `docs/world-state-v0.1.md`.

## AI run tracing and usage

`Ai::TraceRecorder` records the causal inputs that produced an advice result without introducing a database yet.

- `Ai::TraceRecorders::Disabled` is the default.
- `Ai::TraceRecorders::Jsonl` appends one immutable JSON object per advice request.

Enable local append-only tracing explicitly:

```sh
AI_TRACE_STORE=jsonl
AI_TRACE_PATH=tmp/ai-runs.jsonl
```

Trace format `0.3` captures the original input, conversation history, the World State snapshot used for the run, Situation Model, retrieval provenance, final answer, per-stage timings, and model usage. The API also exposes the same `metrics` block even when trace persistence is disabled.

Timings are measured independently for extraction, retrieval, context composition, answer generation, and the complete request. When RubyLLM exposes token usage, the extractor and answer generator record input/output tokens separately and aggregate them for the request.

Pricing is deliberately not hardcoded because provider prices change. Estimated cost is populated only when explicit per-million-token rates are configured for the selected models:

```sh
AI_SITUATION_INPUT_USD_PER_1M_TOKENS=...
AI_SITUATION_OUTPUT_USD_PER_1M_TOKENS=...
AI_ANSWER_INPUT_USD_PER_1M_TOKENS=...
AI_ANSWER_OUTPUT_USD_PER_1M_TOKENS=...
```

Without those rates, token counts can still be recorded while `estimated_cost_usd` remains `null`.

The API exposes `trace_mode`, and when persistence is enabled it also returns `trace_id`. JSONL is a deliberately small persistence adapter for this spike, not the long-term database design. A later ActiveRecord/PostgreSQL implementation can replace it behind the same boundary.

Example model-free request:

```sh
curl -X POST http://localhost:3000/api/advice \
  -H 'Content-Type: application/json' \
  -d '{
    "message": "Третій день перекладаю коробки, але нічого не змінюється.",
    "limit": 4
  }'
```

When answer generation is disabled the response exposes `answer_mode: "disabled"` and omits `answer`. When enabled, the same endpoint additionally returns the final user-facing `answer` while keeping the situation, retrieval trace, composed context, timings, and usage observable.

Example dry-run request:

```sh
curl -X POST http://localhost:3000/api/advice/dry_run \
  -H 'Content-Type: application/json' \
  -d '{
    "limit": 4,
    "situation": {
      "contract_version": "0.1",
      "raw_input": "Третій день перекладаю коробки, але нічого не змінюється.",
      "facts": [{"text":"Коробки постійно переміщуються.","source":"user"}],
      "goals": [{"text":"Бачити реальний прогрес.","source":"user"}],
      "constraints": [],
      "uncertainties": [],
      "hypotheses": [],
      "entities": []
    }
  }'
```

`limit` is optional. When omitted, the pipeline exposes the complete ranked candidate list. Selection policy is deliberately not hidden inside the retriever.

RubyLLM remains bounded by explicit Rails-owned stages: extraction structures the situation, retrieval selects Organized records, context composition prepares the model input, answer generation produces the final prose, trace recording persists the causal execution record, and World State projection persists only safe durable state. Conversation persistence wraps those stages but does not turn them into an autonomous agent loop.
