# Expo HAS CHANGED

Read the exact versioned docs at https://docs.expo.dev/versions/v57.0.0/ before writing any code.

# Rechibox mobile engineering contract

Use the Mobile Engineering Playbook as the shared React Native / Expo engineering baseline.

Playbook repository: https://github.com/sergii/mobile-engineering-playbook
Playbook version: v0.4.4
Playbook revision: 4901486d9373c5b895bf466d9438eec9b08b89ed

The exact revision is the reproducible baseline; the version is the human-readable release label. Read shared documents at that revision, never silently at `main`. Upgrade deliberately after reviewing the changes. Prefer a local checkout when its revision is verified.

This contract merges the [product template at the adopted revision](https://github.com/sergii/mobile-engineering-playbook/blob/4901486d9373c5b895bf466d9438eec9b08b89ed/templates/product/AGENTS.md) with the Expo-generated instructions above.

## Product context

Rechibox is a self-storage / smart-storage product for the Ukrainian market.

Archetype: none
Target platforms: iOS, Android
Native ownership: CNG / Prebuild

The `/inventory` and `/box-scan` camera workflows explicitly use the `camera-operational` archetype as task-scoped guidance only. They do not select that archetype for the whole product.

## Project baseline and commands

Generated with `npx create-expo-app@latest .` using the default SDK 57 template, Expo Router, React Native 0.86.3, React 19.2.3, and strict TypeScript. Preserve Expo-supported version alignment and the New Architecture.

Use Node 22.23.1 (`.nvmrc`) and npm 10.9.8 (`package.json`'s `packageManager`), the verified bootstrap toolchain. create-expo-app 4.0.0 is incompatible with npm 12's `npm pack --json` output format. Keep `package-lock.json` as the dependency lockfile.

```text
install: npm ci
start: npm start
typecheck: npm run typecheck
lint: npm run lint
test: none (no automated test suite yet)
ios simulator / Expo Go: npm run ios
android emulator / Expo Go: npm run android
android emulator native build: npm run android:native
physical-device diagnostics: npm run device:check
physical iPhone / Expo Go: npm run iphone
physical iPhone native build: npm run iphone:native
web: npm run web (optional preview, not a product target)
dependency compatibility: npx expo install --check
project diagnostics: npx expo-doctor
```

`ios`, `android`, and `iphone` use Expo Go and do not build a product-specific native binary. `android:native` uses CNG plus `expo run:android` against a connected emulator/device. `iphone:native` uses CNG plus `expo run:ios --device`; it may generate ignored `ios/` output locally, build with Xcode, install the app on a physical device, and verify native/config-plugin behavior. Generated native output remains ignored and must not become the configuration source of truth. Local signing credentials remain machine-local and must not be committed.

## Always follow

- The product-specific rules in this repository, current task requirements, and the shared playbook's core safety rules.
- Product-specific documented rules override generic shared examples.
- Preserve useful Expo-generated instructions and consult SDK 57 documentation for version-sensitive behavior.

## Load shared guidance only when relevant

All paths below refer to the playbook repository at the recorded revision:

- Architecture/startup/unfamiliar mobile decisions → `MOBILE_ENGINEERING_PLAYBOOK.md`.
- New or cross-cutting dependencies → `guides/decision-ladder.md`.
- Suspicious generated/overbuilt code → `guides/agent-failure-modes.md`.
- Native config, auth routing/security boundaries, storage, safe areas, keyboard, OTA/native compatibility, lifecycle-sensitive behavior, `ios/` or `android/` → `guides/platform-native-rules.md`.
- Finishing a meaningful feature slice → `guides/vertical-slice-checklist.md`.
- Explicitly selected archetype → its README/YAML/slices when relevant.

Do not load every shared document for every small task. Read product/domain documents when they exist and are relevant; do not invent missing domain contracts.

## Product-specific rules

- `/` remains the lightweight customer entry point. Grow product behavior through thin vertical slices, and do not add infrastructure ahead of demonstrated product needs.
- Use React Native primitives and `StyleSheet`. Keep files close to the implemented behavior; do not add speculative feature folders or layers.
- Add UI frameworks, styling systems, state/query libraries, persistence, auth, analytics, animations, or other infrastructure only for a concrete requirement.
- Check dependency and peer-dependency requirements before cleanup. SDK 57's Router brings `@expo/ui`, glass/symbol helpers, and drawer/gesture/animation dependencies transitively; their installation is not adoption of their APIs by this product.
- The headerless home screen owns all four safe-area edges through `react-native-safe-area-context`; Expo Router provides the safe-area context. Routed screens with a native stack header should own only the remaining safe-area edges. Keep text scalable and system bars legible in light and dark appearance.
- `app.json` and config plugins are the native source of truth. Keep generated `ios/` and `android/` out of source control; do not leave persistent changes only in generated native files.
- Native identity is display name `Rechibox`, slug `rechibox`, scheme `rechibox`, iOS bundle identifier `com.sergii.rechibox`, and Android package `com.sergii.rechibox`. Do not change bundle/package identifiers casually: changing them changes application identity. Production domain/API URL, EAS project ID, store records, and release signing/distribution policy remain unset until explicitly decided.
- Do not commit developer certificates, provisioning profiles, keychain data, Apple credentials, device IDs, or machine-specific Xcode signing state. Native development builds may use locally available Xcode automatic signing.
- `expo-camera` is the product-owned camera dependency for both `/inventory` photo capture and `/box-scan` QR scanning. The camera config plugin owns the product camera permission string. Audio recording remains disabled; QR is the only barcode format required by the current Box Identity slice.
- Only mount a live camera while the relevant camera flow needs it and the application is active. Re-check camera permission after returning to the foreground, and model denied permission, camera mount failure, capture/scan failure, and retry states explicitly.
- Inventory recognition is real on-device inference through `react-native-executorch` using the configured YOLO26 model. The captured photo is not uploaded to a Rechibox backend. Model assets may require a first-run download, so represent model readiness and failure states honestly.
- Recognition confidence and low-confidence correction remain part of the inventory interaction. User confirmation persists accepted items to the local inventory source of truth. The current World State integration may project that local inventory to the configured backend as a device-local snapshot, but it does not make the backend the canonical inventory store or provide cross-device synchronization.
- Local inventory persistence is an implemented product capability. Physical inventory boxes/containers may be persisted locally and linked to inventory items. Keep schema migrations explicit and preserve existing local data across upgrades.
- Box Identity separates human and machine identity. `BOX-000001`-style codes are human-facing labels derived from the local numeric row id; QR payloads use an opaque 128-bit `public_id` in the form `rechibox://box/<public_id>`. Do not use the display code as the machine identity or database key.
- `react-native-qrcode-svg` is the product-owned QR renderer for Box Identity and builds on the already-owned `react-native-svg` dependency. Keep scanning on `expo-camera` unless measured product requirements justify a different camera stack.
- Device-local inventory snapshot sync into World State is implemented and remains subordinate to local inventory. Accounts, cross-device/offline synchronization, backend QR resolution, production API contracts, and release policy remain deferred until explicitly implemented.
- Expo icons/splash assets remain development placeholders.
- Keep code comments in English. Do not infer booking/resource models or claim cross-device/backend-canonical inventory behavior before product requirements define it.
- Run strict TypeScript, lint, and relevant Expo checks. Inspect the running app on targeted platforms and state verification limits honestly. Camera-critical behavior should be exercised on a physical device or an emulator with a controlled camera feed. Expo Go can verify the JavaScript camera flow; use a product-specific native build when config-plugin/native behavior matters.
