# Rechibox backend spike

This Rails API slice wires raw advice text to Organized retrieval, context composition, an optional final model-generated answer, and optional reproducible run tracing.

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

## AI run tracing

`Ai::TraceRecorder` records the causal inputs that produced an advice result without introducing a database yet.

- `Ai::TraceRecorders::Disabled` is the default.
- `Ai::TraceRecorders::Jsonl` appends one immutable JSON object per advice request.

Enable local append-only tracing explicitly:

```sh
AI_TRACE_STORE=jsonl
AI_TRACE_PATH=tmp/ai-runs.jsonl
```

Each trace has a stable UUID and `trace_version: "0.1"`, and captures:

- original raw input and extracted Situation Model;
- retrieval strategy plus selected Organized IDs, revisions, and scores;
- extractor mode/model/prompt version;
- answer-generator mode/model/prompt version;
- end-to-end latency;
- final answer when one exists;
- token and cost fields reserved as `null` until RubyLLM usage accounting is wired explicitly.

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

When answer generation is disabled the response exposes `answer_mode: "disabled"` and omits `answer`. When enabled, the same endpoint additionally returns the final user-facing `answer` while keeping the situation, retrieval trace, and composed context observable.

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

RubyLLM remains bounded by explicit Rails-owned stages: extraction structures the situation, retrieval selects Organized records, context composition prepares the model input, answer generation produces the final prose, and trace recording persists the causal execution record. No autonomous agent loop is required for this pipeline.
