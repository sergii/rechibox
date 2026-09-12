# Expo HAS CHANGED

Read the exact versioned docs at https://docs.expo.dev/versions/v57.0.0/ before writing version-sensitive Expo code.

# Rechibox mobile engineering contract

Use the Mobile Engineering Playbook as the shared React Native / Expo engineering baseline.

Playbook repository: https://github.com/sergii/mobile-engineering-playbook
Playbook version: v0.4.4
Playbook revision: 4901486d9373c5b895bf466d9438eec9b08b89ed

The revision is the reproducible baseline. Read shared guidance at that revision, not silently at `main`, and upgrade deliberately.

## Product context

Rechibox is a self-storage / smart-storage product for the Ukrainian market.

Target platforms: iOS, Android
Native ownership: CNG / Prebuild

The `/inventory` workflow uses the `camera-operational` archetype as task-scoped guidance. It is not the archetype for the whole product.

## Baseline and commands

Expo SDK 57, Expo Router, React Native 0.86.3, React 19.2.3, strict TypeScript, New Architecture.

Use Node 22.23.1 (`.nvmrc`) and npm 10.9.8 (`packageManager`). Keep `package-lock.json` authoritative.

```text
install: npm ci
start: npm start
typecheck: npm run typecheck
lint: npm run lint
ios simulator / Expo Go: npm run ios
native iOS Simulator product build: npm run simulator:ios
clean native iOS Simulator rebuild: npm run simulator:ios:clean
agent tooling setup: npm run agent:setup
agent tooling diagnostics: npm run agent:doctor
physical-device diagnostics: npm run device:check
physical iPhone / Expo Go: npm run iphone
physical iPhone native dev build: npm run iphone:native
physical iPhone standalone Release: npm run iphone:release
web: npm run web
EAS readiness: npm run eas:check
```

`ios`, `android`, and `iphone` use Expo Go and cannot exercise product-specific native modules such as React Native ExecuTorch. Use `simulator:ios` for the preferred native day-to-day loop and `iphone:native`/`iphone:release` for physical-device validation.

The native Simulator loop does not require an Apple Developer Program membership. Cloud/internal iOS distribution can require paid Apple signing capabilities, so do not make day-to-day verification depend on EAS iOS builds.

See `docs/agentic-mobile-testing.md` for the current verification strategy.

## Always follow

- Product-specific rules here and current task requirements override generic playbook examples.
- Preserve Expo-supported dependency alignment and consult SDK 57 docs for version-sensitive behavior.
- Keep generated `ios/` and `android/` ignored. `app.json` and config plugins are the native source of truth.
- Never commit certificates, provisioning profiles, Apple credentials, device IDs, access tokens, keychain material, or machine-specific signing state.
- Keep code comments in English.
- Prefer the smallest verification layer that can falsify the change, then escalate when native behavior matters.

## Relevant shared playbook guidance

Load only what the task needs:

- architecture/startup decisions -> `MOBILE_ENGINEERING_PLAYBOOK.md`
- dependencies -> `guides/decision-ladder.md`
- agent-generated overbuilding -> `guides/agent-failure-modes.md`
- native config, storage, safe areas, keyboard, OTA/native compatibility, lifecycle -> `guides/platform-native-rules.md`
- finishing a meaningful feature slice -> `guides/vertical-slice-checklist.md`
- explicitly selected archetype -> its README/YAML/slices

## Product-specific rules

- `/` remains the lightweight customer entry point. Grow behavior through thin vertical slices; do not add infrastructure ahead of demonstrated needs.
- Shared UI primitives are source-owned AniUI/Uniwind components under `src/components/ui`. Domain-specific camera/viewfinder/detection layout may use React Native primitives and `StyleSheet` where that is clearer.
- Do not casually add state/query/persistence/analytics frameworks. Add dependencies only for a concrete requirement.
- Keep safe-area ownership explicit. Headerless screens own the required edges; routed screens with a native stack header should not double-apply top insets.
- Native identity is display name `Rechibox`, slug `rechibox`, scheme `rechibox`, iOS bundle identifier `com.sergii.rechibox`, Android package `com.sergii.rechibox`.
- `expo-camera` owns capture for `/inventory`. Audio recording and barcode scanning are not part of the current inventory slice.
- Only mount the live camera while needed and while the app is active. Model permission denied, camera mount failure, capture failure, model download failure, inference failure, and retry states explicitly.
- `/inventory` performs real local object detection. The current detector is `YOLO26 XLARGE 640 · XNNPACK FP32` through `react-native-executorch`, with Skia used to obtain image pixels. Do not describe this path as a mock.
- Recognition is local. Do not claim image upload or backend persistence unless those behaviors are actually implemented.
- COCO object detection is closed-vocabulary. A miss for an object outside the model vocabulary is not automatically a UI bug. Keep detector quality evaluation separate from interaction correctness.
- Recognition confidence, include/exclude, correction, and confirmation are part of the inventory interaction. Persisted inventory/backend semantics remain separate product work.
- The first model use may download model assets. Distinguish model download latency from inference latency in diagnostics.

## Agentic verification policy

The preferred development loop is native iOS Simulator + Argent. Buoy Simulator Camera may provide deterministic image/video input to `expo-camera` without product code changes.

When Argent is configured, agents should use it to inspect the running app, act through semantic/accessibility targets, collect screenshots, and inspect logs/network evidence. Do not add brittle `testID` values merely to satisfy automation when stable accessibility semantics already identify the element.

Use this verification order when applicable:

1. `npm run typecheck` and `npm run lint`.
2. `npm run simulator:ios` for native UI/integration changes.
3. Use Argent to exercise and inspect the changed flow.
4. For camera flows, use a deterministic Buoy image/video fixture when available.
5. Use a physical iPhone for final real-camera behavior, signing/device-only behavior, and performance/thermal/hardware-acceleration validation.

Simulator timing is not a proxy for iPhone performance, CoreML/ANE behavior, thermals, memory pressure, or real optical camera behavior. State verification limits explicitly.

`agent-device` is an optional secondary agent QA/evidence tool. Maestro may be added later for a small number of durable smoke/regression flows. Avoid building a large selector-heavy E2E suite during rapid UI iteration.

For web-compatible UI/content work, React Native Web + Storybook + Playwright/MSW is the preferred future fast layer, but it should not be introduced until a concrete slice needs it.
