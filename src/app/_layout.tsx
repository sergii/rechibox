import '../../global.css';

import { DarkTheme, DefaultTheme, Stack, ThemeProvider } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useColorScheme } from 'react-native';

export default function RootLayout() {
  const colorScheme = useColorScheme();

  return (
    <ThemeProvider value={colorScheme === 'dark' ? DarkTheme : DefaultTheme}>
      <Stack screenOptions={{ headerBackTitle: 'Назад' }}>
        <Stack.Screen name="index" options={{ title: 'Rechibox', headerShown: false }} />
        <Stack.Screen name="storage/index" options={{ title: 'Варіанти зберігання' }} />
        <Stack.Screen name="storage/[id]" options={{ title: 'Деталі варіанта' }} />
        <Stack.Screen name="inventory" options={{ title: 'AI-інвентар' }} />
      </Stack>
      <StatusBar style="auto" />
    </ThemeProvider>
  );
}
