export type InventoryDetectionBox = {
  xmin: number;
  ymin: number;
  xmax: number;
  ymax: number;
};

export type InventoryRecognitionItem = {
  id: string;
  name: string;
  sourceLabel: string;
  confidence: number;
  included: boolean;
  box: InventoryDetectionBox;
};

export type InventoryRecognitionResult = {
  items: InventoryRecognitionItem[];
  imageWidth: number;
  imageHeight: number;
  inferenceMs: number;
};
