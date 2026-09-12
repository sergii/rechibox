export type DetectionBox = {
  xmin: number;
  ymin: number;
  xmax: number;
  ymax: number;
};

export type RawDetection = {
  box: DetectionBox;
  label: string;
  confidence: number;
};

export type InventoryRecognitionItem = {
  id: string;
  name: string;
  sourceLabel: string;
  confidence: number;
  included: boolean;
  box: DetectionBox;
};

const UKRAINIAN_LABELS: Record<string, string> = {
  person: 'Людина',
  bicycle: 'Велосипед',
  car: 'Автомобіль',
  motorcycle: 'Мотоцикл',
  airplane: 'Літак',
  bus: 'Автобус',
  train: 'Потяг',
  truck: 'Вантажівка',
  boat: 'Човен',
  'traffic light': 'Світлофор',
  'fire hydrant': 'Пожежний гідрант',
  'stop sign': 'Знак STOP',
  'parking meter': 'Паркомат',
  bench: 'Лавка',
  bird: 'Птах',
  cat: 'Кіт',
  dog: 'Собака',
  horse: 'Кінь',
  sheep: 'Вівця',
  cow: 'Корова',
  elephant: 'Слон',
  bear: 'Ведмідь',
  zebra: 'Зебра',
  giraffe: 'Жирафа',
  backpack: 'Рюкзак',
  umbrella: 'Парасоля',
  handbag: 'Сумка',
  tie: 'Краватка',
  suitcase: 'Валіза',
  frisbee: 'Фрисбі',
  skis: 'Лижі',
  snowboard: 'Сноуборд',
  'sports ball': 'М’яч',
  kite: 'Повітряний змій',
  'baseball bat': 'Бейсбольна бита',
  'baseball glove': 'Бейсбольна рукавичка',
  skateboard: 'Скейтборд',
  surfboard: 'Серфборд',
  'tennis racket': 'Тенісна ракетка',
  bottle: 'Пляшка',
  'wine glass': 'Келих',
  cup: 'Чашка',
  fork: 'Виделка',
  knife: 'Ніж',
  spoon: 'Ложка',
  bowl: 'Миска',
  banana: 'Банан',
  apple: 'Яблуко',
  sandwich: 'Сендвіч',
  orange: 'Апельсин',
  broccoli: 'Броколі',
  carrot: 'Морква',
  'hot dog': 'Хот-дог',
  pizza: 'Піца',
  donut: 'Пончик',
  cake: 'Торт',
  chair: 'Стілець',
  couch: 'Диван',
  'potted plant': 'Кімнатна рослина',
  bed: 'Ліжко',
  'dining table': 'Стіл',
  toilet: 'Унітаз',
  tv: 'Телевізор',
  laptop: 'Ноутбук',
  mouse: 'Комп’ютерна миша',
  remote: 'Пульт',
  keyboard: 'Клавіатура',
  'cell phone': 'Телефон',
  microwave: 'Мікрохвильова піч',
  oven: 'Духова шафа',
  toaster: 'Тостер',
  sink: 'Мийка',
  refrigerator: 'Холодильник',
  book: 'Книга',
  clock: 'Годинник',
  vase: 'Ваза',
  scissors: 'Ножиці',
  'teddy bear': 'Плюшевий ведмідь',
  'hair drier': 'Фен',
  toothbrush: 'Зубна щітка',
};

export function localizeDetectionLabel(label: string): string {
  return UKRAINIAN_LABELS[label] ?? label;
}

export function createInventoryRecognitionItems(
  detections: readonly RawDetection[]
): InventoryRecognitionItem[] {
  return detections.map((detection, index) => ({
    id: `${detection.label}-${index}`,
    name: localizeDetectionLabel(detection.label),
    sourceLabel: detection.label,
    confidence: detection.confidence,
    included: true,
    box: detection.box,
  }));
}
