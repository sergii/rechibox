import { useImage } from '@shopify/react-native-skia';
import { CameraView, useCameraPermissions } from 'expo-camera';
import { useTheme } from 'expo-router';
import { models, useObjectDetector } from 'react-native-executorch';
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
  createInventoryRecognitionItems,
  type InventoryRecognitionItem,
} from '@/inventory/detection';

type InventoryStage = 'camera' | 'preview' | 'recognizing' | 'review' | 'confirmed';

type PhotoWithDetectionsProps = {
  uri: string;
  items: InventoryRecognitionItem[];
  imageWidth: number;
  imageHeight: number;
  backgroundColor: string;
};

const LOCAL_AI_NOTICE =
  'Розпізнавання виконується локально на пристрої. Фото не завантажується на сервер.';

const DETECTOR_MODEL = models.objectDetection.SSDLITE320_MOBILENET_V3_LARGE.XNNPACK_FP32;

function PhotoWithDetections({
  uri,
  items,
  imageWidth,
  imageHeight,
  backgroundColor,
}: PhotoWithDetectionsProps) {
  const [layout, setLayout] = useState({ width: 0, height: 0 });
  const scale =
    imageWidth > 0 && imageHeight > 0 && layout.width > 0 && layout.height > 0
      ? Math.min(layout.width / imageWidth, layout.height / imageHeight)
      : 0;
  const displayedWidth = imageWidth * scale;
  const displayedHeight = imageHeight * scale;
  const offsetX = (layout.width - displayedWidth) / 2;
  const offsetY = (layout.height - displayedHeight) / 2;

  return (
    <View
      onLayout={({ nativeEvent: { layout: nextLayout } }) =>
        setLayout({ width: nextLayout.width, height: nextLayout.height })
      }
      style={[styles.photoFrame, { backgroundColor }]}>
      <Image
        accessibilityLabel="Фото речей для інвентарю"
        accessibilityRole="image"
        resizeMode="contain"
        source={{ uri }}
        style={StyleSheet.absoluteFill}
      />
      {scale > 0 ? (
        <View pointerEvents="none" style={StyleSheet.absoluteFill}>
          {items.map((item) => {
            const rawLeft = offsetX + item.box.xmin * scale;
            const rawTop = offsetY + item.box.ymin * scale;
            const rawRight = offsetX + item.box.xmax * scale;
            const rawBottom = offsetY + item.box.ymax * scale;
            const left = Math.max(0, rawLeft);
            const top = Math.max(0, rawTop);
            const right = Math.min(layout.width, rawRight);
            const bottom = Math.min(layout.height, rawBottom);
            const width = Math.max(1, right - left);
            const height = Math.max(1, bottom - top);

            return (
              <View
                key={item.id}
                style={[
                  styles.detectionBox,
                  {
                    left,
                    top,
                    width,
                    height,
                    opacity: item.included ? 1 : 0.35,
                  },
                ]}>
                <Text numberOfLines={1} style={styles.detectionLabel}>
                  {item.name} {Math.round(item.confidence * 100)}%
                </Text>
              </View>
            );
          })}
        </View>
      ) : null}
    </View>
  );
}

