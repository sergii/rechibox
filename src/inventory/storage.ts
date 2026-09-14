import * as SQLite from 'expo-sqlite';

export type StoredInventoryItem = {
  id: number;
  name: string;
  sourceLabel: string;
  confidence: number;
  createdAt: string;
};

export type NewInventoryItem = Pick<StoredInventoryItem, 'name' | 'sourceLabel' | 'confidence'>;

type InventoryRow = {
  id: number;
  name: string;
  source_label: string;
  confidence: number;
  created_at: string;
};

const DATABASE_NAME = 'rechibox.db';
const SCHEMA_VERSION = 1;

let databasePromise: Promise<SQLite.SQLiteDatabase> | null = null;

function mapRow(row: InventoryRow): StoredInventoryItem {
  return {
    id: row.id,
    name: row.name,
    sourceLabel: row.source_label,
    confidence: row.confidence,
    createdAt: row.created_at,
  };
}

async function migrateDatabase(database: SQLite.SQLiteDatabase) {
  const versionRow = await database.getFirstAsync<{ user_version: number }>('PRAGMA user_version');
  const currentVersion = versionRow?.user_version ?? 0;

  if (currentVersion >= SCHEMA_VERSION) {
    return;
  }

  await database.execAsync(`
    PRAGMA journal_mode = WAL;
    CREATE TABLE IF NOT EXISTS inventory_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      source_label TEXT NOT NULL,
      confidence REAL NOT NULL,
      created_at TEXT NOT NULL
    );
    CREATE INDEX IF NOT EXISTS inventory_items_created_at_idx
      ON inventory_items(created_at DESC, id DESC);
    PRAGMA user_version = ${SCHEMA_VERSION};
  `);
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

export async function saveInventoryItems(
  items: readonly NewInventoryItem[]
): Promise<StoredInventoryItem[]> {
  if (items.length === 0) {
    return [];
  }

  const database = await getDatabase();
  const createdAt = new Date().toISOString();
  const savedItems: StoredInventoryItem[] = [];

  await database.withExclusiveTransactionAsync(async (transaction) => {
    for (const item of items) {
      const name = item.name.trim();

      if (!name) {
        throw new Error('Inventory item name must not be blank');
      }

      const result = await transaction.runAsync(
        `INSERT INTO inventory_items (name, source_label, confidence, created_at)
         VALUES (?, ?, ?, ?)`,
        name,
        item.sourceLabel,
        item.confidence,
        createdAt
      );

      savedItems.push({
        id: Number(result.lastInsertRowId),
        name,
        sourceLabel: item.sourceLabel,
        confidence: item.confidence,
        createdAt,
      });
    }
  });

  return savedItems;
}

export async function listInventoryItems(): Promise<StoredInventoryItem[]> {
  const database = await getDatabase();
  const rows = await database.getAllAsync<InventoryRow>(
    `SELECT id, name, source_label, confidence, created_at
     FROM inventory_items
     ORDER BY created_at DESC, id DESC`
  );

  return rows.map(mapRow);
}
