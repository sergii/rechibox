# HomeBox competitive analysis

Status: accepted product research
Date: 2026-09-15
Reference: https://github.com/sysadminsmedia/homebox

## Summary

HomeBox is a mature home inventory and organization product. It strongly validates the user problem around cataloging possessions, assigning them to locations, labeling them, and retrieving them later.

It is a direct competitor to the inventory layer of Rechibox, but it should not define the product boundary for Rechibox.

The strategic conclusion is:

> Rechibox should not compete by becoming another inventory database. Its differentiation should come from camera-first capture, a durable model of the user's physical world, contextual reasoning, organization knowledge, and actions that connect digital inventory to real storage.

A useful shorthand is:

> HomeBox remembers inventory. Rechibox should understand the physical world around that inventory and help the user act on it.

## What HomeBox validates

HomeBox demonstrates sustained demand for several capabilities that should be treated as validated domain concepts rather than speculative Rechibox ideas:

- items and locations;
- nested organization;
- categories and tags;
- custom fields;
- search;
- images and attachments;
- purchase information;
- documents and warranty tracking;
- maintenance tracking;
- asset identifiers;
- QR codes and QR scanning;
- printable labels;
- barcode-oriented workflows;
- import and export;
- API access;
- mobile-friendly inventory access.

These capabilities are useful evidence about what users eventually need from a mature household inventory system.

They are not, by themselves, a Rechibox moat.

## Product boundary

### HomeBox

The core HomeBox question is:

> What do I own, and where is it?

Its model is primarily inventory-centric. The user explicitly creates and manages records that represent physical objects and locations.

Conceptually:

```text
Item
  name
  location
  labels
  custom fields
  attachments
  purchase data
  maintenance
```

This is a strong and useful model for inventory management.

### Rechibox

The intended Rechibox question is broader:

> What do I have, where is it, what does the current physical situation mean, and what should I do next?

The target loop is:

```text
SEE
camera / QR / barcode / receipt
        |
        v
UNDERSTAND
objects / containers / spaces / relationships
        |
        v
REMEMBER
World State
        |
        v
REASON
personal context + Organized knowledge
        |
        v
ACT
find / move / pack / label / sell / donate / store
```

The inventory database is therefore one substrate inside the product, not the product itself.

## Current Rechibox evidence

Rechibox already contains technical work that supports this broader direction.

The mobile application has a camera-first inventory flow with on-device object detection. The current implementation uses `react-native-executorch` with a YOLO object detector, exposes detections with confidence and bounding boxes, lets the user correct or exclude recognized items, and persists confirmed inventory locally in SQLite.

The backend is also moving beyond CRUD inventory. It separates reusable organization knowledge, conversation state, the current Situation Model, and persistent World State. World State models durable entities and provenance-bearing claims and already reserves relationships such as ownership, custody, location, disposition, containment, attributes, and generic facts.

This architecture should be preserved as the product differentiator rather than flattened into a conventional `items` application.

## Competitive capability map

| Capability | HomeBox | Rechibox direction | Strategic treatment |
| --- | --- | --- | --- |
| Manual inventory records | Strong | Needed | Commodity |
| Locations | Strong | Needed | Commodity foundation |
| Nested locations | Strong | Needed | Learn from established patterns |
| Categories / tags | Strong | Eventually useful | Commodity |
| Search | Strong | Needed | Commodity |
| Images | Strong | Camera-first | Rechibox can differentiate in capture |
| QR / asset IDs | Strong | Needed | Adopt concept |
| Label printing | Strong | Likely useful | Later capability |
| Barcode workflows | Present | Useful complement to vision | Later capability |
| Attachments / receipts | Strong | Useful | Later capability |
| Warranty tracking | Strong | Possible | Not MVP |
| Maintenance | Strong | Possible | Not MVP |
| Native camera workflow | Not core | Core | Differentiator |
| On-device object recognition | Not core | Core | Differentiator |
| Physical-world state | Conventional inventory graph | Explicit World State | Differentiator |
| Provenance-bearing claims | Not product core | Designed into backend | Differentiator |
| Conversational context | Not core | Core backend direction | Differentiator |
| Organization knowledge | Not core | Organized integration | Differentiator |
| Self-storage discovery / booking | Not core | Existing product slice | Differentiator / expansion path |
| Reasoning over possessions | Not core | Target behavior | Primary moat candidate |

## Commodity capabilities

The following should not be treated as strategic innovation. They are expected capabilities of a mature inventory product:

- create/edit/delete items;
- names, descriptions, categories and tags;
- rooms and locations;
- nested location browsing;
- search and filtering;
- images and attachments;
- stable item identifiers;
- QR codes;
- labels;
- imports and exports;
- barcode lookup;
- receipts, warranties and maintenance metadata.

Rechibox may eventually need many of these, but implementing more of them does not by itself make the product stronger.

They should be added when they unlock an important user workflow.

## Rechibox differentiators

### 1. Camera-first capture

The user should be able to point the phone at a physical situation rather than manually model it from scratch.

Examples:

- photograph a group of objects;
- photograph a shelf;
- photograph the contents of a box before closing it;
- scan an existing QR label;
- scan a retail barcode when product identity matters.

Vision, QR and barcode identification should complement one another.

