// Fictional fixtures for the selection demo, not Rechibox's inventory or pricing rules.
export type MockStorageOption = Readonly<{
  id: string;
  name: string;
  areaLabel: string;
  priceLabel: string;
  facilityLabel: string;
  available: boolean;
}>;

export const MOCK_STORAGE_NOTICE =
  'Демонстраційні дані: розміри, ціни, локація та доступність наведені для прикладу.';

export const mockStorageOptions: readonly MockStorageOption[] = [
  {
    id: 'demo-small',
    name: 'Малий бокс',
    areaLabel: '1 м²',
    priceLabel: '700 грн / місяць',
    facilityLabel: 'Демо-локація «Приклад»',
    available: true,
  },
  {
    id: 'demo-medium',
    name: 'Середній бокс',
    areaLabel: '3 м²',
    priceLabel: '1 400 грн / місяць',
    facilityLabel: 'Демо-локація «Приклад»',
    available: true,
  },
  {
    id: 'demo-large',
    name: 'Великий бокс',
    areaLabel: '5 м²',
    priceLabel: '2 100 грн / місяць',
    facilityLabel: 'Демо-локація «Приклад»',
    available: false,
  },
];
