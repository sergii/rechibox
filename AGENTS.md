# Expo HAS CHANGED

Read the exact versioned docs at https://docs.expo.dev/versions/v57.0.0/ before writing any code.

# Rechibox mobile engineering contract

Use the Mobile Engineering Playbook as the shared React Native / Expo engineering baseline.

Playbook repository: https://github.com/sergii/mobile-engineering-playbook
Playbook version: v0.4.3
Playbook revision: c202f19cba00a33f2c933c0b653a8e99d8686e24

The exact revision is the reproducible baseline; the version is the human-readable release label. Read shared documents at that revision, never silently at `main`. Upgrade deliberately after reviewing the changes. Prefer a local checkout when its revision is verified.

This contract merges the [product template at the adopted revision](https://github.com/sergii/mobile-engineering-playbook/blob/c202f19cba00a33f2c933c0b653a8e99d8686e24/templates/product/AGENTS.md) with the Expo-generated instructions above.

## Product context

Rechibox is a self-storage / smart-storage product for the Ukrainian market.

Archetype: none
Target platforms: iOS, Android
Native ownership: CNG / Prebuild

Future camera/inventory workflows do not select `camera-operational` for the whole product. An archetype requires an explicit product decision.

## Project baseline and commands

Generated with `npx create-expo-app@latest .` using the default SDK 57 template, Expo Router, React Native 0.86.3, React 19.2.3, and strict TypeScript. Preserve Expo-supported version alignment and the New Architecture.

Use Node 22.23.1 (`.nvmrc`) and npm 10.9.8 (`package.json`'s `packageManager`), the verified bootstrap toolchain. create-expo-app 4.0.0 is incompatible with npm 12's `npm pack --json` output format. Keep `package-lock.json` as the dependency lockfile.

```text
install: npm ci
start: npm start
typecheck: npm run typecheck
lint: npm run lint
test: none (no automated test suite yet)
ios: npm run ios
android: npm run android
web: npm run web (optional preview, not a product target)
dependency compatibility: npx expo install --check
project diagnostics: npx expo-doctor
```

`ios` and `android` start Metro and open Expo Go; they do not build a native binary. Use a development build when product-specific native capabilities need verification. Do not generate app identifiers to make a native build proceed.

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

- Start with a minimal walking skeleton: `/` renders the Rechibox home screen. Use Ukrainian for initial user-facing copy.
- Use React Native primitives and `StyleSheet`. Keep files close to the implemented behavior; do not add speculative feature folders or layers.
- Add UI frameworks, styling systems, state/query libraries, persistence, auth, analytics, animations, or other infrastructure only for a concrete requirement.
- Check dependency and peer-dependency requirements before cleanup. SDK 57's Router brings `@expo/ui`, glass/symbol helpers, and drawer/gesture/animation dependencies transitively; their installation is not adoption of their APIs by this product.
- The headerless home screen owns all four safe-area edges through `react-native-safe-area-context`; Expo Router provides the safe-area context. Do not add a duplicate provider or navigator inset. Keep text scalable and system bars legible in light and dark appearance.
- `app.json` and config plugins are the native source of truth. Keep generated `ios/` and `android/` out of source control; do not leave persistent changes only in generated native files.
- Safe identity is display name `Rechibox`, slug `rechibox`, scheme `rechibox`. Apple bundle ID, Android package ID, production domain/API URL, EAS project ID, and signing configuration remain unset until provided.
- Expo icons/splash assets remain development placeholders. Branded assets, release policy, backend contracts, accounts, storage, and camera workflows are deferred.
- Keep code comments in English. Do not infer booking/resource models or claim offline synchronization before product requirements define them.
- Run strict TypeScript, lint, and relevant Expo checks. Inspect the running app on targeted platforms and state verification limits honestly. Expo Go does not verify native identity, custom-scheme registration, config-plugin output, signing, or release behavior.
