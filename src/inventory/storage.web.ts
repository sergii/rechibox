export type StoredInventoryBox = {
  id: number;
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

type InventoryState = {
  nextBoxId: number;
  nextItemId: number;
  boxes: PersistedBox[];
  items: PersistedItem[];
};

const STORAGE_KEY = 'rechibox.inventory.v0.1';
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
  const box: PersistedBox = {
    id: state.nextBoxId,
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

function readState(): InventoryState {
  const raw = window.localStorage.getItem(STORAGE_KEY);
  if (!raw) return cloneEmptyState();

  try {
    const parsed = JSON.parse(raw) as Partial<InventoryState>;
    if (!Array.isArray(parsed.boxes) || !Array.isArray(parsed.items)) return cloneEmptyState();

    return {
      nextBoxId: validNextId(parsed.nextBoxId, parsed.boxes),
      nextItemId: validNextId(parsed.nextItemId, parsed.items),
      boxes: parsed.boxes as PersistedBox[],
      items: parsed.items as PersistedItem[],
    };
  } catch {
    return cloneEmptyState();
  }
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

function validNextId(value: unknown, records: Array<{ id?: number }>) {
  if (typeof value === 'number' && Number.isInteger(value) && value > 0) return value;

  return records.reduce((maximum, record) => Math.max(maximum, record.id ?? 0), 0) + 1;
}

function compareNewestFirst<T extends { createdAt: string; id: number }>(left: T, right: T) {
  return right.createdAt.localeCompare(left.createdAt) || right.id - left.id;
}
