export type MockRecognitionItem = {
  id: string;
  name: string;
  confidence: number;
  included: boolean;
};

export const MOCK_AI_NOTICE =
  'Демонстрація: фото не надсилається на сервер і фактично не аналізується AI. Результат нижче — фіксований локальний mock, незалежний від знімка.';

const MOCK_RECOGNITION_FIXTURES: Omit<MockRecognitionItem, 'included'>[] = [
  { id: 'lamp', name: 'Настільна лампа', confidence: 0.94 },
  { id: 'extension-cord', name: 'Подовжувач', confidence: 0.86 },
  { id: 'usb-c-cable', name: 'USB-C кабель', confidence: 0.72 },
  { id: 'unknown-accessory', name: 'Невідомий аксесуар', confidence: 0.46 },
];

export function createMockRecognitionItems(): MockRecognitionItem[] {
  return MOCK_RECOGNITION_FIXTURES.map((item) => ({ ...item, included: true }));
}
