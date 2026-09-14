# Rechibox backend spike

This Rails API slice wires raw advice text to Organized retrieval, context composition, and an optional final model-generated answer.

```text
POST /api/advice
  -> SituationExtractor
  -> Situation Model v0.1
  -> deterministic Organized retrieval
  -> structured context composition
  -> optional AnswerGenerator
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

RubyLLM remains bounded by explicit Rails-owned stages: extraction structures the situation, retrieval selects Organized records, context composition prepares the model input, and answer generation produces the final prose. No autonomous agent loop is required for this pipeline.
