# AppLlama + native-sim experiments

These are optional experiments. They do not replace the Rechibox engineering contract, the pinned Mobile Engineering Playbook, the local iOS Simulator + Argent loop, or physical-device validation.

## Experiment A: AppLlama skills, task-scoped

Goal: test whether AppLlama's research/design guidance improves Rechibox UI decisions without letting third-party opinionated rules silently redefine project architecture.

Prepare a pinned copy of the upstream skills without installing them into an agent auto-discovery directory:

```bash
npm run experiment:appllama:prepare
```

Pinned upstream revision:

```text
dd5caaec3d5d50ad7fc0324da238119c6b7c3707
```

The files land under `.experiments/appllama-skills/` and are ignored by Git. Read them only for an explicitly selected design/research task.

Use this contract when evaluating them:

- Rechibox `AGENTS.md` and the pinned Mobile Engineering Playbook remain authoritative.
- Study patterns and outcomes, not pixels. Do not copy a competitor screen 1:1.
- Do not add FlashList, TanStack Query, Zustand/Jotai, MMKV, navigation changes, or other dependencies merely because an external skill recommends them. Re-run the project's dependency decision ladder first.
- `appllama-usage` depends on the AppLlama MCP for the full catalog research workflow; MCP access is paid/Pro and must be explicitly connected by the user.
- `appllama-app-design-skill` can be evaluated without the MCP, but its architectural opinions are advisory only.

Suggested first task:

```text
Review the Rechibox AI inventory capture -> preview -> recognition -> review flow.
For this task only, read the pinned AppLlama skills from .experiments/appllama-skills/.
Treat Rechibox AGENTS.md and our Mobile Engineering Playbook as higher priority.
Extract reusable mobile interaction patterns and concrete UI findings. Do not change dependencies or architecture unless the Rechibox decision ladder independently justifies it.
```

Success means the skill produces useful, specific product/design findings that we would not have reached as quickly from the project contract alone. Failure means it mostly restates generic mobile advice, introduces architectural churn, or conflicts with established project decisions.

## Experiment B: native-sim + agent-device

Goal: prove that a coding agent running away from this Mac can get a real remote iOS Simulator, launch Rechibox, inspect the live UI, navigate Home -> AI inventory, and capture evidence.

This is deliberately a UI/runtime PoC first. Do not test Buoy, camera fixtures, detector quality, or YOLO performance in phase 1. The current inventory screen may still initialize native/model state; phase 1 simply does not score that behavior.

### Setup

Check the operator-owned tools:

```bash
npm run experiment:native-sim:doctor
```

If missing, install them manually after reviewing the packages:

```bash
npm install -g native-sim
npm install -g agent-device@latest
```

`agent-device` is intentionally not fetched with mutable `npx -y ...@latest` during unattended agent execution. Use an installed/pinned binary.

### Cost / experimental guard

`native-sim` is new/experimental and hosts simulators through GitHub infrastructure. Public projects may be free under the project's model; private repositories can consume GitHub-hosted macOS Actions minutes. There has also been public concern that this usage pattern should be treated as an experiment with respect to GitHub's terms. Do not wire it into CI yet.

For that reason the repo wrapper refuses to start a cloud run unless you explicitly acknowledge it:

```bash
RECHIBOX_ALLOW_CLOUD_MACOS=1 npm run experiment:native-sim:up
```

Then, in another terminal when the remote proxy is ready:

```bash
agent-device connect proxy
```

From the connected agent/device session, use normal agent-device interaction to open `com.sergii.rechibox`, take an interactive snapshot, navigate through visible semantic targets, and capture a screenshot.

### Phase-1 acceptance criteria

The experiment passes only if we can reproduce all of these without opening Xcode or manually operating a remote simulator UI:

1. Remote iOS Simulator comes up reliably.
2. Rechibox launches.
3. `agent-device` returns an interactive accessibility snapshot.
4. The agent can navigate Home -> AI inventory from semantic/user-visible targets.
5. A screenshot/evidence artifact can be captured.
6. The same procedure works again in a second clean run without repairing generated infrastructure by hand.

If it passes, compare it against Expo Simulator and Limrun before choosing a remote lane. Local Mac + Simulator + Argent + Buoy remains the fastest default loop while the developer Mac is available.
