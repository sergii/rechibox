# Local Inventory Boxes v0.1

This slice makes a physical box a first-class local inventory container.

## User goal

A user can create a named physical box and assign persisted inventory items to it so the app can answer a basic question: "Which box contains this thing?"

## Local model

```text
inventory_boxes
- id
- name
- created_at

inventory_items
- id
- name
- source_label
- confidence
- box_id -> inventory_boxes.id, nullable
- created_at
```

`box_id = null` means the item is saved but not assigned to a physical box yet.

Deleting boxes is intentionally out of scope for v0.1. The foreign key uses `ON DELETE SET NULL` so future deletion can preserve inventory items.

## Product behavior

- `/boxes` creates and lists local boxes.
- `/inventory-list` shows each item's current box and links to box management.
- An item can be assigned to a box, moved to another box, or returned to `Без коробки`.
- The conversation-first home keeps inventory reachable as a secondary action; physical boxes are reached through the inventory flow.
- Box item counts are derived from the item relation rather than stored separately.

## Persistence

The existing `rechibox.db` SQLite database advances from schema version 1 to 2. Existing inventory items are preserved and migrate with `box_id = null`.

The database enables WAL and foreign keys. User-entered values are passed through bound query parameters rather than interpolated into SQL.

## Deliberately deferred

- QR/barcode identity for a box
- photos of boxes
- box dimensions/material/type
- nested containers
- storage-room or shelf location
- backend sync and cross-device identity
- delete/archive flows
- bulk move operations
- selecting a destination box directly in the AI capture flow

## Runtime acceptance

1. Upgrade an installation that already has inventory items.
2. Confirm all old items remain visible and show `Коробка: не призначено`.
3. Create two boxes.
4. Assign an item to the first box and verify the label updates.
5. Move the item to the second box.
6. Set the item back to `Без коробки`.
7. Kill and restart the app and confirm boxes and assignments persist.
8. Verify light/dark appearance, keyboard reachability on box creation, back navigation, and safe-area behavior on iOS and Android.

Static checks do not replace this runtime persistence/migration verification.
