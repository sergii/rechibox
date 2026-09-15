# Conversational World Query mobile slice v0.1

The home screen is now the conversational entry point for asking questions about the user's World State.

## User flow

```text
Home
→ type or dictate a question with the system keyboard
→ POST /api/worlds/:id/natural_query
→ bounded natural-language interpreter
→ deterministic entity resolution
→ deterministic WorldState::Query
→ deterministic QueryAnswerRenderer
→ render the answer in the chat
```

The mobile client does not perform graph reasoning, choose between ambiguous entities, mutate World State, or generate an answer locally.

## Configuration

Expo client configuration is intentionally public and contains no provider/API secrets:

```sh
EXPO_PUBLIC_RECHIBOX_API_URL=http://localhost:3000
EXPO_PUBLIC_RECHIBOX_WORLD_ID=<existing-world-id>
```

For a physical phone, `localhost` points at the phone itself. Use a backend URL reachable from that device.

Both variables are required for the v0.1 query slice. The world must already exist and contain the state being queried. User/world identity, authentication, world creation/restoration, and durable mobile session state are separate follow-up contracts rather than being guessed in this UI slice.

Expo inlines `EXPO_PUBLIC_` values into the client bundle, so they must never contain secrets.

## Fail-closed behavior

If either client variable is absent, the home screen remains usable but clearly reports that backend search is unavailable in that build.

If the backend natural-language interpreter is disabled, the client displays an unavailable result. It does not fall back to an on-device guess or call a model directly.

The existing backend default remains fail-closed:

```sh
AI_WORLD_QUERY_INTERPRETER=disabled
```

No model call is added by the mobile slice itself.

## UI behavior

- `/` remains headerless and owns all safe-area edges.
- The chat composer stays reachable while the keyboard is open through `KeyboardAvoidingView` and keyboard-aware scrolling.
- Loading, missing configuration, backend failure, ambiguous/unknown/conflict answers, and retry-by-resubmission are visible states.
- The transcript is intentionally in-memory for v0.1. Restarting the app clears it.
- Existing inventory and storage flows remain reachable as secondary actions.
- System keyboard dictation can populate the text field; no microphone permission or speech dependency is introduced.

## Verification

Required before treating the mobile slice as runtime-verified:

```sh
npm run typecheck
npm run lint
npx expo install --check
npx expo-doctor
```

Then exercise on iOS and Android with the keyboard open, including:

1. missing backend configuration;
2. configured backend with a known world/entity;
3. resolved answer;
4. unknown or ambiguous answer;
5. backend/interpreter unavailable;
6. repeated queries and network failure/retry;
7. light/dark appearance and safe areas.

CI and static checks do not substitute for runtime mobile inspection.
