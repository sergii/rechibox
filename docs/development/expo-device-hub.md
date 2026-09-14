# Expo Device Hub

Rechibox uses Expo Device Hub as an installed Expo DevTools plugin for local iOS Simulator and Android Emulator development.

The project is on Expo SDK 57, which satisfies the Device Hub requirement.

## Integrated mode

Install project dependencies as usual:

```sh
npm ci
```

Then start Expo:

```sh
npm start
```

Because `expo-device-hub` is installed in the project dependency graph, Expo registers it automatically as a DevTools plugin. Metro prints a local Device Hub URL similar to:

```text
http://localhost:8081/_expo/plugins/expo-device-hub
```

Use that browser dashboard to stream and control available iOS simulators and Android emulators, including tap, swipe, scroll, typing, boot/shutdown, and appearance changes.

## Standalone mode

The installed package also exposes its standalone CLI:

```sh
npm run device:hub
```

This uses the repository-pinned package rather than downloading a fresh copy through `npx`.

## Requirements

- iOS: macOS with Xcode and an installed Simulator runtime.
- Android: Android SDK with `emulator` and `adb` available.

Device Hub is local development tooling. Adding it does not require an EAS build, native app build, or OTA publish.
