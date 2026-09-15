# Rechibox Technology Radar

This document records technologies worth adopting, trying, assessing, or deliberately not adding yet. The goal is to preserve context behind technology choices without turning every interesting library into a dependency.

## Rings

- **Adopt** - current product choice; use by default for the relevant problem.
- **Trial** - approved for a bounded product experiment.
- **Assess** - promising candidate worth revisiting when a concrete requirement appears.
- **Hold** - do not introduce without a new reason and explicit re-evaluation.

## Mobile scanning

| Technology | Ring | Decision | Revisit when |
| --- | --- | --- | --- |
| `expo-camera` barcode/QR scanning | Adopt | Use the existing camera stack for the first Box Identity QR flow. Rechibox already owns `expo-camera`, and one-at-a-time box scanning does not justify another native camera stack. Enable barcode scanning only when the QR slice is implemented. | If the current scanner becomes a measurable UX or reliability bottleneck. |
| `react-native-nitro-zxing` | Assess | Promising high-performance barcode/QR scanner for React Native, especially for continuous or high-throughput scanning. Do not install now. Adoption would also pull Rechibox toward the VisionCamera/Nitro native stack and require a new native binary, so the complexity is not justified for the current single-box QR flow. | Continuous rapid scanning; small, damaged, skewed, or difficult codes; multiple codes in frame; required barcode formats that the current path handles poorly; or measured latency/reliability problems with `expo-camera`. |
| `react-native-vision-camera` | Assess | Do not migrate the existing camera flow just to gain faster QR scanning. Consider it together with Nitro ZXing if camera throughput or frame-processing requirements become a product need beyond still-photo inventory capture. | The product needs real-time frame processors, high-throughput scanning, or other VisionCamera-specific capabilities. |

## Decision rule for Box Identity

The first implementation should stay intentionally small:

```text
physical box
  -> QR identity (BOX-...)
  -> expo-camera scan
  -> resolve box
  -> show box contents
```

Benchmark or migrate to another scanning stack only after the real Box Identity flow demonstrates a problem. A synthetic throughput benchmark alone is not a reason to add native dependencies.

## Mobile agent and verification tooling

| Technology | Ring | Decision | Revisit when |
| --- | --- | --- | --- |
| `@expo/agent-cli` | Trial | Use as the Expo-aware project/runtime layer for agent workflows. Rechibox pins `1.0.13` in package scripts instead of depending on a moving `latest` release because the tool is experimental. It is invoked through `npx`, not added as an application dependency. | Promote after several real feature slices show stable commands/output and useful failure diagnostics. |
| `agent-device` | Trial | Use as the primary native device verification layer for coding agents: semantic accessibility snapshots, interaction, screenshots/logs/evidence, and replay. Keep it as developer-host tooling rather than a Rechibox runtime dependency. | Promote when it has verified representative iOS and Android flows and replay proves reliable enough for routine PR checks. |
| Expo Device Hub | Adopt | Keep the existing local DevTools dashboard for human simulator/emulator control. It complements rather than replaces agent verification. | Revisit if it materially overlaps with the agent workflow or becomes maintenance-heavy. |
| Argent | Assess | Strong candidate for deeper React Native/native debugging, profiling, network inspection, and visual regression. Do not add a second overlapping device tool before a demonstrated gap in the current harness. | Repeated performance/debugging problems require deeper runtime evidence than `agent-device` provides. |
| Screenmap | Assess | Promising for PR-level screen/navigation maps and visual change review, but defer integration until the simpler `@expo/agent-cli` + `agent-device` verification loop is proven useful. | Rechibox has enough screens and PR churn that navigation/visual diffs would materially reduce review effort. |
| Appium | Hold | Mature and appropriate for large deterministic QA suites and device farms, but too much framework for the current stage. | Dedicated QA automation, broad device-matrix coverage, or a long-lived enterprise E2E suite becomes a requirement. |
| Mobile-Agent / AppAgent / Mobilerun-style autonomous GUI agents | Assess | Keep on the research radar for autonomous user-level exploration. Do not insert another planner/agent into the normal coding loop while the coding agent can drive the device directly. | A concrete autonomous exploratory-QA or cross-app task requires its own planning agent. |
| Playwright | Hold for native | Use only for web surfaces if they become product-relevant. Browser mobile emulation does not verify the native iOS/Android app. | Rechibox gains a real web product/admin surface that needs browser automation. |

The current harness is documented in [`docs/development/mobile-agent-harness.md`](development/mobile-agent-harness.md).

Last reviewed: 2026-09-16.
