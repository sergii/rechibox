# Rechibox

A self-storage / smart-storage mobile product for the Ukrainian market.

This repository contains the first thin customer flow: Expo Router resolves `/` to a Ukrainian home screen, which leads through clearly labeled local mock storage options, option details, and a local confirmation result. It uses React Native primitives and `StyleSheet`, with safe-area handling and system light/dark appearance. The confirmation is a demonstration only; it does not create or persist a reservation.

## Engineering baseline

- Playbook version: **v0.4.3**
- Playbook revision: **c202f19cba00a33f2c933c0b653a8e99d8686e24**
- [Shared playbook at the adopted revision](https://github.com/sergii/mobile-engineering-playbook/tree/c202f19cba00a33f2c933c0b653a8e99d8686e24)
- Archetype: **none**
- Target platforms: **iOS, Android**
- Native ownership: **CNG / Prebuild**

The merged [AGENTS.md](AGENTS.md) contains the product contract and preserves Expo's generated SDK-specific instructions. Shared guidance is read at the pinned commit, not a moving branch. Camera/inventory workflows do not select a global application archetype.

Bootstrapped with `npx create-expo-app@latest .` (create-expo-app 4.0.0, default template 57.0.24): Expo SDK 57, React Native 0.86.3, React 19.2.3, and strict TypeScript. [Expo's SDK 57 reference](https://docs.expo.dev/versions/v57.0.0/) describes the supported runtime versions.

## Run locally

Use Node **22.23.1** from `.nvmrc` and npm **10.9.8** from `package.json`'s `packageManager`, then:

```sh
nvm use
npm ci
npm start
```

The verified bootstrap toolchain is Node 22.23.1/npm 10.9.8. create-expo-app 4.0.0 is incompatible with npm 12's `npm pack --json` output format.

| Command | Purpose |
| --- | --- |
| `npm start` | Start Metro; press `i` or `a` to open a simulator/emulator |
| `npm run ios` | Start Metro and open Expo Go in the iOS simulator |
| `npm run android` | Start Metro and open Expo Go in the Android emulator |
| `npm run web` | Optional browser preview inherited from Expo; web is not a product target |
| `npm run typecheck` | Run strict TypeScript without emitting files |
| `npm run lint` | Run Expo's ESLint configuration |
| `npx expo install --check` | Check SDK dependency compatibility |
| `npx expo-doctor` | Check Expo project health |

The native run scripts use Expo Go and do not generate native projects. The current screen fits Expo Go's capabilities. Product-specific native configuration requires a development build once identifiers and relevant requirements are provided.

## Project structure

```text
src/app/
  _layout.tsx          Router stack, system appearance, status bar
  index.tsx            / home screen and its safe-area insets
  storage/index.tsx    /storage mock option selection
  storage/[id].tsx     /storage/[id] details and local result state
src/storage/
  mock-options.ts       Clearly labeled local fixtures for the slice
assets/
  expo.icon/           Generated iOS icon placeholder
  images/              Generated app icon, splash, and favicon placeholders
app.json               Reversible identity and native configuration
AGENTS.md              Product contract plus Expo instructions
CLAUDE.md              Generated reference to AGENTS.md
.claude/settings.json  Generated Expo agent integration
.vscode/               Generated Expo editor settings
.nvmrc                 Verified Node version
eslint.config.js       Expo lint configuration
tsconfig.json          Strict TypeScript and generated route types
package.json           Actual project commands and direct dependencies
package-lock.json      Reproducible npm dependency graph
```

`ios/` and `android/` are generated output and remain ignored. Native configuration belongs in app config/config plugins. The home screen owns all four safe-area edges because the stack header is hidden; Expo Router supplies the provider. Text retains platform scaling and can scroll when space is limited.

## Direct dependencies

| Packages | Current purpose |
| --- | --- |
| `expo`, `react`, `react-native` | Expo and React Native runtime |
| `expo-router`, `expo-constants`, `expo-linking`, `react-native-screens` | File routing and its native/runtime requirements |
| `react-native-safe-area-context` | Safe-area insets for the headerless home screen |
| `expo-status-bar`, `expo-system-ui` | Status-bar contrast and native appearance support |
| `expo-splash-screen` | Generated splash configuration retained for CNG |
| `react-dom`, `react-native-web` | Generated optional web preview |
| `typescript`, `@types/react` (development) | Strict type checking |
| `eslint`, `eslint-config-expo` (development) | Make the generated `expo lint` command runnable |

No runtime dependency was added beyond the generated template. Ten demo-only direct declarations were removed after checking Expo/Router dependencies. SDK 57's Router still installs `@expo/ui`, glass/symbol helpers, and drawer/gesture/Reanimated dependencies transitively; Rechibox does not import their APIs. Keep Expo's required graph intact. `npm ls` distinguishes these from product-owned dependencies.

## Deferred decisions

Only display name **Rechibox**, slug **rechibox**, and URL scheme **rechibox** are configured. Apple bundle identifier, Android package identifier, production domain/API URL, EAS project ID, and signing configuration are unset.

Backend, accounts/authentication, real booking/inventory behavior, camera permissions, persistence/offline sync, state/query libraries, UI frameworks, analytics, branding, and build/release/OTA policies await concrete product requirements. The slice uses local React state only; its sizes, prices, facility label, and availability are fictional fixtures rather than product rules. There is no automated test suite yet; the app is checked with TypeScript, lint, Expo diagnostics, and runtime inspection.

## Bootstrap verification

Verified on 2026-09-12:

- `npm run typecheck`, `npm run lint`, and `git diff --check` passed.
- `npx expo install --check` reported compatible dependencies; `npx expo-doctor` passed all 21 checks.
- `npx expo config --type public` confirmed the safe identity and absence of bundle/package IDs, production endpoints, and EAS project configuration.
- Expo Go loaded the home route on an iPhone 17 Pro simulator (iOS 26.5) and the existing Pixel 8 Android emulator. Both native Metro bundles succeeded. The home text was verified through accessibility inspection and screenshots in light and dark appearance, including status bars and safe-area layout. Expo's floating developer button is runtime UI, not part of Rechibox.

This verifies the JavaScript skeleton in Expo Go. A custom native binary, native registration of `rechibox://`, app icons/splash configuration, signing, store builds, physical devices, and release behavior have not been verified. Keyboard and business-workflow checks are not applicable to this screen.

The generated dependency graph reported 14 moderate npm audit findings during installation, also present before demo cleanup. No forced dependency upgrades were applied. Expo Doctor compatibility checks are not a security audit.
