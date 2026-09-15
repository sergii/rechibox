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
        <Stack.Screen name="inventory-list" options={{ title: 'Мій інвентар' }} />
        <Stack.Screen name="boxes" options={{ title: 'Мої коробки' }} />
        <Stack.Screen name="boxes/[publicId]" options={{ title: 'Коробка' }} />
        <Stack.Screen name="box-scan" options={{ title: 'Сканувати QR' }} />
      </Stack>
      <StatusBar style="auto" />
    </ThemeProvider>
  );
}
