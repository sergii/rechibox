# Rechibox

A self-storage / smart-storage mobile product for the Ukrainian market.

The repository currently contains two thin product slices:

- storage selection: `/` → local mock storage options → details → local confirmation result;
- AI inventory: `/` → camera permission → live camera → capture → preview → explicitly mocked recognition → confidence/correction → local confirmation result.

Both slices use React Native primitives and `StyleSheet`. Booking and inventory confirmation are demonstrations only; they do not create backend records or persistent local state.

## Engineering baseline

- Playbook version: **v0.4.4**
- Playbook revision: **4901486d9373c5b895bf466d9438eec9b08b89ed**
- [Shared playbook at the adopted revision](https://github.com/sergii/mobile-engineering-playbook/tree/4901486d9373c5b895bf466d9438eec9b08b89ed)
- Archetype: **none** globally
- AI inventory task guidance: **camera-operational**
- Target platforms: **iOS, Android**
- Native ownership: **CNG / Prebuild**

The merged [AGENTS.md](AGENTS.md) contains the product contract and preserves Expo's generated SDK-specific instructions. Shared guidance is read at the pinned commit, not a moving branch. The camera-operational archetype is scoped only to the `/inventory` workflow and is not a global application archetype.

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
| `npm run device:check` | Show available physical Apple/Android devices without starting Metro |
| `npm run iphone` | Start an Expo Go LAN QR flow for a physical iPhone/iPad |
| `npm run iphone:native` | Build, install, and launch a native development build on an available physical iPhone/iPad |
| `npm run web` | Optional browser preview inherited from Expo; web is not a product target |
| `npm run typecheck` | Run strict TypeScript without emitting files |
| `npm run lint` | Run Expo's ESLint configuration |
| `npx expo install --check` | Check SDK dependency compatibility |
| `npx expo-doctor` | Check Expo project health |

`npm run iphone` is the fastest physical-device loop and uses Expo Go over the network. `npm run iphone:native` uses CNG and `expo run:ios --device`: it may generate `ios/` locally, build with Xcode, install the Rechibox binary on the selected physical device, and start Metro. Generated native directories remain ignored; `app.json` and config plugins remain the source of truth.

The native development build is the relevant verification path for product-specific native configuration such as the Rechibox camera permission string. Local Apple signing credentials are not committed to the repository; Xcode uses the developer account/certificate available on the machine.

## Native identity

The selected application identifiers are:

```text
iOS bundle identifier: com.sergii.rechibox
Android package:       com.sergii.rechibox
```

Changing either identifier is a product/release decision because it changes native application identity. The production domain/API URL, EAS project ID, store records, and release signing/distribution policy remain separate decisions.

## Project structure

```text
src/app/
  _layout.tsx          Router stack, system appearance, status bar
  index.tsx            / home screen and product-slice entry points
  inventory.tsx        /inventory camera + mock AI recognition flow
  storage/index.tsx    /storage mock option selection
  storage/[id].tsx     /storage/[id] details and local result state
src/inventory/
  mock-recognition.ts  Fixed local recognition fixtures and mock disclosure
src/storage/
  mock-options.ts       Clearly labeled local fixtures for the storage slice
src/components/
  RechiboxLogo.tsx     Branded SVG logo component
bin/
  run-on-real-device   Physical-device diagnostics + Expo Go runner
  run-native-iphone    Physical iPhone native build/install runner
assets/
  expo.icon/           Generated iOS icon placeholder
  images/              Generated app icon, splash, and favicon placeholders
app.json               Reversible identity and native/config-plugin configuration
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

`ios/` and `android/` are generated output and remain ignored. Native configuration belongs in app config/config plugins. The home screen owns all four safe-area edges because the stack header is hidden; routed screens with a stack header own the remaining edges. Text retains platform scaling and scrolls where space is limited.

## Direct dependencies

| Packages | Current purpose |
| --- | --- |
| `expo`, `react`, `react-native` | Expo and React Native runtime |
| `expo-router`, `expo-constants`, `expo-linking`, `react-native-screens` | File routing and its native/runtime requirements |
| `expo-camera` | Live camera preview and photo capture for `/inventory` |
| `react-native-svg` | Rechibox SVG logo rendering |
| `react-native-safe-area-context` | Safe-area insets |
| `expo-status-bar`, `expo-system-ui` | Status-bar contrast and native appearance support |
| `expo-splash-screen` | Generated splash configuration retained for CNG |
| `react-dom`, `react-native-web` | Generated optional web preview |
| `typescript`, `@types/react` (development) | Strict type checking |
| `eslint`, `eslint-config-expo` (development) | Make the generated `expo lint` command runnable |

`react-native-svg` and `expo-camera` are deliberate product-owned runtime dependencies. Ten demo-only direct declarations were removed after checking Expo/Router dependencies. SDK 57's Router still installs `@expo/ui`, glass/symbol helpers, and drawer/gesture/Reanimated dependencies transitively; Rechibox does not import their APIs. Keep Expo's required graph intact. `npm ls` distinguishes these from product-owned dependencies.

## AI inventory slice

The current interaction shape is:

```text
Home
→ AI inventory
→ camera permission
→ live camera
→ capture
→ photo preview / retake
→ mock recognition
→ confidence + correction
→ local confirmation result
```

The camera is real. Recognition is not: the result is a fixed local fixture, independent of the captured photo. The UI explicitly says that the photo is not uploaded and is not actually analyzed by AI. The slice exists to validate the camera/permission/preview/uncertainty/correction interaction before a model or backend contract is selected.

The live `CameraView` is mounted only while the camera stage is active and the application is in the foreground. Camera permission is re-checked after returning to the foreground. Denied permission, camera mount failure, capture failure, low-confidence recognition, correction, exclusion, and retry are explicit UI states. Confirmation is local screen state only, so there is no server-side duplicate-operation or idempotency behavior yet.

The config plugin disables Android audio recording permission and barcode-scanner support because this slice captures still images only. A future barcode/QR workflow should be added because a product requirement needs it, not because `expo-camera` can scan codes.

## Deferred decisions

Display name **Rechibox**, slug **rechibox**, URL scheme **rechibox**, iOS bundle identifier **com.sergii.rechibox**, and Android package **com.sergii.rechibox** are configured. Production domain/API URL, EAS project ID, App Store / Play Store records, and release signing/distribution policy remain unset.

Backend, accounts/authentication, real booking, real AI recognition/model selection, image upload/storage, persistent inventory, offline sync, state/query libraries, UI frameworks, analytics, and build/release/OTA policies await concrete product requirements. The storage slice uses fictional local fixtures. The AI inventory slice uses a captured cache image plus fixed recognition fixtures and local React state only. There is no automated test suite yet; the app is checked with TypeScript, lint, Expo diagnostics, and runtime inspection.

## Bootstrap verification

Verified on 2026-09-12:

- `npm run typecheck`, `npm run lint`, and `git diff --check` passed.
- `npx expo install --check` reported compatible dependencies; `npx expo-doctor` passed all 21 checks.
- At bootstrap, before native product identifiers were selected, `npx expo config --type public` confirmed the safe display identity and absence of bundle/package IDs, production endpoints, and EAS project configuration.
- Expo Go loaded the home route on an iPhone 17 Pro simulator (iOS 26.5) and the existing Pixel 8 Android emulator. Both native Metro bundles succeeded. The home text was verified through accessibility inspection and screenshots in light and dark appearance, including status bars and safe-area layout. Expo's floating developer button is runtime UI, not part of Rechibox.

This bootstrap verification covered the JavaScript app in Expo Go. Store signing, distribution, release behavior, and production native assets remain unverified.

## Storage slice verification

Verified on 2026-09-12 in Expo Go:

- iPhone 17 Pro simulator: Home → options → available selection → details → confirmation/result → choose another option. The unavailable option remained disabled; invalid `/storage/does-not-exist` showed its recovery state; details back navigation and list-to-home back navigation worked. Light and dark screenshots showed readable content, correct status-bar/safe-area spacing, and reachable primary buttons.
- Pixel 8 Android emulator: the same selection, confirmation/result, choose-another, and alternate selection flow worked. Accessibility inspection confirmed the unavailable option stayed disabled and unselected; the invalid deep link showed recovery and returned to options; system back from details returned to options. Light and dark screenshots showed readable content, correct status-bar/bottom-inset spacing, and reachable primary buttons.
- No product behavior or application code changes were needed for this verification pass.

## AI inventory verification status

Implementation is committed, but the completed camera slice has not yet been runtime-verified after the code change. Verification should include a physical device because camera-critical behavior is material. `npm run iphone:native` now provides the native iOS path needed to verify config-plugin output as well as the JavaScript flow.

Verify:

- permission grant, denial, and return from system settings;
- camera ready, capture, preview, and retake;
- app background → foreground while the camera stage is open;
- mock recognition disclosure, confidence display, low-confidence correction, exclusion, and local confirmation;
- keyboard reachability while editing item names;
- light/dark appearance, safe areas, and back navigation on iOS and Android;
- `npm run typecheck`, `npm run lint`, `npx expo install --check`, `npx expo-doctor`, and `git diff --check`.

The generated dependency graph reported 14 moderate npm audit findings during installation before this slice. No forced dependency upgrades were applied. Expo Doctor compatibility checks are not a security audit.
