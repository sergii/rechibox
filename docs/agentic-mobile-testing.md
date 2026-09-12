# Agentic mobile testing loop

Rechibox should not require a physical iPhone for most UI, interaction, and camera-flow iteration. The preferred development loop is a native iOS Simulator build controlled by an agent, with deterministic camera input where useful.

## Verification layers

Use the cheapest layer that can falsify the change.

1. TypeScript/lint for static correctness.
2. React Native Web/Storybook/Playwright for future component and content-state coverage where native behavior is not required.
3. Native iOS Simulator for the primary day-to-day product loop.
4. Physical iPhone only for device-only behavior, final camera validation, signing/provisioning, thermal/performance checks, and Apple hardware acceleration behavior.

The Simulator layer is intentionally first-class. It renders the real React Native/Fabric app and can exercise the native Expo modules that support Simulator builds without requiring an Apple Developer Program membership.

On 2026-09-12 the Rechibox Simulator PoC reached the full inventory path through `expo-camera` capture, Skia pixel extraction, React Native ExecuTorch model loading/inference, and the review screen. Simulator performance is not an iPhone performance result.

## Primary stack

### Argent

Argent is the preferred agent control/debug layer for Rechibox. It can drive a running iOS Simulator app and expose screenshots, accessibility/component information, logs, network state, React inspection, and profiling to a coding agent.

Set it up once on a development machine:

```bash
npm run agent:setup
```

Check the local toolchain with:

```bash
npm run agent:doctor
```

Argent is intentionally not a runtime dependency of the product. The setup command configures the developer/agent environment instead of shipping agent tooling inside the app.

Canonical docs: https://docs.swmansion.com/argent/ and https://docs.expo.dev/agents/argent/

### Buoy Simulator Camera

Buoy can provide an AVFoundation camera to the iOS Simulator without changing Rechibox source code. `expo-camera` is a verified integration.

For manual development, open Buoy Desktop, select the iOS Simulator Camera, choose an Image/Video/Mac camera/Test pattern source, then launch Rechibox. The camera attaches when the app process starts, so relaunch the app after enabling the source. Switching the source after attachment is live.

When the `buoycam` CLI is available, the deterministic inventory flow configures an image source automatically before Argent launches the app.

Buoy's basic Simulator camera is external to the app and requires no npm package or config plugin. Agent control of Buoy itself over MCP is a separate paid capability and is not required for the CLI-based flow below.

Canonical docs: https://buoy.gg/buoy/latest/docs/tools/camera

### agent-device and Maestro

Do not install additional native automation frameworks by default.

- `agent-device` is a good secondary option for evidence-oriented agent QA and broad device automation.
- Maestro is a good later layer for a small number of durable smoke/regression flows.
- Avoid a large brittle selector suite. Prefer accessibility semantics and user-visible behavior; add stable test IDs only when semantic targeting cannot express the interaction reliably.

## Running Rechibox on the Simulator

Normal native Simulator build:

```bash
npm run simulator:ios
```

Force regeneration of ignored native iOS output after a native dependency/config-plugin change:

```bash
npm run simulator:ios:clean
```

The runner opens Simulator.app when needed, generates native state with CNG when required, installs Pods with the repository's Ruby-compatible CocoaPods path, then delegates build/install/Metro to Expo. Keep the terminal alive for Metro and Fast Refresh.

Once the native binary exists, JavaScript/TypeScript/UI changes should normally iterate through Fast Refresh without another native compile. Rebuild only when the native runtime changes.

## Deterministic inventory camera flow

The committed Argent flow is `.argent/flows/inventory-camera.yaml`. It launches `com.sergii.rechibox`, navigates from the home screen into AI inventory, captures the Buoy camera image, waits for the local model to be ready, runs YOLO, waits for the review screen, and performs a visual snapshot check.

The first run creates a reviewed baseline:

```bash
npm run agent:inventory:baseline -- /path/to/household-fixture.jpg
```

After reviewing the generated baseline under `.argent/flows/__baselines__/inventory-camera/`, replay the same fixture with:

```bash
npm run agent:inventory:test -- /path/to/household-fixture.jpg
```

The wrapper requires a booted iPhone Simulator, an already installed Rechibox native Simulator build, Argent, and `buoycam`. It runs `buoycam source image <fixture>` before Argent restarts Rechibox because camera injection is attached at process start. Argent pins the visual run and compares the final `inventory-review` snapshot. Failure artifacts go to `.argent/artifacts/` and are ignored by git.

This flow intentionally validates the integration path and the visible review state. It does not assert that YOLO's labels are semantically correct for every fixture. Detector-quality expectations should be recorded separately from UI regression expectations.

## Camera fixtures

Store only non-sensitive, deterministic test images under `test/fixtures/camera/`, or pass an external local path to the fixture runner.

Recommended first fixture set:

- one object centered
- several household objects with overlap
- cluttered room/box
- low light
- small objects far from camera
- objects outside the detector's COCO vocabulary
- intentionally empty scene

Fixtures are test evidence, not training data. Record the expected recognition behavior separately instead of silently tuning the fixture to the current detector.

## Inventory recognition boundary

The current `/inventory` flow performs real local inference with React Native ExecuTorch using YOLO26 XLARGE 640 on XNNPACK. Camera capture, Skia pixel extraction, model inference, review/edit state, and confirmation are distinct concerns.

For UI-only tests, recognition results may later be injected as fixtures at the boundary after inference. Do not mock the model inside production code just to make tests convenient.

For camera/inference integration, prefer Simulator + Buoy first. Keep physical-device validation as the source of truth for actual iPhone camera behavior and performance. Simulator timing is not a proxy for iPhone latency, CoreML/ANE behavior, thermals, or memory pressure.

## Agent verification contract

After changing visible behavior, an agent should prefer this sequence when the required tools are available:

1. Run typecheck and lint.
2. Launch or reuse the native iOS Simulator build.
3. Use Argent to inspect the current screen before acting.
4. Exercise the changed flow through semantic/accessibility targets.
5. Capture a screenshot and relevant logs/network evidence.
6. If camera input matters, replay a deterministic Buoy fixture.
7. Report what was actually verified and what remains device-only.

Do not claim a change is verified merely because the app compiled.
