import { Stack, useLocalSearchParams, useRouter, useTheme } from 'expo-router';
import { useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import {
  MOCK_STORAGE_NOTICE,
  mockStorageOptions,
  type MockStorageOption,
} from '@/storage/mock-options';

export default function StorageDetailsScreen() {
  const { id } = useLocalSearchParams<{ id?: string | string[] }>();
  const optionId = Array.isArray(id) ? id[0] : id;
  const option = mockStorageOptions.find((item) => item.id === optionId);
  const { colors } = useTheme();
  const router = useRouter();

  if (!option) {
    return (
      <SafeAreaView
        edges={['left', 'right', 'bottom']}
        style={[styles.screen, { backgroundColor: colors.background }]}>
        <ScrollView contentContainerStyle={styles.content}>
          <Text accessibilityRole="header" style={[styles.heading, { color: colors.text }]}>
            Варіант не знайдено
          </Text>
          <Text style={[styles.body, { color: colors.text }]}>
            Такого варіанта немає в демонстраційному списку.
          </Text>
          <Pressable
            accessibilityRole="button"
            onPress={() => router.dismissTo('/storage')}
            style={({ pressed }) => [
              styles.button,
              { backgroundColor: colors.text, opacity: pressed ? 0.75 : 1 },
            ]}>
            <Text style={[styles.buttonText, { color: colors.background }]}>До варіантів</Text>
          </Pressable>
        </ScrollView>
      </SafeAreaView>
    );
  }

  // A different route ID starts a fresh confirmation, even if Router reuses this screen.
  return <StorageSelection key={option.id} option={option} />;
}

function StorageSelection({ option }: { option: MockStorageOption }) {
  const { colors } = useTheme();
  const router = useRouter();
  const [confirmed, setConfirmed] = useState(false);

  return (
    <SafeAreaView
      edges={['left', 'right', 'bottom']}
      style={[styles.screen, { backgroundColor: colors.background }]}>
      <Stack.Screen options={{ title: confirmed ? 'Результат вибору' : 'Деталі варіанта' }} />
      <ScrollView contentContainerStyle={styles.content}>
        <Text
          accessibilityRole="header"
          accessibilityLiveRegion="polite"
          style={[styles.heading, { color: colors.text }]}>
          {confirmed ? 'Вибір підтверджено' : 'Перевірте свій вибір'}
        </Text>
        <Text style={[styles.body, { color: colors.text }]}>
          {confirmed
            ? 'Бронювання не створено. Це лише демонстрація вибору, яка не зберігається.'
            : MOCK_STORAGE_NOTICE}
        </Text>
        <View style={[styles.details, { backgroundColor: colors.card, borderColor: colors.border }]}>
          <Text style={[styles.optionName, { color: colors.text }]}>{option.name}</Text>
          <View style={styles.field}>
            <Text style={[styles.label, { color: colors.text }]}>Площа</Text>
            <Text style={[styles.value, { color: colors.text }]}>{option.areaLabel}</Text>
          </View>
          <View style={styles.field}>
            <Text style={[styles.label, { color: colors.text }]}>Приклад ціни</Text>
            <Text style={[styles.value, { color: colors.text }]}>{option.priceLabel}</Text>
          </View>
          <View style={styles.field}>
            <Text style={[styles.label, { color: colors.text }]}>Приклад локації</Text>
            <Text style={[styles.value, { color: colors.text }]}>{option.facilityLabel}</Text>
          </View>
          <Text style={[styles.label, { color: colors.text }]}>
            {option.available ? 'Доступний у демо' : 'Недоступний у демо'}
          </Text>
        </View>
        <View style={styles.actions}>
          {!confirmed && (
            <>
              <Text style={[styles.body, { color: colors.text }]}>
                {option.available
                  ? 'Підтвердження покаже підсумок вибору. Це не бронювання.'
                  : 'Цей демонстраційний варіант недоступний. Оберіть інший.'}
              </Text>
              <Pressable
                accessibilityRole="button"
                accessibilityState={{ disabled: !option.available }}
                disabled={!option.available}
                onPress={() => {
                  if (option.available) setConfirmed(true);
                }}
                style={({ pressed }) => [
                  styles.button,
                  { backgroundColor: colors.text, opacity: !option.available ? 0.4 : pressed ? 0.75 : 1 },
                ]}>
                <Text style={[styles.buttonText, { color: colors.background }]}>
                  Підтвердити вибір
                </Text>
              </Pressable>
            </>
          )}
          <Pressable
            accessibilityRole="button"
            onPress={() => router.dismissTo('/storage')}
            style={({ pressed }) => [
              styles.button,
              { borderColor: colors.text, borderWidth: 1, opacity: pressed ? 0.75 : 1 },
            ]}>
            <Text style={[styles.buttonText, { color: colors.text }]}>
              {confirmed ? 'Обрати інший варіант' : 'Змінити вибір'}
            </Text>
          </Pressable>
          {confirmed && (
            <Pressable
              accessibilityRole="button"
              onPress={() => router.dismissTo('/')}
              style={({ pressed }) => [styles.button, { opacity: pressed ? 0.75 : 1 }]}>
              <Text style={[styles.buttonText, { color: colors.text }]}>На головну</Text>
            </Pressable>
          )}
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  content: { flexGrow: 1, padding: 24, gap: 20 },
  heading: { fontSize: 26, fontWeight: '700' },
  body: { fontSize: 16, lineHeight: 24 },
  details: { padding: 20, gap: 18, borderWidth: 1, borderRadius: 12 },
  optionName: { fontSize: 24, fontWeight: '700' },
  field: { gap: 4 },
  label: { fontSize: 14 },
  value: { fontSize: 18, fontWeight: '500' },
  actions: { marginTop: 'auto', gap: 12 },
  button: {
    minHeight: 52,
    padding: 16,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  buttonText: { fontSize: 16, fontWeight: '600', textAlign: 'center' },
});
