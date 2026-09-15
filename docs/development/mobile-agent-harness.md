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

## `@expo/agent-cli`

The CLI is experimental, so Rechibox pins the command version in package scripts instead of depending on a moving `latest` release.

```sh
npm run agent:status
npm run agent:doctor
npm run agent:smoke:ios
npm run agent:smoke:android
```

The scripts currently use `@expo/agent-cli@1.0.13` through `npx`. This does not add a runtime or project dependency.

Useful direct commands while working interactively include:

```sh
npx --yes @expo/agent-cli@1.0.13 dev --ios --detach
npx --yes @expo/agent-cli@1.0.13 navigate /
npx --yes @expo/agent-cli@1.0.13 runtime:reload
npx --yes @expo/agent-cli@1.0.13 runtime:errors
npx --yes @expo/agent-cli@1.0.13 runtime:tree
```

Prefer the project scripts for stable entry points and direct commands for exploratory work.

References:

- https://www.npmjs.com/package/@expo/agent-cli
- https://docs.expo.dev/agents/

## `agent-device`

`agent-device` is developer-host / verification infrastructure, not a Rechibox application dependency. Expo documents it as an external verification tool for an installed Expo app.

The repository already uses `agent-device` in `bin/cloud-ios-smoke`; the current pinned default there is `0.21.1`.

For local verification, install/check the matching version on a development machine when needed:

```sh
npm install -g agent-device@0.21.1
agent-device doctor
agent-device help workflow
```

A typical local verification loop is:

```sh
# Start the app first, for example:
npm run ios

# In another terminal:
agent-device open com.sergii.rechibox --platform ios
agent-device snapshot -i
# interact with semantic refs returned by the snapshot
agent-device screenshot ./tmp/rechibox-verification.png
agent-device close
```

Use semantic/accessibility inspection as the primary control surface. Use screenshots, recordings, logs, network traces, and performance data as evidence or when semantic data is insufficient.

When an exploratory flow becomes valuable and stable, save it as an `agent-device` replay instead of immediately introducing a separate E2E framework.

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

`cloud:ios` consumes billed/limited macOS runner time. Do not use it for documentation-only, non-native, or otherwise cheap-to-check changes. Prefer local verification when a suitable simulator/device is available. Use the cloud path when remote native iOS verification is materially useful.

## Verification policy

For meaningful UI or interaction changes, prefer this order:

1. `npm run typecheck` and `npm run lint`.
2. `npm run agent:status` to inspect the Expo project/runtime plan.
3. Run the relevant iOS or Android target locally when practical.
4. Use `agent-device` to inspect the real screen, drive the changed flow, and capture evidence when the tool is available on the host.
5. Run the relevant `agent:smoke:*` command.
6. Use `npm run cloud:ios` only when remote native iOS verification is worth the runner cost.
7. For camera-critical behavior, still verify on a physical device. Simulator success is not sufficient evidence for camera behavior.

A screenshot alone is not a complete verification result when the change is interactive. Prefer evidence that shows both reachable state and behavior.

## First bounded trial

Use the combined harness on the next user-visible Rechibox slice and answer these questions before expanding it:

- Can the coding agent reach the changed screen without manual help?
- Is the accessibility snapshot sufficient to identify the important controls?
- Can it complete the primary flow and one failure/recovery flow?
- Does the captured evidence make review easier?
- Can a useful exploratory flow be replayed without an LLM?
- Does `@expo/agent-cli` add useful project/runtime diagnostics beyond the existing device layer?
- What is the setup/runtime cost on iOS and Android?

If this works, keep the harness small and make successful replay flows part of the repository over time. If it does not, evaluate a deeper tool before adding more framework layers.

## Deferred alternatives

- **Argent** - assess when React Native/native profiling, network inspection, or deep runtime debugging becomes a recurring need beyond the current harness.
- **Screenmap** - assess for PR-level screen/navigation maps and visual change review after the basic agent verification loop is proven useful.
- **Appium** - hold until Rechibox needs a large deterministic QA suite, broad device-farm coverage, or a dedicated QA automation layer.
- **Mobile-Agent / AppAgent / Mobilerun-style autonomous GUI agents** - research only for autonomous user-level exploration. Do not put another planning agent between the coding agent and the device unless a concrete use case requires it.
- **Playwright** - use for web surfaces if they become product-relevant; it is not a replacement for native iOS/Android verification.
