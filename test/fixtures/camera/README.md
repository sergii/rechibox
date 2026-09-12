# Camera test fixtures

Place deterministic, non-sensitive images/videos here for Simulator camera tests.

Suggested naming:

- `single-object-01.jpg`
- `household-overlap-01.jpg`
- `cluttered-box-01.jpg`
- `low-light-01.jpg`
- `empty-scene-01.jpg`

The deterministic inventory flow can use a fixture anywhere on disk. First create a reviewed visual baseline:

```bash
npm run agent:inventory:baseline -- test/fixtures/camera/household-overlap-01.jpg
```

Then replay the exact camera -> capture -> YOLO -> review path and compare the final screen:

```bash
npm run agent:inventory:test -- test/fixtures/camera/household-overlap-01.jpg
```

The commands require Argent and the `buoycam` CLI. Buoy publishes the image before Argent launches Rechibox, which matters because the Simulator camera attaches at process start.

The generated Argent baseline lives under `.argent/flows/__baselines__/inventory-camera/`. Review it before committing it. Failure artifacts are written to `.argent/artifacts/` and are ignored.

Do not commit personal photos, addresses, labels with private data, or customer content.
