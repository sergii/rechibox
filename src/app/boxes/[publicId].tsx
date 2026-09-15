import { useFocusEffect, useLocalSearchParams, useRouter } from 'expo-router';
import { useCallback, useState } from 'react';
import { ActivityIndicator, ScrollView, StyleSheet, View } from 'react-native';
import QRCode from 'react-native-qrcode-svg';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Text } from '@/components/ui/text';
import { useThemeColors } from '@/components/ui/theme-provider';
import { buildBoxQrPayload } from '@/inventory/box-identity';
import {
  getInventoryBoxByPublicId,
  listInventoryItemsForBox,
  type StoredInventoryBox,
  type StoredInventoryItem,
} from '@/inventory/storage';

export default function BoxDetailsScreen() {
  const colors = useThemeColors();
  const router = useRouter();
  const { publicId } = useLocalSearchParams<{ publicId?: string }>();
  const normalizedPublicId = typeof publicId === 'string' ? publicId : '';
  const [box, setBox] = useState<StoredInventoryBox | null>(null);
  const [items, setItems] = useState<StoredInventoryItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!normalizedPublicId) {
      setBox(null);
      setItems([]);
      setError('Некоректний ідентифікатор коробки.');
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const [storedBox, storedItems] = await Promise.all([
        getInventoryBoxByPublicId(normalizedPublicId),
        listInventoryItemsForBox(normalizedPublicId),
      ]);

      setBox(storedBox);
      setItems(storedBox ? storedItems : []);
    } catch (loadError) {
      console.error('Could not load box details', loadError);
      setError('Не вдалося завантажити коробку.');
    } finally {
      setLoading(false);
    }
  }, [normalizedPublicId]);

  useFocusEffect(
    useCallback(() => {
      void load();
    }, [load])
  );

  return (
    <SafeAreaView
      edges={['left', 'right', 'bottom']}
      style={[styles.screen, { backgroundColor: colors.background }]}>
      <ScrollView contentContainerStyle={styles.content}>
        {loading ? (
          <View style={styles.state}>
            <ActivityIndicator />
            <Text accessibilityLiveRegion="polite">Завантажуємо коробку…</Text>
          </View>
        ) : null}

        {!loading && error ? (
          <Card className="gap-3 p-4">
            <Text accessibilityRole="header" variant="h3">
              Не вдалося відкрити коробку
            </Text>
            <Text className="text-destructive">{error}</Text>
            <Button onPress={() => void load()} variant="outline">
              Спробувати ще раз
            </Button>
          </Card>
        ) : null}

        {!loading && !error && !box ? (
          <Card className="gap-3 p-4">
            <Text accessibilityRole="header" variant="h3">
              Коробку не знайдено
            </Text>
            <Text variant="muted">
              Цей QR не відповідає коробці, збереженій на цьому пристрої.
            </Text>
            <Button onPress={() => router.replace('/box-scan')}>Сканувати іншу коробку</Button>
          </Card>
        ) : null}

        {!loading && !error && box ? (
          <>
            <View style={styles.header}>
              <Text accessibilityRole="header" variant="h2">
                {box.name}
              </Text>
              <Text variant="muted">{box.code}</Text>
            </View>

            <Card className="items-center gap-4 p-5">
              <View style={styles.qrFrame}>
                <QRCode
                  backgroundColor="#FFFFFF"
                  color="#000000"
                  size={220}
                  value={buildBoxQrPayload(box.publicId)}
                />
              </View>
              <Text className="text-center" variant="muted">
                Наклейте цей QR на фізичну коробку. Код під ним можна використати як людську
                назву-ідентифікатор.
              </Text>
              <Text selectable variant="small">
                {box.code}
              </Text>
            </Card>

            <View style={styles.sectionHeader}>
              <Text variant="h3">Вміст</Text>
              <Text variant="muted">
                {items.length === 0 ? 'Поки що порожня' : `Речей: ${items.length}`}
              </Text>
            </View>

            {items.length === 0 ? (
              <Card className="gap-2 p-4">
                <Text variant="h4">У коробці ще немає речей</Text>
                <Text variant="muted">
                  Прив’яжіть речі через «Мій інвентар», а потім вони з’являться тут.
                </Text>
              </Card>
            ) : (
              items.map((item) => (
                <Card className="gap-1 p-4" key={item.id}>
                  <Text variant="h4">{item.name}</Text>
                  <Text variant="muted">Джерело: {item.sourceLabel}</Text>
                </Card>
              ))
            )}

            <Button onPress={() => router.push('/inventory-list')} variant="outline">
              Відкрити мій інвентар
            </Button>
            <Button onPress={() => router.replace('/box-scan')} variant="outline">
              Сканувати іншу коробку
            </Button>
          </>
        ) : null}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  content: { padding: 24, gap: 16 },
  header: { gap: 4 },
  sectionHeader: { gap: 4, marginTop: 4 },
  state: {
    minHeight: 240,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 12,
  },
  qrFrame: {
    padding: 16,
    borderRadius: 16,
    backgroundColor: '#FFFFFF',
  },
});
