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

The `/inventory` camera workflow explicitly uses the `camera-operational` archetype as task-scoped guidance only. It does not select that archetype for the whole product.

## Project baseline and commands

Generated with `npx create-expo-app@latest .` using the default SDK 57 template, Expo Router, React Native 0.86.3, React 19.2.3, and strict TypeScript. Preserve Expo-supported version alignment and the New Architecture.

Use Node 22.23.1 (`.nvmrc`) and npm 10.9.8 (`package.json`'s `packageManager`), the verified bootstrap toolchain. create-expo-app 4.0.0 is incompatible with npm 12's `npm pack --json` output format. Keep `package-lock.json` as the dependency lockfile.

```text
install: npm ci
start: npm start
typecheck: npm run typecheck
lint: npm run lint
test: no broad automated suite yet
one-command local mobile verification: npm run verify:mobile
ios simulator / Expo Go: npm run ios
android emulator / Expo Go: npm run android
physical-device diagnostics: npm run device:check
physical iPhone / Expo Go: npm run iphone
physical iPhone native build: npm run iphone:native
agent project status: npm run agent:status
agent Expo diagnostics: npm run agent:doctor
agent iOS smoke: npm run agent:smoke:ios
agent Android smoke: npm run agent:smoke:android
web: npm run web (optional preview, not a product target)
dependency compatibility: npx expo install --check
project diagnostics: npx expo-doctor
```

`ios`, `android`, and `iphone` use Expo Go and do not build a product-specific native binary. `iphone:native` uses CNG plus `expo run:ios --device`; it may generate ignored `ios/` output locally, build with Xcode, install the app on a physical device, and verify native/config-plugin behavior. Local Apple signing credentials remain machine-local and must not be committed.

`npm run verify:mobile` is the preferred one-command local iOS UI gate. It runs TypeScript, lint, a pinned `@expo/agent-cli` local iOS smoke/navigation pass, and the deterministic `agent-device` replay under `tests/mobile/replays/`. It must remain local-only and must not silently opt into EAS or billed cloud macOS capacity. Generated verification artifacts stay under `.git/rechibox-agent-artifacts/` so the working tree remains clean.

The lower-level `agent:*` commands use a pinned experimental `@expo/agent-cli` version as the Expo-aware project/runtime layer. For meaningful user-visible changes, use `agent-device` when it is available on the development host to inspect and drive the real native UI through semantic/accessibility state and to capture reviewable evidence. `agent-device` is developer-host tooling, not a Rechibox runtime dependency. Read `docs/development/mobile-agent-harness.md` before expanding the automation stack.

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
- `expo-camera` is the product-owned camera dependency for the `/inventory` slice. The camera config plugin owns the product camera permission string; audio recording and barcode scanning are not part of this slice.
- Only mount the live camera while the inventory flow needs it and the application is active. Re-check camera permission after returning to the foreground, and model denied permission, camera mount failure, capture failure, and retry states explicitly.
- Inventory recognition is real on-device inference through `react-native-executorch` using the configured YOLO26 model. The captured photo is not uploaded to a Rechibox backend. Model assets may require a first-run download, so represent model readiness and failure states honestly.
- Recognition confidence and low-confidence correction remain part of the inventory interaction. User confirmation persists accepted items locally in `expo-sqlite`; it does not imply backend synchronization.
- Local inventory persistence is an implemented product capability. Physical inventory boxes/containers may be persisted locally and linked to inventory items. Keep schema migrations explicit and preserve existing local data across upgrades.
- Backend inventory sync, accounts, cross-device/offline synchronization, production API contracts, and release policy remain deferred until explicitly implemented.
- Expo icons/splash assets remain development placeholders.
- Keep code comments in English. Do not infer booking/resource models or claim backend/offline synchronization before product requirements define them.
- Run strict TypeScript, lint, and relevant Expo checks. Inspect the running app on targeted platforms and state verification limits honestly. Camera-critical behavior should be exercised on a physical device. Expo Go can verify the JavaScript camera flow; use the native physical-device runner when config-plugin/native behavior matters.
- For ordinary meaningful UI/interaction changes, run `npm run verify:mobile` as the default local iOS verification gate. Drop to lower-level `agent:*` or `agent-device` commands only to diagnose failures or author new replay coverage. A screenshot alone is not sufficient evidence for an interactive change.