### 2. Physical World State

Rechibox should maintain an explicit representation of the user's physical environment rather than only independent inventory rows.

A possible projection:

```text
World
  Home
    Garage
      Rack A
        Shelf 2
          Box 17
            Drill
            Charger

  Self-storage
    Unit A14
      Winter tires
```

Relationships matter as much as entities:

```text
Drill located_in Box17
Box17 located_in Shelf2
Shelf2 part_of RackA
WinterTires located_in UnitA14
Tent lent_to Dmytro
```

This enables reasoning that is difficult to express through ordinary item CRUD.

### 3. Reasoning over personal context

Rechibox should answer questions about the user's actual possessions and spaces, for example:

- Where is my Makita charger?
- Which boxes are in the garage?
- What did I move to self-storage?
- Which items should not be stored in a damp basement?
- What can I donate before moving?
- Which container should this object go into?

The important boundary is that answers combine personal state with reusable domain knowledge.

### 4. Organization knowledge

Organized should remain separate from the user's personal World State.

```text
Organized       = reusable storage and organization knowledge
World State     = facts about this user's physical world
Situation Model = interpretation of the current request
Conversation    = local conversational context
```

This separation allows Rechibox to advise rather than merely retrieve records.

### 5. Action loop

The product should eventually turn understanding into actions:

- label a container;
- move items into another container;
- produce a packing plan;
- generate a sell/donate list;
- recommend a storage environment;
- find an appropriate self-storage option;
- remember where the move actually happened.

The value comes from closing the loop between observation, memory, recommendation, and real-world action.

## Product principles derived from HomeBox

### Learn from the domain, not from the code

HomeBox is useful product research. We should study its workflows, issue history, terminology, feature requests, and domain modeling decisions.

We should not copy implementation code into Rechibox. HomeBox is licensed under AGPL-3.0, while Rechibox currently has a separate licensing context. Any future reuse must be reviewed deliberately.

### Preserve generic entity modeling

HomeBox's move toward a more unified entity model for items and locations supports a lesson that is already emerging in Rechibox: physical objects and places share many capabilities.

Rechibox should avoid prematurely creating unrelated models for every object type when a generic entity plus typed relationships is sufficient.

At the same time, Rechibox should not erase meaningful semantic distinctions. `item`, `container`, `space`, `person`, and `storage_unit` can remain explicit entity types even if they share infrastructure.

### Add QR and asset identity deliberately

Stable physical identifiers are a proven requirement.

A likely Rechibox flow is:

```text
BOX-00124
   +
QR label
   -> scan
   -> Box 124
   -> current contents
   -> current location
   -> history / actions
```

QR should identify Rechibox entities, while barcodes can identify manufacturer/product information. They solve different problems.

### Model containment explicitly

The useful hierarchy is not merely `item.location_id`.

Users naturally think in nested physical containment:

```text
home
  room
    cabinet
      shelf
        box
          item
```

The World State relationship model should preserve this rather than reduce everything to a single flat location field.

### Keep import/export in the long-term product contract

Users invest real effort in building inventories. Data portability reduces adoption risk and vendor-lock-in anxiety.

It does not need to be an MVP feature, but the domain model should avoid making future export unnecessarily difficult.

## Explicit non-goals

Rechibox should not currently attempt to match HomeBox feature-for-feature.

In particular, do not prioritize the following merely because HomeBox has them:

- warranty management;
- purchase-price reporting;
- complex custom-field systems;
- rich maintenance scheduling;
- advanced report builders;
- sophisticated label-template editors;
- exhaustive import formats;
- broad administrative configuration.

These are mature-product capabilities, not proof of the initial Rechibox value proposition.

## Recommended MVP loop

The near-term product should optimize one complete loop:

```text
Open Rechibox
    |
    v
Take a photo
    |
    v
Detect several objects
    |
    v
Review / correct
    |
    v
Choose or create where they are
    |
    v
Persist that physical state
    |
    v
Ask a natural-language question later
    |
    v
Retrieve the correct object and location
```

A stronger second loop is:

```text
Observe physical situation
    |
    v
Understand contents + environment
    |
    v
Apply organization/storage knowledge
    |
    v
Recommend a concrete action
```

Example:

> This box contains electronics and paper documents. Do not put it in a damp basement. Move it to a dry indoor location or sealed storage.

That is a much stronger differentiation than adding another inventory form.

## Positioning

Avoid positioning such as:

> Smart home inventory app.

That puts Rechibox directly into a mature commodity category.

Prefer positioning closer to:

> Rechibox understands what you own, where it is, and what to do with it.

or:

> An AI layer over your physical possessions and storage.

The exact marketing language can change. The important product boundary is that Rechibox should understand and reason about a user's physical world rather than merely store records about it.

## Decision

Use HomeBox as a benchmark for mature inventory capabilities and as a source of domain lessons.

Do not use HomeBox as the target product specification.

For roadmap decisions, classify proposed work into two buckets:

1. **Inventory commodity** - necessary foundations that established inventory products already provide.
2. **Rechibox differentiation** - camera-native capture, World State, contextual reasoning, organization knowledge, and physical actions.

When trade-offs are required, prioritize a complete differentiating user loop over broader commodity feature coverage.
