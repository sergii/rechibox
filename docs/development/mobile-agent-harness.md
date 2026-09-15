# Mobile agent verification harness

Rechibox uses a layered mobile-agent workflow instead of treating every automation tool as interchangeable.

The current goal is simple: after an agent changes the app, it should be able to inspect the project, run the app, verify the real native UI, capture evidence, and turn useful exploratory flows into repeatable checks without adding a large E2E framework prematurely.

## Current stack

```text
coding agent
  -> @expo/agent-cli
       project/runtime status, dev loop, errors, tree, smoke
  -> agent-device
       real device/simulator inspection, interaction, evidence, replay
       local host OR existing native-sim cloud iOS path
  -> Expo Device Hub
       human-oriented local device dashboard
```

The tools are complementary:

- `@expo/agent-cli` is the Expo-aware project/runtime layer.
- `agent-device` is the device verification layer.
- `npm run cloud:ios` is the existing remote iOS smoke path. It provisions a macOS-hosted simulator through `native-sim`, exposes the simulator through the `agent-device` proxy, verifies an interactive snapshot, and tears the billed run down automatically unless explicitly told to keep it.
- Expo Device Hub remains useful for local human inspection and manual device control.

Do not add Appium, autonomous GUI-agent frameworks, or another mobile automation stack unless this smaller harness demonstrates a concrete gap.

## One-command local gate

For ordinary local iOS verification, run one command:

```sh
npm run verify:mobile
```

It performs the current useful verification chain in one process:

1. strict TypeScript;
2. lint;
3. `@expo/agent-cli` local iOS smoke verification and navigation to `/`;
4. the deterministic `agent-device` replay at `tests/mobile/replays/home-navigation.ios.ad`.

The first replay deliberately stays small and mutation-free:

```text
home
  -> inventory list
  -> home
  -> storage options
  -> home
```

It verifies stable accessibility boundaries already owned by the product and captures screenshots of the home, inventory, and storage screens. It does not require the World Query backend, mutate SQLite data, request camera permission, or invoke EAS.

Artifacts are written under:

```text
.git/rechibox-agent-artifacts/ios
```

Keeping generated evidence below `.git` prevents verification runs from dirtying the working tree.

`verify:mobile` is intentionally local-only. It never opts into EAS or the billed `native-sim` cloud path. If Xcode/iOS Simulator is unavailable, it should fail rather than silently spend cloud credits.

## `@expo/agent-cli`

The CLI is experimental, so Rechibox pins the command version in package scripts instead of depending on a moving `latest` release.

```sh
npm run agent:status
npm run agent:doctor
npm run agent:smoke:ios
npm run agent:smoke:android
```

The scripts currently use `@expo/agent-cli@1.0.13` through `npx`. This does not add a runtime or project dependency.

Useful direct commands while debugging the harness include:

```sh
npx --yes @expo/agent-cli@1.0.13 dev --ios --detach
npx --yes @expo/agent-cli@1.0.13 navigate /
npx --yes @expo/agent-cli@1.0.13 runtime:reload
npx --yes @expo/agent-cli@1.0.13 runtime:errors
npx --yes @expo/agent-cli@1.0.13 runtime:tree
```

Prefer `npm run verify:mobile` for the normal gate. Use the lower-level commands when diagnosing a failure or exploring a new flow.

References:

- https://www.npmjs.com/package/@expo/agent-cli
- https://docs.expo.dev/agents/

## `agent-device`

`agent-device` is developer-host / verification infrastructure, not a Rechibox application dependency. Expo documents it as an external verification tool for an installed Expo app.

The repository already uses `agent-device` in `bin/cloud-ios-smoke`; the current pinned default there is `0.21.1`. The one-command local gate uses the same version.

For manual debugging, useful commands include:

```sh
npx --yes agent-device@0.21.1 doctor
npx --yes agent-device@0.21.1 help workflow
npx --yes agent-device@0.21.1 snapshot -i
```

Use semantic/accessibility inspection as the primary control surface. Use screenshots, recordings, logs, network traces, and performance data as evidence or when semantic data is insufficient.

When an exploratory flow becomes valuable and stable, save it as an `agent-device` replay instead of immediately introducing a separate E2E framework. Durable replays should target stable labels/IDs rather than transient interactive refs.

References:

- https://docs.expo.dev/agents/agent-device/
- https://agent-device.dev/

## Existing remote iOS path

Rechibox already has a cost-aware remote iOS smoke harness:

```sh
npm run cloud:ios
```

That command:

1. refuses to run from a dirty working tree;
2. runs TypeScript and lint checks before allocating macOS capacity;
3. stops stale `native-sim` sessions and duplicate workflow runs;
4. starts one remote iOS Simulator with the `agent-device` proxy enabled;
5. opens `com.sergii.rechibox` and captures an interactive accessibility snapshot;
6. tears the remote run down immediately after verification by default.

`cloud:ios` consumes billed/limited macOS runner time. Do not use it for documentation-only, non-native, or otherwise cheap-to-check changes. Prefer `npm run verify:mobile` when local iOS is available. Use the cloud path only when remote native iOS verification is materially useful.

## Verification policy

For an ordinary meaningful UI/interaction change, the default command is:

```sh
npm run verify:mobile
```

Use lower-level `agent:*` and `agent-device` commands only when the combined gate fails or when authoring a new replay. Use `npm run cloud:ios` explicitly when remote native iOS verification is worth the runner cost.

Camera-critical behavior still requires a physical device. Simulator success is not sufficient evidence for camera behavior. A screenshot alone is not a complete verification result when the change is interactive; the deterministic replay verifies reachable behavior as well as visual evidence.

## Trial criteria

Use the combined harness on real Rechibox changes and keep track of these questions before expanding it:

- Can the coding agent reach the changed screen without manual help?
- Are accessibility selectors stable enough for durable replays?
- Can it complete the primary flow and one useful recovery flow?
- Does the captured evidence make review easier?
- Do deterministic replays remain reliable without an LLM?
- Does `@expo/agent-cli` add useful project/runtime diagnostics beyond the device layer?
- What is the setup/runtime cost on iOS and Android?

If this works, keep the harness small and add replay coverage only for product flows that earn their maintenance cost. If it does not, evaluate a deeper tool before adding more framework layers.

## Deferred alternatives

- **Argent** - assess when React Native/native profiling, network inspection, or deep runtime debugging becomes a recurring need beyond the current harness.
- **Screenmap** - assess for PR-level screen/navigation maps and visual change review after the basic agent verification loop is proven useful.
- **Appium** - hold until Rechibox needs a large deterministic QA suite, broad device-farm coverage, or a dedicated QA automation layer.
- **Mobile-Agent / AppAgent / Mobilerun-style autonomous GUI agents** - research only for autonomous user-level exploration. Do not put another planning agent between the coding agent and the device unless a concrete use case requires it.
- **Playwright** - use for web surfaces if they become product-relevant; it is not a replacement for native iOS/Android verification.
