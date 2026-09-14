# Expo Device Hub

Rechibox can use Expo Device Hub as a local simulator/emulator control surface.

## Run

```sh
npm run device:hub
```

The script pins `expo-device-hub` to `0.10.1` and runs it in standalone mode through `npx`. This keeps the app dependency graph and `package-lock.json` unchanged while giving local access to the browser-based device dashboard.

The Hub can stream and control iOS simulators and Android emulators, including tap, swipe, scroll, typing, boot/shutdown, and appearance changes.

Requirements:

- iOS: macOS with Xcode and an installed Simulator runtime.
- Android: Android SDK with `emulator` and `adb` available.

## Integrated Expo DevTools mode

Expo Device Hub also supports registration as an Expo DevTools plugin when installed into the app:

```sh
npx expo install expo-device-hub
npm start
```

Do not install it into the project dependency graph casually. If we adopt integrated mode, commit the resulting `package.json` and `package-lock.json` changes together and verify Expo SDK compatibility.

For now, standalone mode is deliberate: it provides the useful local dashboard without changing production/runtime dependencies or triggering EAS work.
