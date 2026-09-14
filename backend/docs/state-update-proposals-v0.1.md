# State Update Proposal v0.1

State Update Proposal is the non-mutating bridge between a Situation Model and the deterministic Typed State Update contract.

```text
current Situation Model
+ current durable World State
        ↓
Ai::StateUpdateProposer
        ↓
zero or more proposed updates
        ↓
WorldState::ValidateUpdate
        ↓
valid / invalid proposal
```

A proposal is never persisted automatically. Applying a proposal still requires the explicit `POST /api/worlds/:id/updates` mutation boundary.

## Modes

The default proposer is disabled and performs zero model calls:

```sh
AI_STATE_UPDATE_PROPOSER=disabled
```

RubyLLM proposal generation is opt-in:

```sh
AI_STATE_UPDATE_PROPOSER=ruby_llm
AI_STATE_UPDATE_MODEL=<provider-model-name>
```

Pricing is not hardcoded. Optional cost estimation uses:

```sh
AI_STATE_UPDATE_INPUT_USD_PER_1M_TOKENS=...
AI_STATE_UPDATE_OUTPUT_USD_PER_1M_TOKENS=...
```

## API

```text
POST /api/worlds/:id/proposals
```

The caller supplies a Situation Model. The endpoint loads the durable World State and returns proposals without modifying it.

Each proposal contains:

- `update`: Typed State Update v0.1 payload
- `reason`: short model rationale
- `validation.valid`: whether the deterministic mutation contract accepts it
- `validation.error`: validation error when rejected

Invalid model output remains visible as an invalid proposal rather than being silently applied or discarded.

## Safety boundary

The proposer is instructed to:

- use only explicit `user` or `observed` information from the current situation;
- never promote hypotheses, goals, recommendations, or uncertainty to durable state;
- use only existing durable entity IDs and claim IDs;
- distinguish `correct` from `supersede`;
- prefer no proposal to speculation.

`WorldState::ValidateUpdate` reuses the real `WorldState::ApplyUpdate` semantics against an in-memory copy of the world. This keeps proposal validation aligned with the actual mutation rules while guaranteeing that validation itself cannot change persistent state.

## Conversation integration

After the conservative Situation Model projection creates or refreshes lightweight durable entities, `Conversations::Reply` invokes the proposer with the resulting World State snapshot.

The response adds:

```json
{
  "state_update_proposal_mode": "disabled",
  "state_update_proposals": []
}
```

When the RubyLLM proposer is enabled, this stage adds one model call per conversation turn. It still does not apply any proposal automatically.
