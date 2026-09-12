# EAS deployment

Rechibox uses GitHub as the source of truth and Expo Application Services for cloud builds and over-the-air updates.

## Recommended one-command setup

For the first setup on a Mac, use:

```bash
npm run eas:setup
```

The setup command is interactive and resumable. It will:

1. Install dependencies and run typecheck/lint.
2. Check Expo authentication, open the Expo signup page when needed, and start `eas login`.
3. Install the SDK-compatible `expo-updates` package.
4. Initialize/link the Expo EAS project.
5. Configure EAS Update and verify `runtimeVersion`, `updates.url`, `projectId`, channels, and environments.
6. Check GitHub CLI authentication and configure the `EXPO_TOKEN` Actions secret when missing.
7. Commit and push generated EAS configuration automatically when the working tree was clean before setup.
8. Offer to register an iPhone for ad hoc internal distribution.
9. Offer to start the first interactive iOS preview cloud build, including Apple signing setup when required.

The command can be run again safely. Steps that are already configured are skipped where possible.

If you are pulling these helpers for the first time, the full copy-paste command is:

```bash
git pull --ff-only && npm run eas:setup
```

## Modular commands

The individual commands remain available for troubleshooting or partial setup:

```bash
npm run eas:bootstrap
npm run eas:token
npm run eas:check
npm run eas:status
npm run eas:device:ios
npm run eas:credentials:ios
npm run eas:build:preview:ios
npm run eas:build:production:ios
npm run eas:update:preview
npm run eas:update:production
```

## Automated flow

### Pull requests

`.github/workflows/eas-pr-preview.yml` publishes an EAS preview for pull requests and comments the preview information on the PR when EAS is fully configured and `EXPO_TOKEN` is available. Superseded preview jobs are cancelled automatically.

### Main branch

CI runs typecheck and lint on every push to `main`. After a successful CI run, `.github/workflows/eas-update.yml` automatically publishes the commit to the `preview` channel. Superseded preview update jobs are cancelled automatically.

If EAS is not configured yet, the automatic publish path does not publish an update. This keeps bootstrap commits from producing false deployment failures.

### Production updates

Use the `EAS Update` workflow manually and select the `production` channel. Production updates are intentionally not automatic.

### Native cloud builds

Use the `EAS Build` workflow manually and select:

- platform: `ios`, `android`, or `all`
- profile: `preview` or `production`

The workflow queues the build in Expo and returns immediately.

The first iOS preview build is intentionally interactive when run locally because Apple authentication, device registration, certificates, and ad hoc provisioning can require user action.

## EAS environments

The `preview` build profile uses the EAS `preview` environment, and the `production` build profile uses the EAS `production` environment. EAS Update commands also pass the matching `--environment` explicitly, which is required for modern Expo SDKs.

## Runtime compatibility

The app uses the Expo `fingerprint` runtime version policy. JavaScript/assets can be shipped with EAS Update only when they are compatible with the installed native runtime.

Changes such as adding a native library, changing ExecuTorch backends, changing native permissions, or changing native Expo modules require a new EAS Build. A mismatched update will not be delivered to an incompatible installed binary.
