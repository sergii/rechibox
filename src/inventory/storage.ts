import * as SQLite from 'expo-sqlite';

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

type InventoryRow = {
  id: number;
  name: string;
  source_label: string;
  confidence: number;
  box_id: number | null;
  box_name: string | null;
  created_at: string;
};

type InventoryBoxRow = {
  id: number;
  public_id: string;
  code: string;
  name: string;
  item_count: number;
  created_at: string;
};

const DATABASE_NAME = 'rechibox.db';
const SCHEMA_VERSION = 3;

let databasePromise: Promise<SQLite.SQLiteDatabase> | null = null;

function mapRow(row: InventoryRow): StoredInventoryItem {
  return {
    id: row.id,
    name: row.name,
    sourceLabel: row.source_label,
    confidence: row.confidence,
    boxId: row.box_id,
    boxName: row.box_name,
    createdAt: row.created_at,
  };
}

function mapBoxRow(row: InventoryBoxRow): StoredInventoryBox {
  return {
    id: row.id,
    publicId: row.public_id,
    code: row.code,
    name: row.name,
    itemCount: row.item_count,
    createdAt: row.created_at,
  };
}

async function migrateDatabase(database: SQLite.SQLiteDatabase) {
  await database.execAsync(`
    PRAGMA journal_mode = WAL;
    PRAGMA foreign_keys = ON;
  `);

  const versionRow = await database.getFirstAsync<{ user_version: number }>('PRAGMA user_version');
  let currentVersion = versionRow?.user_version ?? 0;

  if (currentVersion < 1) {
    await database.execAsync(`
      CREATE TABLE IF NOT EXISTS inventory_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        source_label TEXT NOT NULL,
        confidence REAL NOT NULL,
        created_at TEXT NOT NULL
      );
      CREATE INDEX IF NOT EXISTS inventory_items_created_at_idx
        ON inventory_items(created_at DESC, id DESC);
      PRAGMA user_version = 1;
    `);
    currentVersion = 1;
  }

  if (currentVersion < 2) {
    await database.execAsync(`
      CREATE TABLE IF NOT EXISTS inventory_boxes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
      CREATE INDEX IF NOT EXISTS inventory_boxes_created_at_idx
        ON inventory_boxes(created_at DESC, id DESC);
    `);

    const inventoryColumns = await database.getAllAsync<{ name: string }>(
      'PRAGMA table_info(inventory_items)'
    );
    const hasBoxId = inventoryColumns.some((column) => column.name === 'box_id');

    if (!hasBoxId) {
      await database.execAsync(
        'ALTER TABLE inventory_items ADD COLUMN box_id INTEGER REFERENCES inventory_boxes(id) ON DELETE SET NULL'
      );
    }

    await database.execAsync(`
      CREATE INDEX IF NOT EXISTS inventory_items_box_id_idx
        ON inventory_items(box_id, created_at DESC, id DESC);
      PRAGMA user_version = 2;
    `);
    currentVersion = 2;
  }

  if (currentVersion < 3) {
    const boxColumns = await database.getAllAsync<{ name: string }>(
      'PRAGMA table_info(inventory_boxes)'
    );

    if (!boxColumns.some((column) => column.name === 'public_id')) {
      await database.execAsync('ALTER TABLE inventory_boxes ADD COLUMN public_id TEXT');
    }

    if (!boxColumns.some((column) => column.name === 'code')) {
      await database.execAsync('ALTER TABLE inventory_boxes ADD COLUMN code TEXT');
    }

    await database.execAsync(`
      UPDATE inventory_boxes
         SET public_id = lower(hex(randomblob(16)))
       WHERE public_id IS NULL OR public_id = '';

      UPDATE inventory_boxes
         SET code = printf('BOX-%06d', id)
       WHERE code IS NULL OR code = '';

      CREATE UNIQUE INDEX IF NOT EXISTS inventory_boxes_public_id_uidx
        ON inventory_boxes(public_id);
      CREATE UNIQUE INDEX IF NOT EXISTS inventory_boxes_code_uidx
        ON inventory_boxes(code);

      PRAGMA user_version = ${SCHEMA_VERSION};
    `);
  }
}

async function getDatabase() {
  if (!databasePromise) {
    databasePromise = SQLite.openDatabaseAsync(DATABASE_NAME)
      .then(async (database) => {
        await migrateDatabase(database);
        return database;
      })
      .catch((error) => {
        databasePromise = null;
        throw error;
      });
  }

  return databasePromise;
}

export async function createInventoryBox(name: string): Promise<StoredInventoryBox> {
  const normalizedName = name.trim();

  if (!normalizedName) {
    throw new Error('Inventory box name must not be blank');
  }

  const database = await getDatabase();
  const createdAt = new Date().toISOString();
  let createdBox: StoredInventoryBox | null = null;

  await database.withExclusiveTransactionAsync(async (transaction) => {
    const result = await transaction.runAsync(
      `INSERT INTO inventory_boxes (name, public_id, created_at)
       VALUES (?, lower(hex(randomblob(16))), ?)`,
      normalizedName,
      createdAt
    );
    const id = Number(result.lastInsertRowId);
    const code = `BOX-${String(id).padStart(6, '0')}`;

    await transaction.runAsync('UPDATE inventory_boxes SET code = ? WHERE id = ?', code, id);

    const row = await transaction.getFirstAsync<InventoryBoxRow>(
      `SELECT id, public_id, code, name, 0 AS item_count, created_at
         FROM inventory_boxes
        WHERE id = ?`,
      id
    );

    if (!row) {
      throw new Error('Created inventory box could not be loaded');
    }

    createdBox = mapBoxRow(row);
  });

  if (!createdBox) {
    throw new Error('Inventory box was not created');
  }

  return createdBox;
}

