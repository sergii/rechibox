# Conversational World Query mobile slice v0.1

The home screen is the conversational entry point for asking questions about the user's World State.

## User flow

```text
App launch
→ restore World State id from local storage
→ verify the World State still exists on the backend
→ create and persist a new World State only when no valid local world exists
→ sync confirmed local inventory into that World State
→ type or dictate a question with the system keyboard
→ refresh the local inventory snapshot
→ POST /api/worlds/:id/natural_query
→ bounded deterministic natural-language interpreter
→ deterministic entity resolution
→ deterministic WorldState::Query
→ deterministic QueryAnswerRenderer
→ render the answer in the chat
```

The mobile client does not perform graph reasoning, choose between ambiguous entities, or generate an answer locally. Its only World State mutation in this slice is the explicit deterministic projection of already-confirmed local inventory.

## Configuration

Expo client configuration is intentionally public and contains no provider/API secrets:

```sh
EXPO_PUBLIC_RECHIBOX_API_URL=http://localhost:3000
```

For a physical phone, `localhost` points at the phone itself. Use a backend URL reachable from that device.

A World State id is not a build-time setting. The app stores one world id per normalized backend URL, restores it across app restarts, verifies it with `GET /api/worlds/:id`, and creates a replacement through `POST /api/worlds` only when no local id exists or the backend returns 404 for the stored world.

Native uses `expo-sqlite/kv-store`; web uses `localStorage`. Transient network or server failures never silently create another world. The existing local id is retained and the UI offers an explicit retry instead.

Expo inlines `EXPO_PUBLIC_` values into the client bundle, so they must never contain secrets.

## Identity boundary

World bootstrap v0.1 is device-local continuity, not user identity.

It intentionally does not claim cross-device restoration, authentication, account ownership, server-side session identity, or cross-device synchronization. Those require an authenticated identity contract rather than deriving identity from a device-local identifier.

The storage key is scoped by backend URL so development, preview, and production backends do not accidentally reuse each other's World State ids.

## Fail-closed behavior

If the backend URL is absent, the home screen remains usable but clearly reports that backend search is unavailable in that build.

If bootstrap or inventory synchronization cannot reach the backend, the composer remains disabled during bootstrap or the query fails explicitly. A failed verification does not discard the stored id or create a duplicate world.

The backend default is now the zero-cost deterministic interpreter:

```sh
AI_WORLD_QUERY_INTERPRETER=deterministic
```

Unsupported wording returns no bounded query. The client does not fall back to an on-device guess or call a model directly. `disabled` remains available explicitly, and RubyLLM remains opt-in only.

No model call is required by the default mobile slice.

## UI behavior

- `/` remains headerless and owns all safe-area edges.
- World bootstrap happens automatically on app entry.
- Confirmed local inventory is synchronized during bootstrap and immediately before each query.
- The composer is disabled until a World State session is ready.
- Bootstrap progress and failure/retry are explicit UI states.
- The chat composer stays reachable while the keyboard is open through `KeyboardAvoidingView` and keyboard-aware scrolling.
- Loading, missing configuration, backend failure, ambiguous/unknown/conflict answers, and retry-by-resubmission are visible states.
- The transcript is intentionally in-memory for v0.1. Restarting the app clears it, while the World State id persists.
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
2. first launch against a reachable backend creates one world;
3. confirmed local box/item data appears in that world;
4. restart restores the same world instead of creating another;
5. moving an item between local boxes is reflected before the next query;
6. stored world returning 404 creates and persists one replacement;
7. transient network failure preserves the stored world id and retry restores it;
8. resolved, unknown, ambiguous, conflict, and unsupported-query answers;
9. repeated queries, light/dark appearance, and safe areas.

CI and static checks do not substitute for runtime mobile inspection.
