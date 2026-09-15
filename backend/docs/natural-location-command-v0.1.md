# Natural Location Command v0.1

Natural Location Command is the first deterministic conversational mutation path for Rechibox World State.

It supports one narrow fact pattern: the user explicitly says that an existing entity was placed or moved into another existing entity/location.

```text
"Я поклав зарядки в синю коробку"
        ↓
NaturalLocationCommand
        ↓
ResolveEntities(subject, location)
        ↓
State Update Proposal
        ↓
explicit accept/reject
        ↓
ApplyUpdate
        ↓
location(chargers, blue_box)
```

## Safety boundary

The command never mutates World State directly.

It only creates a normal pending State Update Proposal after both mentions resolve to durable World entity IDs and `ValidateUpdate` accepts the proposed typed update. Existing proposal review remains the only path that applies the change.

The deterministic grammar deliberately accepts only explicit completed-placement wording. Uncertain wording such as `Може зарядки десь у синій коробці` is unsupported and creates no proposal.

Supported v0.1 language is Ukrainian and English. Russian is intentionally not part of the deterministic product grammar.

## Location semantics

If the subject has no active location claim, the proposal uses `assert`.

If it already has a different active location, the explicit placement statement represents a physical state transition and the proposal uses `supersede` against that exact active claim.

If the requested location is already the active location, the command returns `already_current` and creates no duplicate proposal.

## Resolution

Both subject and destination pass through the existing deterministic `WorldState::ResolveEntities` boundary. The command does not invent durable IDs or choose among ambiguous candidates.

Result statuses are:

- `unsupported` - wording is outside the bounded grammar
- `unresolved` - at least one mention cannot be resolved
- `ambiguous` - at least one mention has multiple plausible entities
- `already_current` - the typed location fact is already active
- `ready_for_review` - one pending proposal was created

Ambiguity clarification for commands is deferred. v0.1 fails closed rather than guessing.

## API

```text
POST /api/worlds/:id/natural_location_command
```

Request:

```json
{
  "message": "Я поклав зарядки в синю коробку"
}
```

A successful new fact returns `ready_for_review` plus the pending proposal. The caller reviews it through the existing endpoints:

```text
POST /api/worlds/:id/proposals/:proposal_id/accept
POST /api/worlds/:id/proposals/:proposal_id/reject
```

## Cost

This path is fully deterministic and model-free. It does not enable RubyLLM, OpenAI, or any other provider call.
