# Rechibox backend spike

This Rails API slice wires raw advice text to Organized retrieval and model-ready context composition.

```text
POST /api/advice
  -> SituationExtractor
  -> Situation Model v0.1
  -> deterministic Organized retrieval
  -> structured context composition
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

`Ai::SituationExtractor` is the boundary. Two implementations exist:

- `Ai::SituationExtractors::Passthrough` is the default. It preserves the raw message and makes no model call.
- `Ai::SituationExtractors::RubyLlm` uses RubyLLM structured output to populate Situation Model v0.1.

Paid/model-backed extraction is fail-closed. It is enabled only when both of these are set explicitly:

```sh
AI_SITUATION_EXTRACTOR=ruby_llm
AI_SITUATION_MODEL=<provider-model-name>
```

Configure the provider key separately, for example `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, or `GEMINI_API_KEY`. The default remains `passthrough`, so adding RubyLLM does not make ordinary development or CI spend model credits.

Example model-free request:

```sh
curl -X POST http://localhost:3000/api/advice \
  -H 'Content-Type: application/json' \
  -d '{
    "message": "Третій день перекладаю коробки, але нічого не змінюється.",
    "limit": 4
  }'
```

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

RubyLLM extraction is intentionally bounded: it structures the user's situation only. It does not retrieve Organized knowledge, recommend actions, choose products, or perform an autonomous agent loop. Retrieval and context composition remain explicit Rails-owned steps.
