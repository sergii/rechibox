# Box Identity + QR v0.1

This slice gives every local physical box a stable machine identity, a human-facing code, a renderable QR, and a camera path that resolves the QR back to the box contents.

## User goal

A person standing in front of a physical storage box should be able to scan its Rechibox QR and immediately see the locally stored contents of that box.

## Identity model

Each `inventory_boxes` row has three identifiers with different jobs:

```text
SQLite row id      42
human code         BOX-000042
public id          128-bit opaque random hex
QR payload         rechibox://box/<public_id>
```

The numeric row id remains an internal local database key. `BOX-000042` is deliberately human-friendly and printable. It is not used as the machine identity because codes can collide across independent devices and future accounts.

The native `public_id` is generated locally from SQLite `randomblob(16)` and persisted. Existing v2 boxes receive a new public id and deterministic display code during the v2 -> v3 migration without changing their row ids or item assignments. The web adapter applies the same identity contract when upgrading the existing localStorage representation.

## Flow

```text
My boxes
  -> create/open box
  -> show BOX-000042 + QR
  -> attach QR to physical box

Scan QR
  -> expo-camera reads QR only
  -> validate rechibox://box/<public_id>
  -> resolve local box
  -> show box details + contents
```

Unknown Rechibox ids and non-Rechibox QR payloads are explicit recoverable states. Scanning does not contact a backend in v0.1.

## Technology choices

- `expo-camera` remains the scanner. No VisionCamera or Nitro ZXing dependency is introduced.
- `react-native-qrcode-svg` renders the QR locally on top of the existing `react-native-svg` dependency.
- `expo-sqlite` remains the native source of truth for local boxes and assignments.
- Web keeps its platform-specific localStorage adapter so static export does not depend on SQLite.
- Barcode scanning is enabled through the Expo camera config plugin rather than a manually duplicated Android camera permission declaration.

Native iOS/Android camera acceptance requires a real camera device. An iOS Simulator can validate routing, QR rendering, persistence, and the SQLite migration, but it is not proof of real barcode scanning. Expo Go can be used for a fast device smoke test; the product-specific development binary must still be rebuilt once to verify config-plugin integration.

The repeatable local procedure is documented in `docs/development/box-identity-qr-smoke.md`.

## Runtime acceptance

Before merging this slice as complete:

1. start from an installation that already has v2 boxes and inventory assignments;
2. upgrade and confirm all old boxes/items remain and each box now has a stable `BOX-...` code and QR;
3. verify the web legacy localStorage shape upgrades without losing boxes/items/assignments;
4. create a new box and confirm its QR remains identical after a full app restart or browser reload;
5. scan that QR on a physical device and confirm the correct box opens;
6. scan a non-Rechibox QR and confirm the app offers a retry instead of navigating;
7. verify camera permission denial/settings return, background/foreground behavior, safe areas, light/dark appearance, and back navigation;
8. rebuild the product-specific native runtime and repeat one successful QR scan;
9. run TypeScript, lint, Expo dependency compatibility, and Expo Doctor checks.

## Deferred

Backend resolution, shared/cross-device boxes, ownership/authorization, QR label printing/export, label templates, batch scanning, damaged-code performance tuning, and scanner-engine migration remain deferred until a concrete requirement needs them.
