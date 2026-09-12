import { useImage } from '@shopify/react-native-skia';
import { CameraView, useCameraPermissions } from 'expo-camera';
import { models, useObjectDetector } from 'react-native-executorch';
import { useEffect, useRef, useState } from 'react';
import type { ColorValue } from 'react-native';
import {
  ActivityIndicator,
  AppState,
  Image,
  KeyboardAvoidingView,
  Linking,
  Platform,
  ScrollView,
  StyleSheet,
  Text as RNText,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Switch } from '@/components/ui/switch';
import { Text } from '@/components/ui/text';
import { useThemeColors } from '@/components/ui/theme-provider';
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
  backgroundColor: ColorValue;
};

const LOCAL_AI_NOTICE =
  'Розпізнавання виконується локально на пристрої. Фото не завантажується на сервер.';
const DETECTOR_MODEL_NAME = 'SSDLite320 MobileNetV3 Large · XNNPACK FP32';
const CONFIDENCE_THRESHOLD = 0.45;
const IOU_THRESHOLD = 0.55;

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
                <RNText numberOfLines={1} style={styles.detectionLabel}>
                  {item.name} {Math.round(item.confidence * 100)}%
                </RNText>
              </View>
            );
          })}
        </View>
      ) : null}
    </View>
  );
}

function ErrorText({ children }: { children: string }) {
  return (
    <Text accessibilityLiveRegion="polite" className="text-destructive leading-5" variant="small">
      {children}
    </Text>
  );
}

function LocalNotice() {
  return <Text variant="muted">{LOCAL_AI_NOTICE}</Text>;
}

