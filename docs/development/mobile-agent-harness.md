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
  -> Expo Device Hub
       human-oriented local device dashboard
```

The tools are complementary:

- `@expo/agent-cli` is the Expo-aware project/runtime layer.
- `agent-device` is the device verification layer.
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

Prefer the project scripts for the stable entry points and direct commands for exploratory work.

References:

- https://www.npmjs.com/package/@expo/agent-cli
- https://docs.expo.dev/agents/

## `agent-device`

`agent-device` is intentionally a developer-host tool, not a Rechibox application dependency. Expo documents it as an external verification tool for an installed Expo app.

Install/check it on a development machine when needed:

```sh
npm install -g agent-device@0.21.0
agent-device doctor
agent-device help workflow
```

A typical verification loop is:

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

## Verification policy

For meaningful UI or interaction changes, prefer this order:

1. `npm run typecheck` and `npm run lint`.
2. `npm run agent:status` to inspect the Expo project/runtime plan.
3. Run the relevant iOS or Android target.
4. Use `agent-device` to inspect the real screen, drive the changed flow, and capture evidence when the tool is available on the host.
5. Run the relevant `agent:smoke:*` command.
6. For camera-critical behavior, still verify on a physical device. Simulator success is not sufficient evidence for camera behavior.

A screenshot alone is not a complete verification result when the change is interactive. Prefer evidence that shows both reachable state and behavior.

## First bounded trial

Use the harness on the next user-visible Rechibox slice and answer these questions before expanding it:

- Can the agent reach the changed screen without manual help?
- Is the accessibility snapshot sufficient to identify the important controls?
- Can it complete the primary flow and one failure/recovery flow?
- Does the captured evidence make review easier?
- Can a useful exploratory flow be replayed without an LLM?
- What is the setup/runtime cost on iOS and Android?

If this works, keep the harness small and make successful replay flows part of the repository over time. If it does not, evaluate a deeper tool before adding more framework layers.

## Deferred alternatives

- **Argent** - assess when React Native/native profiling, network inspection, or deep runtime debugging becomes a recurring need beyond the current harness.
- **Screenmap** - assess for PR-level screen/navigation maps and visual change review after the basic agent verification loop is proven useful.
- **Appium** - hold until Rechibox needs a large deterministic QA suite, broad device-farm coverage, or a dedicated QA automation layer.
- **Mobile-Agent / AppAgent / Mobilerun-style autonomous GUI agents** - research only for autonomous user-level exploration. Do not put another planning agent between the coding agent and the device unless a concrete use case requires it.
- **Playwright** - use for web surfaces if they become product-relevant; it is not a replacement for native iOS/Android verification.
