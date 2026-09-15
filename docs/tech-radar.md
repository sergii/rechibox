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

Last reviewed: 2026-09-15.
