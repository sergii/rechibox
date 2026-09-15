# Box Identity + QR local smoke test

This checklist validates the Box Identity slice locally without GitHub Actions, EAS Build, or OTA publishing.

## 1. Prepare the branch

First make sure the working tree is clean. The branch is intentionally rewritten while the draft is being polished, so the command below resets the local branch to the current remote head.

```sh
git status --short
git fetch origin
git switch feat/box-identity-qr
git reset --hard origin/feat/box-identity-qr
nvm use
npm ci
```

If `git status --short` prints local work you need, commit or stash it before running `git reset --hard`.

Run the lightweight checks:

```sh
npm run typecheck
npm run lint
npx expo install --check
npx expo-doctor
```

Do not continue to runtime acceptance until unexpected errors are understood.

## 2. Verify the v2 -> v3 SQLite migration on the Mac

Use a fresh iOS Simulator/Expo Go data set so the test definitely begins with schema v2 rather than a database already migrated by an earlier branch run.

Start from `main`:

```sh
git switch main
git pull --ff-only
npm ci
npm start
```

Press `i` in the Expo terminal and wait for Rechibox to load once. This creates the v2 database. Stop Metro, then terminate Expo Go without deleting its data:

```sh
xcrun simctl terminate booted host.exp.Exponent || true
```

Locate the Rechibox SQLite database inside the booted simulator:

```sh
EXPO_DATA="$(xcrun simctl get_app_container booted host.exp.Exponent data)"
find "$EXPO_DATA" -type f -name rechibox.db -print
```

Set `DB` to the printed Rechibox database path, for example:

```sh
DB="/the/path/printed/above/rechibox.db"
```

Confirm this is the v2 database and seed one box plus one assigned item without needing a simulator camera:

```sh
sqlite3 "$DB" <<'SQL'
PRAGMA user_version;
PRAGMA foreign_keys = ON;
BEGIN;
INSERT INTO inventory_boxes (name, created_at)
VALUES ('Migration box', '2026-09-15T12:00:00.000Z');
INSERT INTO inventory_items (name, source_label, confidence, box_id, created_at)
VALUES (
  'Migration item',
  'manual-smoke',
  1.0,
  last_insert_rowid(),
  '2026-09-15T12:01:00.000Z'
);
COMMIT;
SELECT id, name FROM inventory_boxes;
SELECT id, name, box_id FROM inventory_items;
SQL
```

The first value printed by `PRAGMA user_version` should be `2`.

Switch to the feature branch without clearing simulator data:

```sh
git fetch origin
git switch feat/box-identity-qr
git reset --hard origin/feat/box-identity-qr
npm ci
npm start
```

Press `i` again and use the same simulator. Open `Мій інвентар` -> `Мої коробки` -> `Migration box`. Verify the box has a `BOX-......` code, QR, and contains `Migration item`.

Terminate Expo Go again and inspect the database:

```sh
xcrun simctl terminate booted host.exp.Exponent || true
sqlite3 "$DB" <<'SQL'
PRAGMA user_version;
SELECT id, name, length(public_id), public_id, code FROM inventory_boxes;
SELECT id, name, box_id FROM inventory_items;
SQL
```

Expected results:

- `user_version` is `3`;
- the original box id is unchanged;
- `public_id` has length `32`;
- the code is derived from the existing row id, for example `BOX-000001`;
- `Migration item` still points to the same `box_id`.

Launch the feature branch once more and confirm the QR/code do not change after restart.

## 3. Verify the web localStorage migration

Start the web app from the feature branch:

```sh
npm run web
```

Open browser DevTools, go to Console, and seed the old v0.1 shape:

```js
localStorage.setItem(
  'rechibox.inventory.v0.1',
  JSON.stringify({
    nextBoxId: 2,
    nextItemId: 2,
    boxes: [
      {
        id: 1,
        name: 'Legacy box',
        createdAt: '2026-09-15T12:00:00.000Z',
      },
    ],
    items: [
      {
        id: 1,
        name: 'Winter gloves',
        sourceLabel: 'manual-smoke',
        confidence: 1,
        boxId: 1,
        createdAt: '2026-09-15T12:01:00.000Z',
      },
    ],
  }),
);
location.reload();
```

Open inventory and boxes. Verify `Legacy box` becomes `BOX-000001`, gets a QR, and still contains `Winter gloves`.

Inspect the migrated value:

```js
JSON.parse(localStorage.getItem('rechibox.inventory.v0.1'))
```

Reload the browser and inspect again. The same box should keep the same 32-character lowercase hexadecimal `publicId`, `BOX-000001`, QR, and item assignment.

## 4. Verify QR scanning entirely on the computer with Android Emulator + Device Hub

Expo Device Hub can feed a PNG into an Android emulator camera. This makes it possible to exercise the scanner without a physical phone.

Boot an Android emulator and start Rechibox from the feature branch:

```sh
npm start
```

Press `a` in the Expo terminal. In the app:

1. tap the inventory button in the home header;
2. open `Мої коробки`;
3. create `QR smoke box`;
4. open that box and leave its QR visible.

Capture the emulator screen while the QR is visible:

```sh
adb exec-out screencap -p > /tmp/rechibox-box-qr.png
file /tmp/rechibox-box-qr.png
```

Open the Expo Device Hub URL printed by `npm start`, select the Android emulator, open the inspector's Camera section, and feed `/tmp/rechibox-box-qr.png` to the emulator camera.

Return to Rechibox and open `Сканувати QR коробки`. The scanner should read the QR from the injected camera image and open `QR smoke box`.

Also test recovery:

- leave the scanner screen and return;
- background/foreground the emulator app;
- feed a PNG containing a non-Rechibox QR and verify the retry state;
- if the camera mount is forced to fail, `Сканувати ще раз` should remount the camera instead of leaving the screen stuck.

## 5. Verify config-plugin behavior with a local Android native build

Expo Go proves the JavaScript scanning flow, but `barcodeScannerEnabled` is a native/config-plugin setting. Build the product-specific Android app locally into the emulator:

```sh
npm run android:native
```

This uses `expo run:android`; it is a local build and does not use EAS Build or GitHub Actions. Generated `android/` output is ignored by the repository and is not the configuration source of truth.

Once the product app is installed, repeat the Device Hub PNG camera test once. Confirm:

- the product app asks for camera permission;
- `Сканувати QR коробки` opens the camera;
- the injected QR resolves to the correct box;
- closing and reopening the product app preserves the same box identity and contents.

## 6. Optional physical-device confirmation

A physical phone is still the best final check for focus, exposure, damaged labels, and real-world scan distance, but it is not required for the computer-only functional smoke above.

For iPhone Expo Go:

```sh
npm run iphone
```

For the product-specific iPhone build:

```sh
npm run iphone:native
```

## Acceptance result

The slice is ready to merge when:

- static checks report no unexpected regressions;
- the native v2 SQLite fixture survives v3 migration with its item assignment intact;
- the web legacy fixture survives its in-place migration;
- box code and QR identity remain stable across restarts/reloads;
- Android Emulator + Device Hub successfully scans the injected Rechibox QR;
- scanner recovery does not leave the camera stuck;
- the local product-specific Android build applies the camera config and repeats the successful scan.
