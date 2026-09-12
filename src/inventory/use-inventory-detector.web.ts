import { useCallback } from 'react';

import type { InventoryRecognitionResult } from '@/inventory/inventory-detection';

export function useInventoryDetector(photoUri: string | null) {
  const recognize = useCallback(async (): Promise<InventoryRecognitionResult> => {
    throw new Error('Локальне AI-розпізнавання доступне лише в нативному development build.');
  }, []);

  return {
    isReady: false,
    modelReady: false,
    photoReady: Boolean(photoUri),
    downloadProgress: 0,
    error: null as Error | null,
    recognize,
  };
}
