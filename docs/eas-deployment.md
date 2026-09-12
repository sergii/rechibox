# EAS deployment

Rechibox uses GitHub as the source of truth and Expo Application Services for cloud builds and over-the-air updates.

## One-time bootstrap

Run:

```bash
npm run eas:bootstrap
```

The script will:

1. Check Expo authentication and open `eas login` when needed.
2. Install the SDK-compatible `expo-updates` package when it is missing.
3. Initialize/link the Expo EAS project.
4. Configure EAS Update.
5. Verify `runtimeVersion`, `updates.url`, `projectId`, and the preview/production channels.

After the command completes, review and commit all generated changes, including `package.json`, `package-lock.json`, and `app.json`.

## GitHub token

Run:

```bash
npm run eas:token
```

On macOS this opens the Expo access-token page, asks for the token with hidden terminal input, and stores it directly in GitHub Actions as the `EXPO_TOKEN` repository secret using `gh`.

The token is never written to the repository.

## iPhone setup

If EAS does not already know the test iPhone, register it with:

```bash
npm run eas:device:ios
```

Prepare Apple signing credentials for the preview profile with:

```bash
npm run eas:credentials:ios
```

These are account-level operations and can require interactive Apple authentication.

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

Equivalent local commands are available when useful:

```bash
npm run eas:build:preview:ios
npm run eas:build:production:ios
```

The first iOS cloud build can still require Apple signing credentials and device registration for internal distribution.

## Runtime compatibility

The app uses the Expo `fingerprint` runtime version policy. JavaScript/assets can be shipped with EAS Update only when they are compatible with the installed native runtime.

Changes such as adding a native library, changing ExecuTorch backends, changing native permissions, or changing native Expo modules require a new EAS Build. A mismatched update will not be delivered to an incompatible installed binary.

## Useful commands

```bash
npm run eas:check
npm run eas:status
npm run eas:update:preview
npm run eas:update:production
```
