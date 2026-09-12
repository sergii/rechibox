import { useImage, type SkImage } from '@shopify/react-native-skia';
import { Asset } from 'expo-asset';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { models, useObjectDetector } from 'react-native-executorch';
import type { ImageBuffer } from 'react-native-executorch/cv';

import type {
  InventoryRecognitionItem,
  InventoryRecognitionResult,
} from '@/inventory/inventory-detection';

const MODEL_ASSET = require('../../assets/models/ssdlite320_mobilenet_v3_large_xnnpack_fp32.pte');
const BASE_MODEL = models.objectDetection.SSDLITE320_MOBILENET_V3_LARGE.XNNPACK_FP32;

const UKRAINIAN_LABELS: Record<string, string> = {
  backpack: 'Рюкзак',
  bed: 'Ліжко',
  book: 'Книга',
  bottle: 'Пляшка',
  bowl: 'Миска',
  chair: 'Стілець',
  clock: 'Годинник',
  couch: 'Диван',
  cup: 'Чашка',
  'cell phone': 'Телефон',
  'dining table': 'Стіл',
  handbag: 'Сумка',
  keyboard: 'Клавіатура',
  laptop: 'Ноутбук',
  microwave: 'Мікрохвильова піч',
  mouse: 'Миша',
  oven: 'Духовка',
  refrigerator: 'Холодильник',
  remote: 'Пульт',
  scissors: 'Ножиці',
  suitcase: 'Валіза',
  teddy_bear: 'Мʼяка іграшка',
  toaster: 'Тостер',
  toothbrush: 'Зубна щітка',
  tv: 'Телевізор',
  vase: 'Ваза',
};

function skImageToBuffer(image: SkImage): ImageBuffer {
  const pixels = image.readPixels();
  if (!(pixels instanceof Uint8Array)) {
    throw new Error('Не вдалося прочитати пікселі фотографії.');
  }

  return {
    data: pixels,
    width: image.width(),
    height: image.height(),
    format: 'rgba',
    layout: 'hwc',
  };
}

function localModelPath(uri: string): string {
  return decodeURI(uri.replace(/^file:\/\//, ''));
}

function displayName(label: string): string {
  return UKRAINIAN_LABELS[label] ?? label.replaceAll('_', ' ');
}

export function useInventoryDetector(photoUri: string | null) {
  const image = useImage(photoUri);
  const [modelPath, setModelPath] = useState<string | null>(null);
  const [assetError, setAssetError] = useState<Error | null>(null);

  useEffect(() => {
    let active = true;

    async function prepareBundledModel() {
      try {
        const asset = Asset.fromModule(MODEL_ASSET);
        const downloaded = await asset.downloadAsync();
        const uri = downloaded.localUri ?? downloaded.uri;
        if (!uri) {
          throw new Error('Bundled AI model has no local URI.');
        }
        if (active) {
          setModelPath(localModelPath(uri));
          setAssetError(null);
        }
      } catch (error) {
        if (active) {
          setAssetError(error instanceof Error ? error : new Error(String(error)));
        }
      }
    }

    void prepareBundledModel();

    return () => {
      active = false;
    };
  }, []);

  const model = useMemo(
    () => ({ ...BASE_MODEL, modelPath: modelPath ?? '' }),
    [modelPath]
  );

  const detector = useObjectDetector(model, {
    preventLoad: !modelPath || !photoUri,
  });

  const recognize = useCallback(async (): Promise<InventoryRecognitionResult> => {
    if (!image) {
      throw new Error('Фотографія ще не готова для локального AI.');
    }
    if (!detector.detectObjects) {
      throw new Error('Локальна AI-модель ще не готова.');
    }

    const buffer = skImageToBuffer(image);
    const startedAt = Date.now();
    const detections = await detector.detectObjects(buffer, {
      confidenceThreshold: 0.4,
      iouThreshold: 0.55,
    });
    const inferenceMs = Date.now() - startedAt;

    const items: InventoryRecognitionItem[] = detections
      .filter((detection) => detection.label !== 'N/A')
      .map((detection, index) => {
        const box = detection.box;
        if (box.format !== 'xyxy') {
          throw new Error(`Unexpected detection box format: ${box.format}`);
        }

        return {
          id: `${detection.label}-${index}`,
          name: displayName(String(detection.label)),
          sourceLabel: String(detection.label),
          confidence: detection.confidence,
          included: detection.label !== 'person',
          box: {
            xmin: box.xmin,
            ymin: box.ymin,
            xmax: box.xmax,
            ymax: box.ymax,
          },
        };
      });

    return {
      items,
      imageWidth: buffer.width,
      imageHeight: buffer.height,
      inferenceMs,
    };
  }, [detector.detectObjects, image]);

  return {
    isReady: Boolean(image && detector.isReady),
    modelReady: detector.isReady,
    photoReady: Boolean(image),
    downloadProgress: detector.downloadProgress,
    error: assetError ?? detector.error ?? null,
    recognize,
  };
}
