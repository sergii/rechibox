import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, ScrollView, StyleSheet, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Text } from '@/components/ui/text';
import { useThemeColors } from '@/components/ui/theme-provider';
import { listInventoryItems, type StoredInventoryItem } from '@/inventory/storage';

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
  const [items, setItems] = useState<StoredInventoryItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadInventory = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      setItems(await listInventoryItems());
    } catch (loadError) {
      console.error('Could not load local inventory', loadError);
      setError('Не вдалося завантажити локальний інвентар.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadInventory();
  }, [loadInventory]);

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
              <Card className="gap-1.5 p-4" key={item.id}>
                <Text variant="h4">{item.name}</Text>
                <Text variant="muted">AI-впевненість: {Math.round(item.confidence * 100)}%</Text>
                <Text variant="muted">Додано: {formatCreatedAt(item.createdAt)}</Text>
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
});
