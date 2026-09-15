import Storage from './storage';

import { getWorldQueryConfiguration, WorldQueryClientError } from './client';

const WORLD_ID_STORAGE_PREFIX = 'rechibox.world-id.v0.1:';

type JsonObject = Record<string, unknown>;

export type WorldSession = {
  apiUrl: string;
  worldId: string;
  source: 'stored' | 'created';
};

export async function bootstrapWorldSession(): Promise<WorldSession> {
  const configuration = getWorldQueryConfiguration();
  if (!configuration.ready) {
    throw new WorldQueryClientError(
      'not_configured',
      'Rechibox World State backend is not configured for this build.',
    );
  }

  const storageKey = worldIdStorageKey(configuration.apiUrl);
  const storedWorldId = (await Storage.getItem(storageKey))?.trim() ?? '';

  if (storedWorldId) {
    const exists = await worldExists(configuration.apiUrl, storedWorldId);
    if (exists) {
      return {
        apiUrl: configuration.apiUrl,
        worldId: storedWorldId,
        source: 'stored',
      };
    }

    await Storage.removeItem(storageKey);
  }

  const worldId = await createWorld(configuration.apiUrl);
  await Storage.setItem(storageKey, worldId);

  return {
    apiUrl: configuration.apiUrl,
    worldId,
    source: 'created',
  };
}

export async function forgetWorldSession(apiUrl: string): Promise<void> {
  const normalizedApiUrl = apiUrl.trim().replace(/\/+$/, '');
  if (!normalizedApiUrl) return;

  await Storage.removeItem(worldIdStorageKey(normalizedApiUrl));
}

async function worldExists(apiUrl: string, worldId: string): Promise<boolean> {
  let response: Response;
  try {
    response = await fetch(`${apiUrl}/api/worlds/${encodeURIComponent(worldId)}`);
  } catch {
    throw new WorldQueryClientError('request_failed', 'Could not reach the Rechibox backend.');
  }

  if (response.status === 404) return false;
  if (!response.ok) {
    throw new WorldQueryClientError('request_failed', `Could not restore World State (HTTP ${response.status}).`);
  }

  const payload = await readJsonObject(response);
  if (payload.id !== worldId) {
    throw new WorldQueryClientError('invalid_response', 'Backend returned a different World State id.');
  }

  return true;
}

async function createWorld(apiUrl: string): Promise<string> {
  let response: Response;
  try {
    response = await fetch(`${apiUrl}/api/worlds`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    });
  } catch {
    throw new WorldQueryClientError('request_failed', 'Could not reach the Rechibox backend.');
  }

  if (!response.ok) {
    throw new WorldQueryClientError('request_failed', `Could not create World State (HTTP ${response.status}).`);
  }

  const payload = await readJsonObject(response);
  if (typeof payload.id !== 'string' || payload.id.trim().length === 0) {
    throw new WorldQueryClientError('invalid_response', 'Backend did not return a World State id.');
  }

  return payload.id;
}

async function readJsonObject(response: Response): Promise<JsonObject> {
  try {
    const value: unknown = await response.json();
    if (isObject(value)) return value;
  } catch {
    // The caller reports a stable contract error below.
  }

  throw new WorldQueryClientError('invalid_response', 'Backend returned invalid JSON.');
}

function worldIdStorageKey(apiUrl: string) {
  return `${WORLD_ID_STORAGE_PREFIX}${apiUrl}`;
}

function isObject(value: unknown): value is JsonObject {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
