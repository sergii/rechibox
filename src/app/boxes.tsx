import { useRouter } from 'expo-router';
import { useEffect, useState } from 'react';
import { ActivityIndicator, ScrollView, StyleSheet, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Text } from '@/components/ui/text';
import { useThemeColors } from '@/components/ui/theme-provider';
import {
  createInventoryBox,
  listInventoryBoxes,
  type StoredInventoryBox,
} from '@/inventory/storage';

export default function BoxesScreen() {
  const colors = useThemeColors();
  const router = useRouter();
  const [boxes, setBoxes] = useState<StoredInventoryBox[]>([]);
  const [name, setName] = useState('');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    void listInventoryBoxes()
      .then((storedBoxes) => {
        if (!cancelled) {
          setBoxes(storedBoxes);
          setError(null);
        }
      })
      .catch((loadError) => {
        console.error('Could not load local boxes', loadError);
        if (!cancelled) {
          setError('Не вдалося завантажити коробки.');
        }
      })
      .finally(() => {
        if (!cancelled) {
          setLoading(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, []);

  async function handleCreate() {
    if (!name.trim() || saving) {
      return;
    }

    setSaving(true);
    setError(null);

    try {
      const box = await createInventoryBox(name);
      setBoxes((current) => [box, ...current]);
      setName('');
    } catch (createError) {
      console.error('Could not create local box', createError);
      setError('Не вдалося створити коробку. Спробуйте ще раз.');
    } finally {
      setSaving(false);
    }
  }

  return (
    <SafeAreaView
      edges={['left', 'right', 'bottom']}
      style={[styles.screen, { backgroundColor: colors.background }]}>
      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        <View style={styles.header}>
          <Text accessibilityRole="header" variant="h2">
            Мої коробки
          </Text>
          <Text variant="muted">
            Кожна коробка має стабільний код і QR, який відкриває її вміст на цьому пристрої.
          </Text>
        </View>

        <Button onPress={() => router.push('/box-scan')} size="lg" variant="outline">
          Сканувати QR коробки
        </Button>

        <Card className="gap-3 p-4">
          <Text variant="h4">Нова коробка</Text>
          <Input
            accessibilityLabel="Назва нової коробки"
            autoCapitalize="sentences"
            onChangeText={setName}
            placeholder="Наприклад, Зимові речі"
            returnKeyType="done"
            value={name}
          />
          <Button
            disabled={!name.trim() || saving}
            loading={saving}
            onPress={() => void handleCreate()}>
            {saving ? 'Створюємо…' : 'Створити коробку'}
          </Button>
        </Card>

        {error ? (
          <Text accessibilityLiveRegion="polite" className="text-destructive">
            {error}
          </Text>
        ) : null}

        {loading ? (
          <View style={styles.state}>
            <ActivityIndicator />
            <Text accessibilityLiveRegion="polite">Завантажуємо коробки…</Text>
          </View>
        ) : null}

        {!loading && boxes.length === 0 ? (
          <Card className="gap-2 p-4">
            <Text variant="h4">Ще немає коробок</Text>
            <Text variant="muted">
              Створіть коробку, щоб отримати її код і QR та прив’язувати до неї речі.
            </Text>
          </Card>
        ) : null}

        {!loading
          ? boxes.map((box) => (
              <Card className="gap-2 p-4" key={box.publicId}>
                <Text variant="h4">{box.name}</Text>
                <Text variant="small">{box.code}</Text>
                <Text variant="muted">
                  {box.itemCount === 0
                    ? 'Поки що порожня'
                    : `Речей у коробці: ${box.itemCount}`}
                </Text>
                <Button
                  onPress={() =>
                    router.push({ pathname: '/boxes/[publicId]', params: { publicId: box.publicId } })
                  }
                  variant="outline">
                  Відкрити коробку
                </Button>
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
  header: { gap: 6, marginBottom: 4 },
  state: {
    minHeight: 180,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 12,
  },
});
