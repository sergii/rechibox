import { listInventoryBoxes, listInventoryItems } from '@/inventory/storage';

import { getWorldQueryConfiguration, WorldQueryClientError } from './client';

type SnapshotEntity = {
  source_ref: string;
  kind: 'container' | 'item';
  label: string;
  attributes: Record<string, string | number>;
  location_ref?: string | null;
};

export type InventorySyncResult = {
  createdEntities: number;
  updatedEntities: number;
  locationChanges: number;
  conflicts: string[];
};

export async function syncInventoryToWorld(worldId: string): Promise<InventorySyncResult> {
  const normalizedWorldId = worldId.trim();
  if (!normalizedWorldId) {
    throw new WorldQueryClientError('request_failed', 'World State id must not be blank.');
  }

  const configuration = getWorldQueryConfiguration();
  if (!configuration.ready) {
    throw new WorldQueryClientError('not_configured', 'Rechibox backend is not configured for this build.');
  }

  const [boxes, items] = await Promise.all([listInventoryBoxes(), listInventoryItems()]);
  const entities: SnapshotEntity[] = [
    ...boxes.map((box) => ({
      source_ref: boxRef(box.id),
      kind: 'container' as const,
      label: box.name,
      attributes: { local_inventory_id: box.id },
    })),
    ...items.map((item) => ({
      source_ref: itemRef(item.id),
      kind: 'item' as const,
      label: item.name,
      attributes: {
        local_inventory_id: item.id,
        recognition_source: item.sourceLabel,
        recognition_confidence: item.confidence,
      },
      location_ref: item.boxId === null ? null : boxRef(item.boxId),
    })),
  ];

  let response: Response;
  try {
    response = await fetch(
      `${configuration.apiUrl}/api/worlds/${encodeURIComponent(normalizedWorldId)}/inventory_snapshot`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          snapshot: {
            contract_version: '0.1',
            entities,
          },
        }),
      },
    );
  } catch {
    throw new WorldQueryClientError('request_failed', 'Could not sync local inventory to Rechibox.');
  }

  const payload = await readJsonObject(response);
  if (!response.ok) {
    const detail = typeof payload.error === 'string' ? payload.error : `HTTP ${response.status}`;
    throw new WorldQueryClientError('request_failed', detail);
  }

  return parseSyncResult(payload);
}

function boxRef(id: number) {
  return `mobile_inventory:box:${id}`;
}

function itemRef(id: number) {
  return `mobile_inventory:item:${id}`;
}

async function readJsonObject(response: Response): Promise<Record<string, unknown>> {
  try {
    const value: unknown = await response.json();
    if (isObject(value)) return value;
  } catch {
    // Stable contract error is reported below.
  }

  throw new WorldQueryClientError('invalid_response', 'Backend returned invalid inventory sync JSON.');
}

function parseSyncResult(payload: Record<string, unknown>): InventorySyncResult {
  const createdEntities = payload.created_entities;
  const updatedEntities = payload.updated_entities;
  const locationChanges = payload.location_changes;
  const conflicts = payload.conflicts;

  if (
    typeof createdEntities !== 'number' ||
    typeof updatedEntities !== 'number' ||
    typeof locationChanges !== 'number' ||
    !Array.isArray(conflicts) ||
    !conflicts.every((value) => typeof value === 'string')
  ) {
    throw new WorldQueryClientError('invalid_response', 'Backend returned an invalid inventory sync result.');
  }

  return { createdEntities, updatedEntities, locationChanges, conflicts };
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
