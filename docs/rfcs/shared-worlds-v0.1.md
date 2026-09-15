# RFC: Accounts and Shared Worlds v0.1

Status: proposed

## Summary

Rechibox should model cross-device and family/friend sharing as access to a shared physical `World`, not as synchronization between devices.

The core separation is:

```text
Account / User = who is using Rechibox
World          = durable map of spaces, containers, items, people, and claims
Membership     = an Account's authorization to a World
```

A server-backed World can therefore be opened from several devices and by several people according to explicit membership permissions. Cross-device sync becomes a consequence of this model rather than a separate product primitive.

## Product scenario

A user inventories a home, garage, workshop, or other space. Later a sister, partner, friend, tenant, or other trusted person asks whether something exists or where it is. Instead of the owner searching on their behalf, the owner can invite that person to the relevant World.

Example:

```text
Serhii account
    |
    v
World: My Home
  apartment
  wardrobe
  storage room
    bicycle
  garage

Members:
  Serhii  owner
  sister  member or guest
  friend  guest
```

The invited person can then ask the same bounded World queries, for example `Де велосипед?`, subject to their permissions.

## Decision

### Account is not World

An Account represents authentication and product identity. It must not own physical-world truth directly.

A World is the durable physical-world state Rechibox already models. One account may participate in multiple Worlds, and one World may have multiple accounts.

```text
Account A --membership--> World Home
Account A --membership--> World Workshop
Account B --membership--> World Home
```

### Membership is explicit

Membership is the authorization boundary between Account and World.

Initial roles:

| Role | Read/search | Change World | Invite/manage access |
| --- | --- | --- | --- |
| owner | yes | yes | yes |
| member | yes | yes | no |
| guest | yes | no | no |

These roles are intentionally small for v0.1. Authorization must be enforced on the backend, not inferred from mobile UI state.

### Sharing is broader than family sharing

Family sharing is a primary use case, but the domain primitive is Shared World access. It should also support partners, friends, tenants, house sitters, workers, and other trusted collaborators without encoding family relationships into authorization.

### World Person is not Account

A `person` entity inside World State describes a person in the physical-world knowledge graph. A Rechibox Account is an authenticated product identity. They must remain separate.

For example, World State may already contain:

```text
Person: "my sister"
ownership(bicycle, sister)
```

If the sister later creates an Account, Rechibox may explicitly link that World person to her membership/account, but it must never infer that identity automatically from a label, name, email, or conversation. This follows the existing explicit identity-resolution boundary.

### Anonymous World can later be claimed

The current mobile bootstrap creates device-local continuity without authentication. Account introduction must preserve that work.

Expected migration:

```text
anonymous device
  -> creates World
  -> inventories items
  -> later creates/signs into Account
  -> explicitly claims/attaches existing World
  -> owner Membership created
  -> same World ID and physical history retained
```

Creating an account must not silently create a second World and abandon the anonymous one.

## Sharing scope

v0.1 can authorize at whole-World scope.

The data model should not prevent later scoped grants such as:

```text
share World
share space/subtree: Garage
share container: BOX-000042
share selected entities
share until timestamp
```

Scoped sharing is not required for the first implementation. It should be added only with an explicit authorization model that handles graph traversal and prevents information leakage through search, counts, relationships, or conversational answers.

## QR relationship

Box Identity QR and Shared Worlds are complementary but separate.

A QR identifies a physical box. It does not grant access by itself.

```text
scan QR
  -> resolve box public identity
  -> authorize Account/Membership against World
  -> show permitted box data
```

Future share links or guest QR flows must use separate revocable authorization tokens. The opaque box `public_id` must not become a bearer credential.

## Server model sketch

A later implementation can introduce relational records approximately like:

```text
accounts
  id
  ...authentication identity...

world_memberships
  id
  world_id
  account_id
  role: owner | member | guest
  created_at
  revoked_at

world_person_links
  id
  world_id
  world_entity_id
  account_id
  linked_by_account_id
  linked_at
```

Invitations should be separate lifecycle records rather than pre-created memberships:

```text
world_invitations
  id
  world_id
  inviter_account_id
  role
  token_digest
  expires_at
  accepted_at
  revoked_at
```

Exact authentication provider and token/session implementation are deferred.

## Authorization invariants

- Every server-side World read and mutation must authorize the current Account or anonymous session against that World.
- A `guest` must not mutate World State.
- Membership revocation must take effect server-side without requiring a mobile update.
- Box `public_id`, World IDs, entity IDs, and QR payloads are identifiers, not authorization secrets.
- Invitations must be revocable and expiring.
- Linking a World `person` entity to an Account requires an explicit decision.
- Sharing must not weaken existing state-update, clarification, identity-resolution, or proposal-review safety boundaries.
- Audit provenance should eventually include the acting account/membership for shared mutations.

## Consequence for cross-device sync

Cross-device sync is no longer modeled as device-to-device replication:

```text
Device A ----\
              -> authenticated API -> shared server World
Device B ----/
Friend phone -/
```

The local mobile database can remain a cache/offline working set, but the server World is the collaboration authority once an anonymous World is claimed by an Account.

Conflict/offline synchronization policy is a later RFC. Account/World/Membership boundaries should be established before implementing generic cross-device replication.

## Product language

Working product concept: **Shared Worlds**.

`Family Sharing` can be user-facing copy or onboarding language for a common scenario, but it should not be the domain model name.

A useful product framing is:

> Rechibox is shared memory for the physical world.

This is a product direction, not a requirement to expose internal `World State` terminology to users.

## Non-goals for v0.1

- no automatic matching of World people to Accounts
- no per-claim ACLs
- no graph-subtree sharing yet
- no public searchable Worlds
- no QR-as-authentication
- no generic CRDT/offline conflict system yet
- no paid/model dependency for authorization

## Implementation sequence

```text
Box Identity / QR
  -> complete personal inventory + query loop
  -> Account authentication
  -> claim existing anonymous World
  -> World Membership
  -> invite / accept / revoke
  -> Shared World read access
  -> member mutations through existing safe state-update boundaries
  -> scoped sharing
  -> explicit offline/cross-device conflict policy
```

The immediate product work remains Box Identity and the complete personal Rechibox loop. This RFC establishes the boundary so that those features do not accidentally encode device ownership as World ownership.
