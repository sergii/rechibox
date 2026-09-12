export type MockRecognitionItem = {
  id: string;
  name: string;
  confidence: number;
  included: boolean;
};

export const MOCK_AI_NOTICE =
  'Демо: фото не надсилається на сервер і не аналізується AI. Нижче показано фіксований локальний приклад результату, незалежний від знімка.';

const MOCK_RECOGNITION_FIXTURES: Omit<MockRecognitionItem, 'included'>[] = [
  { id: 'water-bottle', name: 'Пляшка для води', confidence: 0.94 },
  { id: 'cable', name: 'Кабель', confidence: 0.58 },
];

export function createMockRecognitionItems(): MockRecognitionItem[] {
  return MOCK_RECOGNITION_FIXTURES.map((item) => ({ ...item, included: true }));
}