export default function InventoryScreen() {
  const { colors } = useTheme();
  const [permission, requestPermission, refreshPermission] = useCameraPermissions();
  const cameraRef = useRef<CameraView>(null);
  const [appState, setAppState] = useState(AppState.currentState);
  const [stage, setStage] = useState<InventoryStage>('camera');
  const [photoUri, setPhotoUri] = useState<string | null>(null);
  const [items, setItems] = useState<InventoryRecognitionItem[]>([]);
  const [cameraReady, setCameraReady] = useState(false);
  const [isCapturing, setIsCapturing] = useState(false);
  const [recognitionMs, setRecognitionMs] = useState<number | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  const skiaImage = useImage(photoUri);
  const detector = useObjectDetector(DETECTOR_MODEL);
  const aiReady = detector.isReady && Boolean(detector.detectObjects);
  const modelProgress = Math.round(detector.downloadProgress);

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
      setItems([]);
      setRecognitionMs(null);
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
    setRecognitionMs(null);
    setMessage(null);
    setCameraReady(false);
    setStage('camera');
  }

  async function handleRecognize() {
    if (!photoUri || !skiaImage || !detector.detectObjects) {
      return;
    }

    setMessage(null);
    setStage('recognizing');

    try {
      const pixels = skiaImage.readPixels();
      if (!pixels || !(pixels instanceof Uint8Array)) {
        throw new Error('Could not decode image pixels');
      }

      const startedAt = Date.now();
      const detections = await detector.detectObjects(
        {
          data: pixels,
          width: skiaImage.width(),
          height: skiaImage.height(),
          format: 'rgba',
          layout: 'hwc',
        },
        {
          confidenceThreshold: 0.45,
          iouThreshold: 0.55,
        }
      );

      setRecognitionMs(Date.now() - startedAt);
      setItems(
        createInventoryRecognitionItems(
          detections.map((detection) => ({
            label: String(detection.label),
            confidence: detection.confidence,
            box: {
              xmin: detection.box.xmin,
              ymin: detection.box.ymin,
              xmax: detection.box.xmax,
              ymax: detection.box.ymax,
            },
          }))
        )
      );
      setStage('review');
    } catch (error) {
      console.error('On-device object detection failed', error);
      setMessage('Не вдалося виконати локальне AI-розпізнавання. Спробуйте ще раз.');
      setStage('preview');
    }
  }

  function updateItem(
    id: string,
    patch: Partial<Pick<InventoryRecognitionItem, 'name' | 'included'>>
  ) {
    setItems((current) =>
      current.map((item) => (item.id === id ? { ...item, ...patch } : item))
    );
  }

  function handleStartOver() {
    setPhotoUri(null);
    setItems([]);
    setRecognitionMs(null);
    setMessage(null);
    setCameraReady(false);
    setStage('camera');
  }

  const includedItems = items.filter((item) => item.included);
  const hasBlankIncludedName = includedItems.some((item) => item.name.trim().length === 0);
  const canConfirm = includedItems.length > 0 && !hasBlankIncludedName;
  const captureDisabled = !cameraReady || isCapturing || appState !== 'active';
  const photoWidth = skiaImage?.width() ?? 0;
  const photoHeight = skiaImage?.height() ?? 0;
  const recognizeDisabled = !skiaImage || !aiReady || Boolean(detector.error);

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
          <Text style={[styles.note, { color: colors.text }]}>{LOCAL_AI_NOTICE}</Text>
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

              <Text style={[styles.note, { color: colors.text }]}>{LOCAL_AI_NOTICE}</Text>
              {!detector.isReady && !detector.error ? (
                <Text accessibilityLiveRegion="polite" style={[styles.note, { color: colors.text }]}>
                  Завантажуємо AI-модель для першого запуску: {modelProgress}%
                </Text>
              ) : null}
              {detector.error ? (
                <Text accessibilityLiveRegion="polite" style={[styles.error, { color: colors.text }]}>
                  AI-модель не завантажилась. Перевірте мережу та перезапустіть екран.
                </Text>
              ) : null}
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
                <PhotoWithDetections
                  backgroundColor={colors.card}
                  imageHeight={photoHeight}
                  imageWidth={photoWidth}
                  items={[]}
                  uri={photoUri}
                />
                <Text style={[styles.note, { color: colors.text }]}>{LOCAL_AI_NOTICE}</Text>
                {!detector.isReady && !detector.error ? (
                  <Text accessibilityLiveRegion="polite" style={[styles.note, { color: colors.text }]}>
                    Готуємо AI-модель: {modelProgress}%
                  </Text>
                ) : null}
                {detector.error ? (
                  <Text accessibilityLiveRegion="polite" style={[styles.error, { color: colors.text }]}>
                    AI-модель недоступна. Перевірте мережу та відкрийте цей екран ще раз.
                  </Text>
                ) : null}
                {message ? (
                  <Text accessibilityLiveRegion="polite" style={[styles.error, { color: colors.text }]}>
                    {message}
                  </Text>
                ) : null}
                <Pressable
                  accessibilityRole="button"
                  accessibilityState={{ disabled: recognizeDisabled }}
                  disabled={recognizeDisabled}
                  onPress={() => void handleRecognize()}
                  style={({ pressed }) => [
                    styles.primaryButton,
                    {
                      backgroundColor: colors.text,
                      opacity: recognizeDisabled ? 0.4 : pressed ? 0.75 : 1,
                    },
                  ]}>
                  <Text style={[styles.primaryButtonText, { color: colors.background }]}>
                    {!skiaImage
                      ? 'Готуємо фото…'
                      : !aiReady
                        ? `Готуємо AI… ${modelProgress}%`
                        : 'Розпізнати речі'}
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
                  Розпізнаємо речі на пристрої…
                </Text>
                <Text style={[styles.note, { color: colors.text }]}>{LOCAL_AI_NOTICE}</Text>
              </View>
            ) : null}

            {stage === 'review' && photoUri ? (
              <>
                <Text accessibilityRole="header" style={[styles.heading, { color: colors.text }]}>
                  Перевірте розпізнані речі
                </Text>
                <Text style={[styles.body, { color: colors.text }]}>
                  Виправте назви або вимкніть речі, які не потрібно додавати.
                </Text>
                <PhotoWithDetections
                  backgroundColor={colors.card}
                  imageHeight={photoHeight}
                  imageWidth={photoWidth}
                  items={items}
                  uri={photoUri}
                />
                {recognitionMs !== null ? (
                  <Text style={[styles.note, { color: colors.text }]}>
                    Локальне розпізнавання: {recognitionMs} мс · знайдено {items.length}
                  </Text>
                ) : null}
                {items.length === 0 ? (
                  <Text accessibilityLiveRegion="polite" style={[styles.note, { color: colors.text }]}>
                    Модель не знайшла впевнених об’єктів. Поточний detector розпізнає базові категорії COCO, тому специфічні речі може пропускати.
                  </Text>
                ) : null}

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
                  Речі розпізнані на цьому пристрої. Дані не відправлені в backend і не збережені після цього сеансу.
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
  photoFrame: {
    width: '100%',
    aspectRatio: 3 / 4,
    borderRadius: 20,
    overflow: 'hidden',
  },
  detectionBox: {
    position: 'absolute',
    borderWidth: 2,
    borderColor: '#30D158',
  },
  detectionLabel: {
    alignSelf: 'flex-start',
    maxWidth: 180,
    color: 'white',
    backgroundColor: 'rgba(0, 0, 0, 0.75)',
    fontSize: 12,
    lineHeight: 16,
    fontWeight: '700',
    paddingHorizontal: 5,
    paddingVertical: 2,
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
