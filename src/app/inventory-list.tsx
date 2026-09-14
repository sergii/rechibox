import { useCallback, useState } from 'react';
import { useFocusEffect, useRouter } from 'expo-router';
import { ActivityIndicator, ScrollView, StyleSheet, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Text } from '@/components/ui/text';
import { useThemeColors } from '@/components/ui/theme-provider';
import {
  assignInventoryItemToBox,
  listInventoryBoxes,
  listInventoryItems,
  type StoredInventoryBox,
  type StoredInventoryItem,
} from '@/inventory/storage';

function formatCreatedAt(value: string) {
  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return date.toLocaleString('uk-UA', {
    dateStyle: 'medium',
    timeStyle: 'short',
  });
}

export default function InventoryListScreen() {
  const colors = useThemeColors();
  const router = useRouter();
  const [items, setItems] = useState<StoredInventoryItem[]>([]);
  const [boxes, setBoxes] = useState<StoredInventoryBox[]>([]);
  const [loading, setLoading] = useState(true);
  const [assigningItemId, setAssigningItemId] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const loadInventory = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      const [storedItems, storedBoxes] = await Promise.all([
        listInventoryItems(),
        listInventoryBoxes(),
      ]);
      setItems(storedItems);
      setBoxes(storedBoxes);
    } catch (loadError) {
      console.error('Could not load local inventory', loadError);
      setError('Не вдалося завантажити локальний інвентар.');
    } finally {
      setLoading(false);
    }
  }, []);

  useFocusEffect(
    useCallback(() => {
      let active = true;

      void Promise.all([listInventoryItems(), listInventoryBoxes()])
        .then(([storedItems, storedBoxes]) => {
          if (active) {
            setItems(storedItems);
            setBoxes(storedBoxes);
            setError(null);
          }
        })
        .catch((loadError) => {
          console.error('Could not load local inventory', loadError);
          if (active) {
            setError('Не вдалося завантажити локальний інвентар.');
          }
        })
        .finally(() => {
          if (active) {
            setLoading(false);
          }
        });

      return () => {
        active = false;
      };
    }, [])
  );

  async function handleAssign(item: StoredInventoryItem, box: StoredInventoryBox | null) {
    if (assigningItemId !== null) {
      return;
    }

    setAssigningItemId(item.id);
    setActionError(null);

    try {
      await assignInventoryItemToBox(item.id, box?.id ?? null);
      setItems((current) =>
        current.map((currentItem) =>
          currentItem.id === item.id
            ? {
                ...currentItem,
                boxId: box?.id ?? null,
                boxName: box?.name ?? null,
              }
            : currentItem
        )
      );
    } catch (assignError) {
      console.error('Could not assign inventory item to box', assignError);
      setActionError('Не вдалося змінити коробку для речі. Спробуйте ще раз.');
    } finally {
      setAssigningItemId(null);
    }
  }

  return (
    <SafeAreaView
      edges={['left', 'right', 'bottom']}
      style={[styles.screen, { backgroundColor: colors.background }]}>
      <ScrollView contentContainerStyle={styles.content}>
        <View style={styles.header}>
          <Text accessibilityRole="header" variant="h2">
            Мій інвентар
          </Text>
          {!loading && !error ? (
            <Text variant="muted">
              {items.length === 0 ? 'Поки що порожньо' : `Збережено речей: ${items.length}`}
            </Text>
          ) : null}
        </View>

        <Button onPress={() => router.push('/boxes')} variant="outline">
          {boxes.length === 0 ? 'Створити першу коробку' : `Мої коробки: ${boxes.length}`}
        </Button>

        {actionError ? (
          <Text accessibilityLiveRegion="polite" className="text-destructive">
            {actionError}
          </Text>
        ) : null}

        {loading ? (
          <View style={styles.state}>
            <ActivityIndicator />
            <Text accessibilityLiveRegion="polite">Завантажуємо інвентар…</Text>
          </View>
        ) : null}

        {!loading && error ? (
          <Card className="gap-3 p-4">
            <Text accessibilityLiveRegion="polite" className="text-destructive">
              {error}
            </Text>
            <Button onPress={() => void loadInventory()} variant="outline">
              Спробувати ще раз
            </Button>
          </Card>
        ) : null}

        {!loading && !error && items.length === 0 ? (
          <Card className="gap-2 p-4">
            <Text variant="h4">Інвентар ще порожній</Text>
            <Text variant="muted">
              Сфотографуйте речі в AI-інвентарі, перевірте розпізнавання і підтвердьте їх. Після
              цього вони залишаться на цьому пристрої навіть після перезапуску застосунку.
            </Text>
          </Card>
        ) : null}

        {!loading && !error
          ? items.map((item) => (
              <Card className="gap-2 p-4" key={item.id}>
                <Text variant="h4">{item.name}</Text>
                <Text variant="muted">AI-впевненість: {Math.round(item.confidence * 100)}%</Text>
                <Text variant="muted">Додано: {formatCreatedAt(item.createdAt)}</Text>
                <Text variant="small">
                  Коробка: {item.boxName ?? 'не призначено'}
                </Text>

                {boxes.length > 0 ? (
                  <View style={styles.boxChoices}>
                    <Button
                      disabled={assigningItemId !== null}
                      loading={assigningItemId === item.id && item.boxId !== null}
                      onPress={() => void handleAssign(item, null)}
                      size="sm"
                      variant={item.boxId === null ? 'default' : 'outline'}>
                      Без коробки
                    </Button>
                    {boxes.map((box) => (
                      <Button
                        disabled={assigningItemId !== null}
                        key={box.id}
                        onPress={() => void handleAssign(item, box)}
                        size="sm"
                        variant={item.boxId === box.id ? 'default' : 'outline'}>
                        {box.name}
                      </Button>
                    ))}
                  </View>
                ) : (
                  <Text variant="muted">
                    Створіть коробку, щоб прив’язати до неї цю річ.
                  </Text>
                )}
              </Card>
            ))
          : null}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  content: { padding: 24, gap: 12 },
  header: { gap: 4, marginBottom: 4 },
  state: {
    minHeight: 220,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 12,
  },
  boxChoices: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginTop: 4,
  },
});
