import { CameraView, useCameraPermissions } from 'expo-camera';
import { useTheme } from 'expo-router';
import { useEffect, useRef, useState } from 'react';
import {
  ActivityIndicator,
  AppState,
  Image,
  KeyboardAvoidingView,
  Linking,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Switch,
  Text,
  TextInput,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import {
  createMockRecognitionItems,
  MOCK_AI_NOTICE,
  type MockRecognitionItem,
} from '@/inventory/mock-recognition';

type InventoryStage = 'camera' | 'preview' | 'recognizing' | 'review' | 'confirmed';

export default function InventoryScreen() {
  const { colors } = useTheme();
  const [permission, requestPermission, refreshPermission] = useCameraPermissions();
  const cameraRef = useRef<CameraView>(null);
  const recognitionTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const [appState, setAppState] = useState(AppState.currentState);
  const [stage, setStage] = useState<InventoryStage>('camera');
  const [photoUri, setPhotoUri] = useState<string | null>(null);
  const [items, setItems] = useState<MockRecognitionItem[]>([]);
  const [cameraReady, setCameraReady] = useState(false);
  const [isCapturing, setIsCapturing] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

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

  useEffect(() => {
    return () => {
      if (recognitionTimerRef.current) {
        clearTimeout(recognitionTimerRef.current);
      }
    };
  }, []);

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

  async function handleCapture() {
    if (!cameraRef.current || !cameraReady || isCapturing || appState !== 'active') {
      return;
    }

    setIsCapturing(true);
    setMessage(null);

    try {
      const photo = await cameraRef.current.takePictureAsync({ quality: 0.75 });
      if (!photo?.uri) {
        throw new Error('Photo URI is missing');
      }

      setPhotoUri(photo.uri);
      setStage('preview');
      setCameraReady(false);
    } catch {
      setMessage('Не вдалося зробити фото. Перевірте камеру й спробуйте ще раз.');
    } finally {
      setIsCapturing(false);
    }
  }

  function handleRetake() {
    setPhotoUri(null);
    setItems([]);
    setMessage(null);
    setCameraReady(false);
    setStage('camera');
  }

  function handleRecognize() {
    if (!photoUri) {
      return;
    }

    setMessage(null);
    setStage('recognizing');

    recognitionTimerRef.current = setTimeout(() => {
      setItems(createMockRecognitionItems());
      setStage('review');
      recognitionTimerRef.current = null;
    }, 650);
  }

  function updateItem(
    id: string,
    patch: Partial<Pick<MockRecognitionItem, 'name' | 'included'>>
  ) {
    setItems((current) =>
      current.map((item) => (item.id === id ? { ...item, ...patch } : item))
    );
  }

  function handleStartOver() {
    setPhotoUri(null);
    setItems([]);
    setMessage(null);
    setCameraReady(false);
    setStage('camera');
  }

  const includedItems = items.filter((item) => item.included);
  const hasBlankIncludedName = includedItems.some((item) => item.name.trim().length === 0);
  const canConfirm = includedItems.length > 0 && !hasBlankIncludedName;
  const captureDisabled = !cameraReady || isCapturing || appState !== 'active';

  if (!permission) {
    return (
      <SafeAreaView
        edges={['left', 'right', 'bottom']}
        style={[styles.screen, { backgroundColor: colors.background }]}>
        <View style={styles.centeredState}>
          <ActivityIndicator />
          <Text style={[styles.body, { color: colors.text }]}>Перевіряємо доступ до камери…</Text>
        </View>
      </SafeAreaView>
    );
  }

  if (!permission.granted) {
    return (
      <SafeAreaView
        edges={['left', 'right', 'bottom']}
        style={[styles.screen, { backgroundColor: colors.background }]}>
        <ScrollView contentContainerStyle={styles.content}>
          <Text accessibilityRole="header" style={[styles.heading, { color: colors.text }]}>
            Камера потрібна для інвентарю
          </Text>
          <Text style={[styles.body, { color: colors.text }]}>
            Rechibox використовує камеру лише тоді, коли ви відкриваєте цей сценарій і робите фото речей.
          </Text>
          <Text style={[styles.note, { color: colors.text }]}>
            У цій демо-версії фото не завантажується на сервер і не зберігається після завершення локального сеансу.
          </Text>
          {message ? (
            <Text accessibilityLiveRegion="polite" style={[styles.error, { color: colors.text }]}>
              {message}
            </Text>
          ) : null}
          <Pressable
            accessibilityRole="button"
            onPress={permission.canAskAgain ? handleRequestPermission : handleOpenSettings}
            style={({ pressed }) => [
              styles.primaryButton,
              { backgroundColor: colors.text, opacity: pressed ? 0.75 : 1 },
            ]}>
            <Text style={[styles.primaryButtonText, { color: colors.background }]}>
              {permission.canAskAgain ? 'Надати доступ до камери' : 'Відкрити налаштування'}
            </Text>
          </Pressable>
        </ScrollView>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView
      edges={['left', 'right', 'bottom']}
      style={[styles.screen, { backgroundColor: colors.background }]}>
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        keyboardVerticalOffset={Platform.OS === 'ios' ? 88 : 0}
        style={styles.flex}>
        {stage === 'camera' ? (
          <View style={styles.flex}>
            <ScrollView
              contentContainerStyle={styles.cameraContent}
              keyboardShouldPersistTaps="handled">
              <Text accessibilityRole="header" style={[styles.heading, { color: colors.text }]}>
                Сфотографуйте речі
              </Text>
              <Text style={[styles.body, { color: colors.text }]}>
                Покладіть кілька речей у кадр. Після фото ви зможете перевірити результат перед підтвердженням.
              </Text>

              <View style={[styles.cameraFrame, { backgroundColor: colors.card }]}>
                {appState === 'active' ? (
                  <CameraView
                    ref={cameraRef}
                    facing="back"
                    mode="picture"
                    onCameraReady={() => {
                      setCameraReady(true);
                      setMessage(null);
                    }}
                    onMountError={({ message: cameraMessage }) => {
                      setCameraReady(false);
                      setMessage(`Камера не запустилась: ${cameraMessage}`);
                    }}
                    style={StyleSheet.absoluteFill}
                  />
                ) : (
                  <View style={styles.cameraPaused}>
                    <Text style={styles.cameraPausedText}>
                      Камера призупинена, поки застосунок неактивний.
                    </Text>
                  </View>
                )}
                {appState === 'active' ? (
                  <View pointerEvents="none" style={styles.viewfinder}>
                    <Text style={styles.viewfinderLabel}>Помістіть речі всередину рамки</Text>
                  </View>
                ) : null}
              </View>

              <Text style={[styles.note, { color: colors.text }]}>{MOCK_AI_NOTICE}</Text>
              {message ? (
                <Text accessibilityLiveRegion="polite" style={[styles.error, { color: colors.text }]}>
                  {message}
                </Text>
              ) : null}
            </ScrollView>

            <View
              style={[
                styles.cameraActionBar,
                { backgroundColor: colors.background, borderTopColor: colors.border },
              ]}>
              <Pressable
                accessibilityRole="button"
                accessibilityState={{ disabled: captureDisabled }}
                disabled={captureDisabled}
                onPress={handleCapture}
                style={({ pressed }) => [
                  styles.primaryButton,
                  {
                    backgroundColor: colors.text,
                    opacity: captureDisabled ? 0.4 : pressed ? 0.75 : 1,
                  },
                ]}>
                <Text style={[styles.primaryButtonText, { color: colors.background }]}>
                  {isCapturing ? 'Фотографуємо…' : cameraReady ? 'Зробити фото' : 'Готуємо камеру…'}
                </Text>
              </Pressable>
            </View>
          </View>
        ) : (
          <ScrollView
            contentContainerStyle={styles.content}
            keyboardShouldPersistTaps="handled">
            {stage === 'preview' && photoUri ? (
              <>
                <Text accessibilityRole="header" style={[styles.heading, { color: colors.text }]}>
                  Перевірте фото
                </Text>
                <Image
                  accessibilityLabel="Фото речей для інвентарю"
                  accessibilityRole="image"
                  source={{ uri: photoUri }}
                  style={[styles.photo, { backgroundColor: colors.card }]}
                />
                <Text style={[styles.note, { color: colors.text }]}>{MOCK_AI_NOTICE}</Text>
                <Pressable
                  accessibilityRole="button"
                  onPress={handleRecognize}
                  style={({ pressed }) => [
                    styles.primaryButton,
                    { backgroundColor: colors.text, opacity: pressed ? 0.75 : 1 },
                  ]}>
                  <Text style={[styles.primaryButtonText, { color: colors.background }]}>
                    Розпізнати речі
                  </Text>
                </Pressable>
                <Pressable
                  accessibilityRole="button"
                  onPress={handleRetake}
                  style={({ pressed }) => [
                    styles.secondaryButton,
                    { borderColor: colors.border, opacity: pressed ? 0.7 : 1 },
                  ]}>
                  <Text style={[styles.secondaryButtonText, { color: colors.text }]}>Перезняти</Text>
                </Pressable>
              </>
            ) : null}

            {stage === 'recognizing' ? (
              <View style={styles.centeredState}>
                <ActivityIndicator />
                <Text accessibilityLiveRegion="polite" style={[styles.body, { color: colors.text }]}>
                  Готуємо демо-результат…
                </Text>
                <Text style={[styles.note, { color: colors.text }]}>{MOCK_AI_NOTICE}</Text>
              </View>
            ) : null}

            {stage === 'review' ? (
              <>
                <Text accessibilityRole="header" style={[styles.heading, { color: colors.text }]}>
                  Перевірте розпізнані речі
                </Text>
                <Text style={[styles.body, { color: colors.text }]}>
                  Виправте назви або вимкніть речі, які не потрібно додавати.
                </Text>
                <Text style={[styles.note, { color: colors.text }]}>{MOCK_AI_NOTICE}</Text>

                {items.map((item) => {
                  const confidencePercent = Math.round(item.confidence * 100);
                  const isUncertain = item.confidence < 0.6;

                  return (
                    <View
                      key={item.id}
                      style={[
                        styles.itemCard,
                        { backgroundColor: colors.card, borderColor: colors.border },
                      ]}>
                      <View style={styles.itemRow}>
                        <TextInput
                          accessibilityLabel="Назва розпізнаної речі"
                          editable={item.included}
                          onChangeText={(name) => updateItem(item.id, { name })}
                          placeholder="Назва речі"
                          placeholderTextColor={colors.border}
                          style={[
                            styles.input,
                            {
                              borderColor: colors.border,
                              color: colors.text,
                              opacity: item.included ? 1 : 0.45,
                            },
                          ]}
                          value={item.name}
                        />
                        <Switch
                          accessibilityLabel={`Додати ${item.name || 'цю річ'} до інвентарю`}
                          onValueChange={(included) => updateItem(item.id, { included })}
                          value={item.included}
                        />
                      </View>
                      <View style={styles.itemMetaRow}>
                        <Text style={[styles.confidence, { color: colors.text }]}>
                          {confidencePercent}% впевненість
                        </Text>
                        {isUncertain ? (
                          <Text style={[styles.uncertain, { color: colors.text }]}>Перевірте назву</Text>
                        ) : null}
                      </View>
                    </View>
                  );
                })}

                {hasBlankIncludedName ? (
                  <Text accessibilityLiveRegion="polite" style={[styles.error, { color: colors.text }]}>
                    Дайте назву кожній речі, яку хочете підтвердити.
                  </Text>
                ) : null}
                <Pressable
                  accessibilityRole="button"
                  accessibilityState={{ disabled: !canConfirm }}
                  disabled={!canConfirm}
                  onPress={() => setStage('confirmed')}
                  style={({ pressed }) => [
                    styles.primaryButton,
                    {
                      backgroundColor: colors.text,
                      opacity: !canConfirm ? 0.4 : pressed ? 0.75 : 1,
                    },
                  ]}>
                  <Text style={[styles.primaryButtonText, { color: colors.background }]}>
                    Підтвердити {includedItems.length} {includedItems.length === 1 ? 'річ' : 'речі'}
                  </Text>
                </Pressable>
                <Pressable
                  accessibilityRole="button"
                  onPress={handleRetake}
                  style={({ pressed }) => [
                    styles.secondaryButton,
                    { borderColor: colors.border, opacity: pressed ? 0.7 : 1 },
                  ]}>
                  <Text style={[styles.secondaryButtonText, { color: colors.text }]}>Зробити інше фото</Text>
                </Pressable>
              </>
            ) : null}

            {stage === 'confirmed' ? (
              <>
                <Text accessibilityRole="header" style={[styles.heading, { color: colors.text }]}>
                  Інвентар підтверджено локально
                </Text>
                <Text accessibilityLiveRegion="polite" style={[styles.body, { color: colors.text }]}>
                  Це демонстраційний результат. Дані не відправлені в backend і не збережені після цього сеансу.
                </Text>
                <View
                  style={[
                    styles.resultCard,
                    { backgroundColor: colors.card, borderColor: colors.border },
                  ]}>
                  {includedItems.map((item) => (
                    <Text key={item.id} style={[styles.resultItem, { color: colors.text }]}>
                      • {item.name.trim()}
                    </Text>
                  ))}
                </View>
                <Pressable
                  accessibilityRole="button"
                  onPress={handleStartOver}
                  style={({ pressed }) => [
                    styles.primaryButton,
                    { backgroundColor: colors.text, opacity: pressed ? 0.75 : 1 },
                  ]}>
                  <Text style={[styles.primaryButtonText, { color: colors.background }]}>
                    Додати ще фото
                  </Text>
                </Pressable>
              </>
            ) : null}
          </ScrollView>
        )}
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  screen: { flex: 1 },
  content: { padding: 24, gap: 16 },
  cameraContent: { padding: 24, paddingBottom: 20, gap: 16 },
  cameraActionBar: {
    borderTopWidth: StyleSheet.hairlineWidth,
    paddingHorizontal: 24,
    paddingTop: 12,
    paddingBottom: 12,
  },
  heading: { fontSize: 26, fontWeight: '700' },
  body: { fontSize: 16, lineHeight: 24 },
  note: { fontSize: 14, lineHeight: 21 },
  error: { fontSize: 14, lineHeight: 21, fontWeight: '600' },
  centeredState: {
    flexGrow: 1,
    minHeight: 260,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
    gap: 16,
  },
  cameraFrame: {
    width: '100%',
    aspectRatio: 3 / 4,
    borderRadius: 20,
    overflow: 'hidden',
  },
  cameraPaused: {
    ...StyleSheet.absoluteFill,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
    backgroundColor: '#202020',
  },
  cameraPausedText: {
    color: 'white',
    fontSize: 16,
    lineHeight: 24,
    textAlign: 'center',
  },
  viewfinder: {
    position: 'absolute',
    top: '14%',
    right: '10%',
    bottom: '14%',
    left: '10%',
    borderWidth: 2,
    borderColor: 'white',
    borderRadius: 18,
    justifyContent: 'flex-end',
    alignItems: 'center',
    padding: 12,
  },
  viewfinderLabel: {
    color: 'white',
    fontSize: 14,
    fontWeight: '600',
    textAlign: 'center',
    backgroundColor: 'rgba(0, 0, 0, 0.45)',
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 8,
  },
  photo: {
    width: '100%',
    aspectRatio: 3 / 4,
    borderRadius: 20,
  },
  primaryButton: {
    minHeight: 52,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 16,
    borderRadius: 12,
  },
  primaryButtonText: { fontSize: 16, fontWeight: '600', textAlign: 'center' },
  secondaryButton: {
    minHeight: 52,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 16,
    borderRadius: 12,
    borderWidth: 1,
  },
  secondaryButtonText: { fontSize: 16, fontWeight: '600', textAlign: 'center' },
  itemCard: {
    padding: 12,
    gap: 8,
    borderWidth: StyleSheet.hairlineWidth,
    borderRadius: 12,
  },
  itemRow: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  itemMetaRow: { flexDirection: 'row', alignItems: 'center', gap: 10, flexWrap: 'wrap' },
  confidence: { fontSize: 13, lineHeight: 18, fontWeight: '600' },
  uncertain: { fontSize: 13, lineHeight: 18 },
  input: {
    flex: 1,
    minHeight: 44,
    borderWidth: 1,
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 8,
    fontSize: 16,
  },
  resultCard: {
    padding: 18,
    gap: 10,
    borderWidth: StyleSheet.hairlineWidth,
    borderRadius: 12,
  },
  resultItem: { fontSize: 16, lineHeight: 24 },
});
