import { useRouter, useTheme } from 'expo-router';
import { useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { MOCK_STORAGE_NOTICE, mockStorageOptions } from '@/storage/mock-options';

export default function StorageOptionsScreen() {
  const { colors } = useTheme();
  const router = useRouter();
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const selectedOption = mockStorageOptions.find(
    (option) => option.id === selectedId && option.available
  );

  return (
    <SafeAreaView
      edges={['left', 'right', 'bottom']}
      style={[styles.screen, { backgroundColor: colors.background }]}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text accessibilityRole="header" style={[styles.heading, { color: colors.text }]}>
          Оберіть свій варіант
        </Text>
        <Text style={[styles.note, { color: colors.text }]}>{MOCK_STORAGE_NOTICE}</Text>
        {mockStorageOptions.map((option) => {
          const selected = option.id === selectedId;
          const status = !option.available
            ? 'Недоступний у демо'
            : selected
              ? 'Обрано'
              : 'Доступний у демо';

          return (
            <Pressable
              key={option.id}
              accessibilityRole="radio"
              accessibilityLabel={`${option.name}, ${option.areaLabel}, ${option.priceLabel}. ${status}`}
              accessibilityState={{ checked: selected, disabled: !option.available }}
              disabled={!option.available}
              onPress={() => setSelectedId(option.id)}
              style={({ pressed }) => [
                styles.option,
                {
                  backgroundColor: colors.card,
                  borderColor: selected ? colors.text : colors.border,
                  opacity: pressed ? 0.75 : 1,
                },
              ]}>
              <Text style={[styles.optionName, { color: colors.text }]}>{option.name}</Text>
              <Text style={[styles.optionInfo, { color: colors.text }]}>
                {option.areaLabel} · {option.priceLabel}
              </Text>
              <Text style={[styles.status, { color: colors.text }]}>{status}</Text>
            </Pressable>
          );
        })}
      </ScrollView>
      <View style={[styles.footer, { borderTopColor: colors.border }]}>
        <Text accessibilityLiveRegion="polite" style={[styles.note, { color: colors.text }]}>
          {selectedOption ? `Обрано: ${selectedOption.name}` : 'Оберіть доступний варіант.'}
        </Text>
        <Pressable
          accessibilityRole="button"
          accessibilityState={{ disabled: !selectedOption }}
          disabled={!selectedOption}
          onPress={() => {
            if (selectedOption) {
              router.push({ pathname: '/storage/[id]', params: { id: selectedOption.id } });
            }
          }}
          style={({ pressed }) => [
            styles.button,
            { backgroundColor: colors.text, opacity: !selectedOption ? 0.4 : pressed ? 0.75 : 1 },
          ]}>
          <Text style={[styles.buttonText, { color: colors.background }]}>
            Переглянути деталі
          </Text>
        </Pressable>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  content: { padding: 24, gap: 16 },
  heading: { fontSize: 26, fontWeight: '700' },
  note: { fontSize: 15, lineHeight: 22 },
  option: { padding: 18, gap: 8, borderWidth: 2, borderRadius: 12 },
  optionName: { fontSize: 20, fontWeight: '600' },
  optionInfo: { fontSize: 16, lineHeight: 24 },
  status: { fontSize: 14, fontWeight: '600' },
  footer: { padding: 20, gap: 12, borderTopWidth: StyleSheet.hairlineWidth },
  button: {
    minHeight: 52,
    padding: 16,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  buttonText: { fontSize: 16, fontWeight: '600', textAlign: 'center' },
});
