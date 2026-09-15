import { CameraView, type BarcodeScanningResult, useCameraPermissions } from 'expo-camera';
import { useRouter } from 'expo-router';
import { useEffect, useRef, useState } from 'react';
import { AppState, Linking, StyleSheet, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Button } from '@/components/ui/button';
import { Text } from '@/components/ui/text';
import { useThemeColors } from '@/components/ui/theme-provider';
import { parseBoxQrPayload } from '@/inventory/box-identity';
import { getInventoryBoxByPublicId } from '@/inventory/storage';

export default function BoxScanScreen() {
  const colors = useThemeColors();
  const router = useRouter();
  const [permission, requestPermission, refreshPermission] = useCameraPermissions();
  const [appState, setAppState] = useState(AppState.currentState);
  const [cameraReady, setCameraReady] = useState(false);
  const [cameraFailed, setCameraFailed] = useState(false);
  const [cameraKey, setCameraKey] = useState(0);
  const [scanLocked, setScanLocked] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const resolvingRef = useRef(false);

  useEffect(() => {
    const subscription = AppState.addEventListener('change', (nextState) => {
      setAppState(nextState);

      if (nextState === 'active') {
        void refreshPermission().catch(() => {
          setMessage('Не вдалося оновити стан дозволу камери.');
        });
      } else {
        setCameraReady(false);
      }
    });

    return () => subscription.remove();
  }, [refreshPermission]);

  async function handleRequestPermission() {
    setMessage(null);

    try {
      const result = await requestPermission();
      if (!result.granted && !result.canAskAgain) {
        setMessage('Доступ до камери вимкнено. Його можна змінити в налаштуваннях системи.');
      }
    } catch {
      setMessage('Не вдалося запросити доступ до камери. Спробуйте ще раз.');
    }
  }

  async function handleOpenSettings() {
    setMessage(null);

    try {
      await Linking.openSettings();
    } catch {
      setMessage('Не вдалося відкрити системні налаштування.');
    }
  }

  async function handleBarcodeScanned(result: BarcodeScanningResult) {
    if (scanLocked || resolvingRef.current) {
      return;
    }

    resolvingRef.current = true;
    setScanLocked(true);
    setMessage(null);

    try {
      const publicId = parseBoxQrPayload(result.data);

      if (!publicId) {
        setMessage('Це не QR-код Rechibox. Спробуйте іншу наклейку.');
        return;
      }

      const box = await getInventoryBoxByPublicId(publicId);

      if (!box) {
        setMessage('Цю коробку не знайдено на цьому пристрої.');
        return;
      }

      router.replace({ pathname: '/boxes/[publicId]', params: { publicId } });
    } catch (scanError) {
      console.error('Could not resolve scanned box QR', scanError);
      setMessage('Не вдалося відкрити коробку. Спробуйте ще раз.');
    } finally {
      resolvingRef.current = false;
    }
  }

  function handleScanAgain() {
    setMessage(null);
    setScanLocked(false);

    if (cameraFailed) {
      setCameraFailed(false);
      setCameraReady(false);
      setCameraKey((current) => current + 1);
    }
  }

  if (!permission) {
    return (
      <SafeAreaView
        edges={['left', 'right', 'bottom']}
        style={[styles.screen, { backgroundColor: colors.background }]}>
        <View style={styles.state}>
          <Text>Перевіряємо доступ до камери…</Text>
        </View>
      </SafeAreaView>
    );
  }

  if (!permission.granted) {
    return (
      <SafeAreaView
        edges={['left', 'right', 'bottom']}
        style={[styles.screen, { backgroundColor: colors.background }]}>
        <View style={styles.permissionContent}>
          <Text accessibilityRole="header" variant="h2">
            Камера потрібна для QR
          </Text>
          <Text>
            Rechibox використовує камеру, щоб прочитати QR-код на коробці та відкрити її вміст.
          </Text>
          {message ? <Text className="text-destructive">{message}</Text> : null}
          <Button onPress={permission.canAskAgain ? handleRequestPermission : handleOpenSettings}>
            {permission.canAskAgain ? 'Надати доступ до камери' : 'Відкрити налаштування'}
          </Button>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView
      edges={['left', 'right', 'bottom']}
      style={[styles.screen, { backgroundColor: colors.background }]}>
      <View style={styles.content}>
        <View style={styles.header}>
          <Text accessibilityRole="header" variant="h2">
            Скануйте QR коробки
          </Text>
          <Text variant="muted">
            Наведіть камеру на QR Rechibox. Після розпізнавання відкриється локальний вміст
            коробки.
          </Text>
        </View>

        <View style={[styles.cameraFrame, { backgroundColor: colors.card }]}>
          {appState === 'active' ? (
            <CameraView
              barcodeScannerSettings={{ barcodeTypes: ['qr'] }}
              facing="back"
              key={cameraKey}
              onBarcodeScanned={scanLocked ? undefined : (result) => void handleBarcodeScanned(result)}
              onCameraReady={() => {
                setCameraFailed(false);
                setCameraReady(true);
                if (!scanLocked) {
                  setMessage(null);
                }
              }}
              onMountError={({ message: cameraMessage }) => {
                console.error('Could not mount box QR camera', cameraMessage);
                setCameraFailed(true);
                setCameraReady(false);
                setScanLocked(true);
                setMessage('Не вдалося запустити камеру. Спробуйте ще раз.');
              }}
              style={StyleSheet.absoluteFill}
            />
          ) : (
            <View style={styles.state}>
              <Text>Камера призупинена, поки застосунок неактивний.</Text>
            </View>
          )}

          {appState === 'active' ? <View pointerEvents="none" style={styles.viewfinder} /> : null}
        </View>

        {!cameraReady && appState === 'active' && !message ? (
          <Text accessibilityLiveRegion="polite" variant="muted">
            Готуємо камеру…
          </Text>
        ) : null}

        {message ? (
          <>
            <Text accessibilityLiveRegion="polite" className="text-destructive">
              {message}
            </Text>
            <Button onPress={handleScanAgain} variant="outline">
              Сканувати ще раз
            </Button>
          </>
        ) : null}
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  content: { flex: 1, padding: 24, gap: 16 },
  header: { gap: 6 },
  permissionContent: { flex: 1, padding: 24, justifyContent: 'center', gap: 16 },
  cameraFrame: {
    flex: 1,
    minHeight: 360,
    borderRadius: 20,
    overflow: 'hidden',
  },
  state: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
  },
  viewfinder: {
    position: 'absolute',
    top: '24%',
    right: '14%',
    bottom: '24%',
    left: '14%',
    borderWidth: 2,
    borderColor: 'white',
    borderRadius: 18,
  },
});
