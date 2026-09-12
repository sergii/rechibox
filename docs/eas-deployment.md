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

## GitHub secret

Create an Expo access token and save it as the repository Actions secret named `EXPO_TOKEN`.

Never commit the token to the repository.

## Automated flow

### Pull requests

`.github/workflows/eas-pr-preview.yml` publishes an EAS preview for pull requests and comments the preview information on the PR when EAS is fully configured and `EXPO_TOKEN` is available.

### Main branch

CI runs typecheck and lint on every push to `main`. After a successful CI run, `.github/workflows/eas-update.yml` automatically publishes the commit to the `preview` channel.

If EAS is not configured yet, the automatic publish job exits successfully without publishing. This keeps bootstrap commits from producing false failures.

### Production updates

Use the `EAS Update` workflow manually and select the `production` channel. Production updates are intentionally not automatic.

### Native cloud builds

Use the `EAS Build` workflow manually and select:

- platform: `ios`, `android`, or `all`
- profile: `preview` or `production`

The workflow queues the build in Expo and returns immediately.

The first iOS cloud build can still require Apple signing/credential setup. That is an account-level operation and cannot be stored in the repository.

## Runtime compatibility

The app uses the Expo `fingerprint` runtime version policy. JavaScript/assets can be shipped with EAS Update only when they are compatible with the installed native runtime.

Changes such as adding a native library, changing ExecuTorch backends, changing native permissions, or changing native Expo modules require a new EAS Build. A mismatched update will not be delivered to an incompatible installed binary.

## Useful commands

```bash
npm run eas:check
npm run eas:update:preview
npm run eas:update:production
```
