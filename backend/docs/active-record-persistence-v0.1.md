# Active Record persistence v0.1

Rechibox now uses PostgreSQL-backed Active Record document stores by default while preserving the existing domain store interfaces.

## Why document tables first

The current services already own the domain transitions. This migration deliberately changes persistence without redesigning the domain model at the same time.

Each aggregate is stored as JSONB behind the same interfaces that previously used JSON files:

- World State -> `world_documents`
- conversations/messages -> `conversation_documents`
- conversation turns -> `conversation_turn_documents`
- state update proposals -> `state_update_proposal_documents`
- clarifications -> `world_clarification_documents`

The JSON shape exposed by the services remains unchanged.

## Adapter selection

PostgreSQL is the default:

```sh
PERSISTENCE_ADAPTER=active_record
```

The old file adapters remain available for local compatibility and focused tests:

```sh
PERSISTENCE_ADAPTER=json_directory
```

Any other value fails closed.

## Database

The backend uses the `pg` gem and `DATABASE_URL` when provided. Development and test database names are defined in `config/database.yml`.

Typical local setup:

```sh
cd backend
bundle install
bin/rails db:prepare
bin/rails test
```

## Concurrency

Active Record adapters use row locks for read-modify-write operations. This replaces per-file `flock` locking for the default adapter.

## Transactions

`Persistence.transaction` is a no-op wrapper for the legacy file adapter and an `ActiveRecord::Base.transaction` for PostgreSQL.

`WorldState::ReviewProposal` now executes acceptance/rejection inside this boundary. With Active Record persistence, applying a World State update and changing proposal lifecycle state participate in one database transaction.

This closes the v0.1 failure mode where the world could be mutated but the proposal could remain pending if the second file write failed.

## What this does not do yet

This is intentionally a storage migration, not a normalized relational redesign. Entities, claims, messages, and lifecycle details still live inside aggregate JSONB documents.

Likely later migrations can normalize the parts that need independent querying or constraints, especially:

- world entities
- typed world claims
- messages
- proposal relations/provenance
- users and ownership scopes

The service/store boundaries should allow those migrations without changing the conversational orchestration contract.
