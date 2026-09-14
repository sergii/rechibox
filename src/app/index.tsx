import { useRouter, useTheme } from 'expo-router';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { RechiboxLogo } from '@/components/RechiboxLogo';

export default function HomeScreen() {
  const { colors } = useTheme();
  const router = useRouter();

  return (
    <SafeAreaView style={[styles.screen, { backgroundColor: colors.background }]}>
      <ScrollView contentContainerStyle={styles.content}>
        <View accessible accessibilityLabel="Rechibox" accessibilityRole="image" style={styles.logo}>
          <RechiboxLogo color={colors.text} />
        </View>
        <Text style={[styles.description, { color: colors.text }]}>Простір для ваших речей.</Text>
        <Text style={[styles.note, { color: colors.text }]}>
          Спробуйте вибір боксу або додайте речі через AI-інвентар. Підтверджені речі зберігаються локально на цьому пристрої.
        </Text>
        <Pressable
          accessibilityRole="button"
          onPress={() => router.push('/storage')}
          style={({ pressed }) => [
            styles.button,
            { backgroundColor: colors.text, opacity: pressed ? 0.75 : 1 },
          ]}>
          <Text style={[styles.buttonText, { color: colors.background }]}>Переглянути варіанти</Text>
        </Pressable>
        <Pressable
          accessibilityRole="button"
          onPress={() => router.push('/inventory')}
          style={({ pressed }) => [
            styles.secondaryButton,
            { borderColor: colors.border, opacity: pressed ? 0.7 : 1 },
          ]}>
          <Text style={[styles.secondaryButtonText, { color: colors.text }]}>Додати речі через AI</Text>
        </Pressable>
        <Pressable
          accessibilityRole="button"
          onPress={() => router.push('/inventory-list')}
          style={({ pressed }) => [
            styles.secondaryButton,
            { borderColor: colors.border, opacity: pressed ? 0.7 : 1 },
          ]}>
          <Text style={[styles.secondaryButtonText, { color: colors.text }]}>Мій інвентар</Text>
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
  logo: {
    width: 300,
    height: 70,
    alignSelf: 'flex-start',
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
  secondaryButton: {
    minHeight: 52,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 16,
    borderRadius: 12,
    borderWidth: 1,
  },
  secondaryButtonText: {
    fontSize: 16,
    fontWeight: '600',
    textAlign: 'center',
  },
});
