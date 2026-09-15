# World Query Answer Renderer v0.1

The answer renderer turns deterministic `WorldState::Query` results into short user-facing text without another model call.

```text
natural language
  -> bounded query interpreter (optional AI)
  -> deterministic entity resolution
  -> deterministic WorldState::Query
  -> deterministic QueryAnswerRenderer
  -> text + provenance
```

## Contract

Natural query responses now include an `answer` when an entity mention can be interpreted and resolution has been attempted:

```json
{
  "contract_version": "0.1",
  "status": "resolved",
  "locale": "uk",
  "text": "Розташування «кабелі»: синя коробка → полиця → гараж.",
  "supporting_claim_ids": ["...", "...", "..."]
}
```

Statuses are `resolved`, `ambiguous`, `unknown`, `conflict`, and `unavailable`.

The renderer supports the five World Query v0.1 intents:

- `where_is`
- `what_is_in`
- `contents_recursive`
- `who_owns`
- `who_has_custody`

## Safety semantics

The renderer is presentation only. It never reads arbitrary facts, resolves entities, traverses the graph, mutates World State, or asks a model to fill gaps.

Important behavior:

- no physical parent path is rendered as `unknown`, not as a known top-level location
- no recorded contents is rendered as `unknown`, not as an assertion that a container is empty
- multiple physical location paths are `ambiguous`
- graph cycles are `conflict`
- multiple owners are a valid resolved collection because ownership is not singleton
- multiple active custody targets are `conflict` because custody is singleton
- supporting typed claim IDs are returned with the rendered answer
- merged tombstones remain excluded upstream by the deterministic query/read model

## Locale

v0.1 uses a deliberately small deterministic locale detector for Ukrainian, Russian, and English. It does not call AI for translation or grammatical inflection. Entity labels are preserved as stored/interpreted, and templates avoid pretending to understand arbitrary label grammar.

This is a presentation contract, not a localization framework. A product locale should replace message-script detection when the mobile client owns explicit locale settings.

## Cost

The renderer always makes zero model calls. When `AI_WORLD_QUERY_INTERPRETER=disabled`, the whole natural-query endpoint still makes zero model calls and returns `answer: null` because no bounded query exists to render.
