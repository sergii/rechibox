# Rechibox backend spike

This is the first Rails API slice for the advice pipeline. It is intentionally model-free.

```text
POST /api/advice/dry_run
  -> Situation Model v0.1
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

Example request:

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

`limit` is optional. When omitted, the dry run exposes the complete ranked candidate list. Selection policy is deliberately not hidden inside the retriever.

No OpenAI key, RubyLLM, embeddings, database, authentication, persistence, or model call is part of this slice. Those are later decisions.