export async function listInventoryBoxes(): Promise<StoredInventoryBox[]> {
  const database = await getDatabase();
  const rows = await database.getAllAsync<InventoryBoxRow>(
    `SELECT boxes.id,
            boxes.public_id,
            boxes.code,
            boxes.name,
            boxes.created_at,
            COUNT(items.id) AS item_count
       FROM inventory_boxes AS boxes
       LEFT JOIN inventory_items AS items ON items.box_id = boxes.id
      GROUP BY boxes.id, boxes.public_id, boxes.code, boxes.name, boxes.created_at
      ORDER BY boxes.created_at DESC, boxes.id DESC`
  );

  return rows.map(mapBoxRow);
}

export async function getInventoryBoxByPublicId(
  publicId: string
): Promise<StoredInventoryBox | null> {
  const database = await getDatabase();
  const row = await database.getFirstAsync<InventoryBoxRow>(
    `SELECT boxes.id,
            boxes.public_id,
            boxes.code,
            boxes.name,
            boxes.created_at,
            COUNT(items.id) AS item_count
       FROM inventory_boxes AS boxes
       LEFT JOIN inventory_items AS items ON items.box_id = boxes.id
      WHERE boxes.public_id = ?
      GROUP BY boxes.id, boxes.public_id, boxes.code, boxes.name, boxes.created_at`,
    publicId
  );

  return row ? mapBoxRow(row) : null;
}

export async function saveInventoryItems(
  items: readonly NewInventoryItem[],
  boxId: number | null = null
): Promise<StoredInventoryItem[]> {
  if (items.length === 0) {
    return [];
  }

  const database = await getDatabase();
  const createdAt = new Date().toISOString();
  const savedItems: StoredInventoryItem[] = [];
  let boxName: string | null = null;

  if (boxId !== null) {
    const box = await database.getFirstAsync<{ name: string }>(
      'SELECT name FROM inventory_boxes WHERE id = ?',
      boxId
    );

    if (!box) {
      throw new Error('Inventory box not found');
    }

    boxName = box.name;
  }

  await database.withExclusiveTransactionAsync(async (transaction) => {
    for (const item of items) {
      const name = item.name.trim();

      if (!name) {
        throw new Error('Inventory item name must not be blank');
      }

      const result = await transaction.runAsync(
        `INSERT INTO inventory_items (name, source_label, confidence, box_id, created_at)
         VALUES (?, ?, ?, ?, ?)`,
        name,
        item.sourceLabel,
        item.confidence,
        boxId,
        createdAt
      );

      savedItems.push({
        id: Number(result.lastInsertRowId),
        name,
        sourceLabel: item.sourceLabel,
        confidence: item.confidence,
        boxId,
        boxName,
        createdAt,
      });
    }
  });

  return savedItems;
}

export async function assignInventoryItemToBox(
  itemId: number,
  boxId: number | null
): Promise<void> {
  const database = await getDatabase();

  if (boxId !== null) {
    const box = await database.getFirstAsync<{ id: number }>(
      'SELECT id FROM inventory_boxes WHERE id = ?',
      boxId
    );

    if (!box) {
      throw new Error('Inventory box not found');
    }
  }

  const result = await database.runAsync(
    'UPDATE inventory_items SET box_id = ? WHERE id = ?',
    boxId,
    itemId
  );

  if (result.changes !== 1) {
    throw new Error('Inventory item not found');
  }
}

export async function listInventoryItems(): Promise<StoredInventoryItem[]> {
  const database = await getDatabase();
  const rows = await database.getAllAsync<InventoryRow>(
    `SELECT items.id,
            items.name,
            items.source_label,
            items.confidence,
            items.box_id,
            boxes.name AS box_name,
            items.created_at
       FROM inventory_items AS items
       LEFT JOIN inventory_boxes AS boxes ON boxes.id = items.box_id
      ORDER BY items.created_at DESC, items.id DESC`
  );

  return rows.map(mapRow);
}

export async function listInventoryItemsForBox(
  publicId: string
): Promise<StoredInventoryItem[]> {
  const database = await getDatabase();
  const rows = await database.getAllAsync<InventoryRow>(
    `SELECT items.id,
            items.name,
            items.source_label,
            items.confidence,
            items.box_id,
            boxes.name AS box_name,
            items.created_at
       FROM inventory_items AS items
       JOIN inventory_boxes AS boxes ON boxes.id = items.box_id
      WHERE boxes.public_id = ?
      ORDER BY items.created_at DESC, items.id DESC`,
    publicId
  );

  return rows.map(mapRow);
}
