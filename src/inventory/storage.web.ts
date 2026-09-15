export type StoredInventoryBox = {
  id: number;
  publicId: string;
  code: string;
  name: string;
  itemCount: number;
  createdAt: string;
};

export type StoredInventoryItem = {
  id: number;
  name: string;
  sourceLabel: string;
  confidence: number;
  boxId: number | null;
  boxName: string | null;
  createdAt: string;
};

export type NewInventoryItem = Pick<StoredInventoryItem, 'name' | 'sourceLabel' | 'confidence'>;

type PersistedBox = Omit<StoredInventoryBox, 'itemCount'>;
type PersistedItem = Omit<StoredInventoryItem, 'boxName'>;
type LegacyPersistedBox = Omit<PersistedBox, 'publicId' | 'code'> &
  Partial<Pick<PersistedBox, 'publicId' | 'code'>>;

type InventoryState = {
  nextBoxId: number;
  nextItemId: number;
  boxes: PersistedBox[];
  items: PersistedItem[];
};

type LegacyInventoryState = {
  nextBoxId?: number;
  nextItemId?: number;
  boxes?: LegacyPersistedBox[];
  items?: PersistedItem[];
};

const STORAGE_KEY = 'rechibox.inventory.v0.1';
const PUBLIC_ID_PATTERN = /^[0-9a-f]{32}$/;
const EMPTY_STATE: InventoryState = {
  nextBoxId: 1,
  nextItemId: 1,
  boxes: [],
  items: [],
};

export async function createInventoryBox(name: string): Promise<StoredInventoryBox> {
  const normalizedName = name.trim();
  if (!normalizedName) throw new Error('Inventory box name must not be blank');

  const state = readState();
  const id = state.nextBoxId;
  const box: PersistedBox = {
    id,
    publicId: createPublicId(),
    code: formatBoxCode(id),
    name: normalizedName,
    createdAt: new Date().toISOString(),
  };

  state.nextBoxId += 1;
  state.boxes.push(box);
  writeState(state);

  return { ...box, itemCount: 0 };
}

export async function listInventoryBoxes(): Promise<StoredInventoryBox[]> {
  const state = readState();

  return [...state.boxes]
    .sort(compareNewestFirst)
    .map((box) => ({
      ...box,
      itemCount: state.items.filter((item) => item.boxId === box.id).length,
    }));
}

export async function getInventoryBoxByPublicId(
  publicId: string,
): Promise<StoredInventoryBox | null> {
  const normalizedPublicId = publicId.trim().toLowerCase();
  const state = readState();
  const box = state.boxes.find((candidate) => candidate.publicId === normalizedPublicId);

  if (!box) return null;

  return {
    ...box,
    itemCount: state.items.filter((item) => item.boxId === box.id).length,
  };
}

export async function saveInventoryItems(
  items: readonly NewInventoryItem[],
  boxId: number | null = null,
): Promise<StoredInventoryItem[]> {
  if (items.length === 0) return [];

  const state = readState();
  const box = boxId === null ? null : state.boxes.find((candidate) => candidate.id === boxId);
  if (boxId !== null && !box) throw new Error('Inventory box not found');

  const createdAt = new Date().toISOString();
  const savedItems = items.map((item) => {
    const name = item.name.trim();
    if (!name) throw new Error('Inventory item name must not be blank');

    const persisted: PersistedItem = {
      id: state.nextItemId,
      name,
      sourceLabel: item.sourceLabel,
      confidence: item.confidence,
      boxId,
      createdAt,
    };

    state.nextItemId += 1;
    state.items.push(persisted);

    return {
      ...persisted,
      boxName: box?.name ?? null,
    };
  });

  writeState(state);
  return savedItems;
}

export async function assignInventoryItemToBox(itemId: number, boxId: number | null): Promise<void> {
  const state = readState();

  if (boxId !== null && !state.boxes.some((box) => box.id === boxId)) {
    throw new Error('Inventory box not found');
  }

  const item = state.items.find((candidate) => candidate.id === itemId);
  if (!item) throw new Error('Inventory item not found');

  item.boxId = boxId;
  writeState(state);
}

export async function listInventoryItems(): Promise<StoredInventoryItem[]> {
  const state = readState();
  const boxNames = new Map(state.boxes.map((box) => [box.id, box.name]));

  return [...state.items]
    .sort(compareNewestFirst)
    .map((item) => ({
      ...item,
      boxName: item.boxId === null ? null : (boxNames.get(item.boxId) ?? null),
    }));
}

export async function listInventoryItemsForBox(
  publicId: string,
): Promise<StoredInventoryItem[]> {
  const normalizedPublicId = publicId.trim().toLowerCase();
  const state = readState();
  const box = state.boxes.find((candidate) => candidate.publicId === normalizedPublicId);

  if (!box) return [];

  return state.items
    .filter((item) => item.boxId === box.id)
    .sort(compareNewestFirst)
    .map((item) => ({ ...item, boxName: box.name }));
}

function readState(): InventoryState {
  const raw = window.localStorage.getItem(STORAGE_KEY);
  if (!raw) return cloneEmptyState();

  let parsed: LegacyInventoryState;
  try {
    parsed = JSON.parse(raw) as LegacyInventoryState;
  } catch {
    return cloneEmptyState();
  }

  if (!Array.isArray(parsed.boxes) || !Array.isArray(parsed.items)) return cloneEmptyState();

  const usedPublicIds = new Set<string>();
  let migrated = false;
  const boxes = parsed.boxes.map((box) => {
    let publicId = typeof box.publicId === 'string' ? box.publicId.trim().toLowerCase() : '';
    if (!PUBLIC_ID_PATTERN.test(publicId) || usedPublicIds.has(publicId)) {
      publicId = createUniquePublicId(usedPublicIds);
      migrated = true;
    }
    usedPublicIds.add(publicId);

    const code = formatBoxCode(box.id);
    if (box.code !== code) migrated = true;

    return {
      id: box.id,
      publicId,
      code,
      name: box.name,
      createdAt: box.createdAt,
    };
  });

  const state: InventoryState = {
    nextBoxId: validNextId(parsed.nextBoxId, boxes),
    nextItemId: validNextId(parsed.nextItemId, parsed.items),
    boxes,
    items: parsed.items,
  };

  if (migrated) writeState(state);
  return state;
}

function writeState(state: InventoryState) {
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

function cloneEmptyState(): InventoryState {
  return {
    nextBoxId: EMPTY_STATE.nextBoxId,
    nextItemId: EMPTY_STATE.nextItemId,
    boxes: [],
    items: [],
  };
}

function createUniquePublicId(usedPublicIds: Set<string>) {
  let publicId = createPublicId();
  while (usedPublicIds.has(publicId)) publicId = createPublicId();
  return publicId;
}

function createPublicId() {
  if (!globalThis.crypto?.getRandomValues) {
    throw new Error('Secure random generator is unavailable');
  }

  const bytes = new Uint8Array(16);
  globalThis.crypto.getRandomValues(bytes);
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0')).join('');
}

function formatBoxCode(id: number) {
  return `BOX-${String(id).padStart(6, '0')}`;
}

function validNextId(value: unknown, records: Array<{ id?: number }>) {
  const minimumNextId = records.reduce((maximum, record) => Math.max(maximum, record.id ?? 0), 0) + 1;

  if (typeof value === 'number' && Number.isInteger(value) && value >= minimumNextId) return value;
  return minimumNextId;
}

function compareNewestFirst<T extends { createdAt: string; id: number }>(left: T, right: T) {
  return right.createdAt.localeCompare(left.createdAt) || right.id - left.id;
}
