import { useRouter, useTheme } from 'expo-router';
import { Pressable, ScrollView, StyleSheet, Text } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

export default function HomeScreen() {
  const { colors } = useTheme();
  const router = useRouter();

  return (
    <SafeAreaView style={[styles.screen, { backgroundColor: colors.background }]}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text accessibilityRole="header" style={[styles.title, { color: colors.text }]}>
          Rechibox
        </Text>
        <Text style={[styles.description, { color: colors.text }]}>
          Простір для ваших речей.
        </Text>
        <Text style={[styles.note, { color: colors.text }]}>
          Спробуйте вибрати бокс на демонстраційних даних. Це не бронювання.
        </Text>
        <Pressable
          accessibilityRole="button"
          onPress={() => router.push('/storage')}
          style={({ pressed }) => [
            styles.button,
            { backgroundColor: colors.text, opacity: pressed ? 0.75 : 1 },
          ]}>
          <Text style={[styles.buttonText, { color: colors.background }]}>
            Переглянути варіанти
          </Text>
        </Pressable>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
  },
  content: {
    flexGrow: 1,
    justifyContent: 'center',
    padding: 24,
    gap: 12,
  },
  title: {
    fontSize: 36,
    fontWeight: '700',
  },
  description: {
    fontSize: 18,
  },
  note: {
    fontSize: 16,
    lineHeight: 24,
    marginVertical: 12,
  },
  button: {
    minHeight: 52,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 16,
    borderRadius: 12,
  },
  buttonText: {
    fontSize: 16,
    fontWeight: '600',
    textAlign: 'center',
  },
});