export default function InventoryScreen() {
  const colors = useThemeColors();
  const [permission, requestPermission, refreshPermission] = useCameraPermissions();
  const cameraRef = useRef<CameraView>(null);
  const [appState, setAppState] = useState(AppState.currentState);
  const [stage, setStage] = useState<InventoryStage>('camera');
  const [photoUri, setPhotoUri] = useState<string | null>(null);
  const [items, setItems] = useState<InventoryRecognitionItem[]>([]);
  const [cameraReady, setCameraReady] = useState(false);
  const [isCapturing, setIsCapturing] = useState(false);
  const [recognitionMs, setRecognitionMs] = useState<number | null>(null);
  const [debugMode, setDebugMode] = useState(false);
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
          confidenceThreshold: CONFIDENCE_THRESHOLD,
          iouThreshold: IOU_THRESHOLD,
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
        <ScrollView contentContainerStyle={styles.content}>
          <Text accessibilityRole="header" variant="h2">
            Камера потрібна для інвентарю
          </Text>
          <Text>
            Rechibox використовує камеру лише тоді, коли ви відкриваєте цей сценарій і робите фото
            речей.
          </Text>
          <LocalNotice />
          {message ? <ErrorText>{message}</ErrorText> : null}
          <Button
            onPress={permission.canAskAgain ? handleRequestPermission : handleOpenSettings}
            size="lg">
            {permission.canAskAgain ? 'Надати доступ до камери' : 'Відкрити налаштування'}
          </Button>
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
              <Text accessibilityRole="header" variant="h2">
                Сфотографуйте речі
              </Text>
              <Text>
                Покладіть кілька речей у кадр. Після фото ви зможете перевірити результат перед
                підтвердженням.
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
                    <RNText style={styles.cameraPausedText}>
                      Камера призупинена, поки застосунок неактивний.
                    </RNText>
                  </View>
                )}
                {appState === 'active' ? (
                  <View pointerEvents="none" style={styles.viewfinder}>
                    <RNText style={styles.viewfinderLabel}>Помістіть речі всередину рамки</RNText>
                  </View>
                ) : null}
              </View>

              <LocalNotice />
              {!detector.isReady && !detector.error ? (
                <Text accessibilityLiveRegion="polite" variant="muted">
                  Завантажуємо AI-модель для першого запуску: {modelProgress}%
                </Text>
              ) : null}
              {detector.error ? (
                <ErrorText>AI-модель не завантажилась. Перевірте мережу та перезапустіть екран.</ErrorText>
              ) : null}
              {message ? <ErrorText>{message}</ErrorText> : null}
            </ScrollView>

            <View
              style={[
                styles.cameraActionBar,
                { backgroundColor: colors.background, borderTopColor: colors.border },
              ]}>
              <Button
                accessibilityState={{ disabled: captureDisabled }}
                disabled={captureDisabled}
                loading={isCapturing}
                onPress={handleCapture}
                size="lg"
                variant="default">
                {isCapturing ? 'Фотографуємо…' : cameraReady ? 'Зробити фото' : 'Готуємо камеру…'}
              </Button>
            </View>
          </View>
        ) : (
          <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
            {stage === 'preview' && photoUri ? (
              <>
                <Text accessibilityRole="header" variant="h2">
                  Перевірте фото
                </Text>
                <PhotoWithDetections
                  backgroundColor={colors.card}
                  imageHeight={photoHeight}
                  imageWidth={photoWidth}
                  items={[]}
                  uri={photoUri}
                />
                <LocalNotice />
                {!detector.isReady && !detector.error ? (
                  <Text accessibilityLiveRegion="polite" variant="muted">
                    Готуємо AI-модель: {modelProgress}%
                  </Text>
                ) : null}
                {detector.error ? (
                  <ErrorText>
                    AI-модель недоступна. Перевірте мережу та відкрийте цей екран ще раз.
                  </ErrorText>
                ) : null}
                {message ? <ErrorText>{message}</ErrorText> : null}
                <Button
                  accessibilityState={{ disabled: recognizeDisabled }}
                  disabled={recognizeDisabled}
                  onPress={() => void handleRecognize()}
                  size="lg">
                  {!skiaImage
                    ? 'Готуємо фото…'
                    : !aiReady
                      ? `Готуємо AI… ${modelProgress}%`
                      : 'Розпізнати речі'}
                </Button>
                <Button onPress={handleRetake} size="lg" variant="outline">
                  Перезняти
                </Button>
              </>
            ) : null}

            {stage === 'recognizing' ? (
              <View style={styles.centeredState}>
                <ActivityIndicator />
                <Text accessibilityLiveRegion="polite">Розпізнаємо речі на пристрої…</Text>
                <LocalNotice />
              </View>
            ) : null}

            {stage === 'review' && photoUri ? (
              <>
                <Text accessibilityRole="header" variant="h2">
                  Перевірте розпізнані речі
                </Text>
                <Text>Виправте назви або вимкніть речі, які не потрібно додавати.</Text>

                <Card className="p-4">
                  <View style={styles.toggleRow}>
                    <View style={styles.toggleCopy}>
                      <Text variant="small">Debug mode</Text>
                      <Text variant="muted">Показувати сирі дані detector-а</Text>
                    </View>
                    <Switch
                      accessibilityLabel="Debug mode"
                      onValueChange={setDebugMode}
                      value={debugMode}
                    />
                  </View>
                </Card>

                <PhotoWithDetections
                  backgroundColor={colors.card}
                  imageHeight={photoHeight}
                  imageWidth={photoWidth}
                  items={items}
                  uri={photoUri}
                />

                {debugMode ? (
                  <Card className="gap-1.5 p-4">
                    <Text variant="small">Detector debug</Text>
                    <RNText style={[styles.debugCode, { color: colors.foreground }]}>model: {DETECTOR_MODEL_NAME}</RNText>
                    <RNText style={[styles.debugCode, { color: colors.foreground }]}>image: {photoWidth}×{photoHeight}</RNText>
                    <RNText style={[styles.debugCode, { color: colors.foreground }]}>inference: {recognitionMs ?? '—'} ms</RNText>
                    <RNText style={[styles.debugCode, { color: colors.foreground }]}>detections: {items.length}</RNText>
                    <RNText style={[styles.debugCode, { color: colors.foreground }]}>confidence threshold: {CONFIDENCE_THRESHOLD}</RNText>
                    <RNText style={[styles.debugCode, { color: colors.foreground }]}>IoU threshold: {IOU_THRESHOLD}</RNText>
                    {items.map((item, index) => (
                      <RNText
                        key={`debug-${item.id}`}
                        style={[styles.debugCode, { color: colors.foreground }]}>
                        {index + 1}. {item.sourceLabel} · {(item.confidence * 100).toFixed(1)}% · [{item.box.xmin.toFixed(0)}, {item.box.ymin.toFixed(0)}, {item.box.xmax.toFixed(0)}, {item.box.ymax.toFixed(0)}]
                      </RNText>
                    ))}
                  </Card>
                ) : null}

                {items.length === 0 ? (
                  <Text accessibilityLiveRegion="polite" variant="muted">
                    Модель не знайшла впевнених об’єктів. Поточний detector розпізнає базові
                    категорії COCO, тому специфічні речі може пропускати.
                  </Text>
                ) : null}

                {items.map((item) => {
                  const confidencePercent = Math.round(item.confidence * 100);
                  const isUncertain = item.confidence < 0.6;

                  return (
                    <Card className="gap-2 p-3" key={item.id}>
                      <View style={styles.itemRow}>
                        <View style={styles.inputWrap}>
                          <Input
                            accessibilityLabel="Назва розпізнаної речі"
                            className={item.included ? undefined : 'opacity-50'}
                            editable={item.included}
                            onChangeText={(name) => updateItem(item.id, { name })}
                            placeholder="Назва речі"
                            value={item.name}
                          />
                        </View>
                        <Switch
                          accessibilityLabel={`Додати ${item.name || 'цю річ'} до інвентарю`}
                          onValueChange={(included) => updateItem(item.id, { included })}
                          value={item.included}
                        />
                      </View>
                      <View style={styles.itemMetaRow}>
                        <Text variant="small">{confidencePercent}% впевненість</Text>
                        {isUncertain ? (
                          <Text className="text-amber-600 dark:text-amber-400" variant="muted">
                            Перевірте назву
                          </Text>
                        ) : null}
                      </View>
                    </Card>
                  );
                })}

                {hasBlankIncludedName ? (
                  <ErrorText>Дайте назву кожній речі, яку хочете підтвердити.</ErrorText>
                ) : null}
                <Button
                  accessibilityState={{ disabled: !canConfirm }}
                  disabled={!canConfirm}
                  onPress={() => setStage('confirmed')}
                  size="lg">
                  {`Підтвердити ${includedItems.length} ${
                    includedItems.length === 1 ? 'річ' : 'речі'
                  }`}
                </Button>
                <Button onPress={handleRetake} size="lg" variant="outline">
                  Зробити інше фото
                </Button>
              </>
            ) : null}

            {stage === 'confirmed' ? (
              <>
                <Text accessibilityRole="header" variant="h2">
                  Інвентар підтверджено локально
                </Text>
                <Text accessibilityLiveRegion="polite">
                  Речі розпізнані на цьому пристрої. Дані не відправлені в backend і не збережені
                  після цього сеансу.
                </Text>
                <Card className="gap-2 p-4">
                  {includedItems.map((item) => (
                    <Text key={item.id}>• {item.name.trim()}</Text>
                  ))}
                </Card>
                <Button onPress={handleStartOver} size="lg">
                  Додати ще фото
                </Button>
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
  toggleRow: {
    minHeight: 44,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  toggleCopy: { flex: 1, gap: 4 },
  itemRow: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  inputWrap: { flex: 1 },
  itemMetaRow: { flexDirection: 'row', alignItems: 'center', gap: 10, flexWrap: 'wrap' },
  debugCode: {
    fontFamily: Platform.select({ ios: 'Menlo', android: 'monospace' }),
    fontSize: 12,
    lineHeight: 18,
  },
});
