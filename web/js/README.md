# Cola WASM - Библиотека для constraint-based layout графов

Эта директория содержит WASM-обёртку для библиотек libvpsc и libcola, предназначенную для использования в Flutter Web приложениях.

## Возможности

- **Force-directed layout** с поддержкой ограничений
- **Constraints (ограничения)**:
  - Separation — минимальное расстояние между узлами
  - Alignment — выравнивание узлов на линии
  - Distribution — равномерное распределение выровненных узлов
  - Page Boundary — ограничение области размещения
  - Boundary — узлы по одну сторону от линии
  - Fixed Relative — сохранение относительных позиций группы
- **Clusters** — группировка узлов с padding/margin
- **Desired Positions** — притяжение узлов к целевым позициям
- **Node Locking** — фиксация узлов в позиции
- **Overlap Removal** — автоматическое устранение перекрытий
- **Neighbour Stress Mode** — оптимизация для больших графов (1000+ узлов)
- **Анимация** — пошаговое выполнение layout с `tick()`

## Структура файлов

```
wasm/
├── cola_api.h          # C API заголовочный файл
├── cola_api.cpp        # C API реализация
├── build_direct.bat    # Скрипт сборки для Windows (без CMake)
├── build.sh            # Скрипт сборки для Linux/Mac
├── cola_wrapper.js     # JavaScript обёртка для удобного API
├── build/
│   ├── cola.js         # Скомпилированный JS загрузчик
│   └── cola.wasm       # WebAssembly бинарник
└── dart/
    └── cola_interop.dart  # Dart bindings для Flutter
```

## Требования

1. **Emscripten SDK** - https://emscripten.org/docs/getting_started/downloads.html
2. **CMake** >= 3.10
3. **MinGW** (для Windows) или **Make** (для Linux/Mac)

## Установка Emscripten

### Windows

```powershell
# Клонировать emsdk
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk

# Установить и активировать последнюю версию
.\emsdk.bat install latest
.\emsdk.bat activate latest

# Добавить в PATH (выполнять в каждой новой сессии или добавить в профиль)
.\emsdk_env.bat
```

### Linux/Mac

```bash
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk
./emsdk install latest
./emsdk activate latest
source ./emsdk_env.sh
```

## Сборка

### Windows

```powershell
cd cola\wasm
.\build.bat
```

### Linux/Mac

```bash
cd cola/wasm
chmod +x build.sh
./build.sh
```

После успешной сборки в директории `build/` появятся файлы:
- `cola.js` - JavaScript загрузчик модуля
- `cola.wasm` - WebAssembly бинарник

## Интеграция в Flutter Web проект

### 1. Скопируйте файлы в проект

```
your_flutter_project/
├── web/
│   ├── index.html
│   ├── cola.js          # Скопировать из build/
│   ├── cola.wasm        # Скопировать из build/
│   └── cola_wrapper.js  # Скопировать из wasm/
└── lib/
    └── cola/
        └── cola_interop.dart  # Скопировать из wasm/dart/
```

### 2. Подключите скрипты в index.html

```html
<!DOCTYPE html>
<html>
<head>
  <!-- ... -->
</head>
<body>
  <!-- Загрузка Cola WASM -->
  <script src="cola.js"></script>
  <script src="cola_wrapper.js"></script>
  
  <!-- Flutter -->
  <script src="flutter.js" defer></script>
  <script>
    window.addEventListener('load', function(ev) {
      _flutter.loader.loadEntrypoint({
        onEntrypointLoaded: async function(engineInitializer) {
          // Инициализировать Cola перед Flutter
          await initCola();
          
          let appRunner = await engineInitializer.initializeEngine();
          await appRunner.runApp();
        }
      });
    });
  </script>
</body>
</html>
```

### 3. Используйте в Dart коде

```dart
import 'package:your_app/cola/cola_interop.dart';

class GraphLayoutService {
  late ColaLayout _layout;
  
  Future<void> initialize(int nodeCount) async {
    // Инициализация уже выполнена в index.html
    // но можно проверить готовность:
    if (!ColaInterop.isReady) {
      await ColaInterop.init();
    }
    
    _layout = ColaLayout(
      nodeCount: nodeCount,
      idealEdgeLength: 150,
    );
  }
  
  void setupGraph(List<BpmnNode> nodes, List<BpmnEdge> edges) {
    // Установить позиции узлов
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      _layout.setNode(
        i,
        x: node.x,
        y: node.y,
        width: node.width,
        height: node.height,
      );
    }
    
    // Добавить рёбра
    for (final edge in edges) {
      _layout.addEdge(edge.sourceIndex, edge.targetIndex);
    }
    
    // Включить предотвращение перекрытий
    _layout.setAvoidOverlaps(true);
  }
  
  /// Запустить layout с анимацией
  void runAnimated(void Function(List<NodePosition>) onUpdate) {
    final animator = AnimatedLayout(
      layout: _layout,
      onTick: onUpdate,
      onComplete: () {
        print('Layout завершён, stress: ${_layout.getStress()}');
      },
    );
    animator.start();
  }
  
  /// Запустить layout без анимации
  List<NodePosition> runImmediate() {
    _layout.run();
    return _layout.getPositions();
  }
  
  void dispose() {
    _layout.dispose();
  }
}
```

## API Reference

### ColaLayout — Основные методы

| Метод | Описание |
|-------|----------|
| `setNode(id, x, y, width, height)` | Установить позицию и размер узла |
| `setNodes(List<Rectangle>)` | Установить все узлы из списка |
| `addEdge(source, target)` | Добавить ребро между узлами |
| `addEdges(List<(int, int)>)` | Добавить несколько рёбер |
| `run()` | Запустить layout до сходимости |
| `tick()` | Выполнить одну итерацию (для анимации), возвращает `true` если сошёлся |
| `makeFeasible()` | Сделать конфигурацию допустимой (удовлетворить constraints) |
| `getPositions()` | Получить позиции всех узлов как `List<NodePosition>` |
| `getAllPositionsFlat()` | Получить позиции как `Float64List [x0,y0,x1,y1,...]` |
| `getNodePosition(id)` | Получить позицию одного узла |
| `getStress()` | Получить текущее значение stress (меньше = лучше) |
| `dispose()` | Освободить ресурсы |

### ColaLayout — Настройки

| Метод | Описание |
|-------|----------|
| `setAvoidOverlaps(bool)` | Включить/выключить предотвращение перекрытий |
| `setConvergence(tolerance, maxIterations)` | Настроить сходимость (по умолчанию: 0.0001, 100) |
| `setNeighbourStress(bool)` | Режим neighbour stress для больших графов |

### ColaLayout — Node Locking

| Метод | Описание |
|-------|----------|
| `lockNode(nodeId, x, y)` | Зафиксировать узел в позиции |
| `unlockNode(nodeId)` | Разблокировать узел |
| `clearLocks()` | Снять все блокировки |

### ColaLayout — Desired Positions

| Метод | Описание |
|-------|----------|
| `setDesiredPosition(nodeId, x, y, weight)` | Притягивать узел к позиции |
| `clearDesiredPositions()` | Очистить все desired positions |

### ColaLayout — Constraints

| Метод | Описание |
|-------|----------|
| `addSeparationConstraint(...)` | Минимальное расстояние между узлами |
| `addAlignmentConstraint(...)` | Выравнивание узлов на линии |
| `addDistributionConstraint(...)` | Равномерное распределение alignments |
| `addOrthogonalEdgeConstraint(...)` | Ортогональная связь (горизонтальная/вертикальная) |
| `addPageBoundary(...)` | Ограничение области размещения |
| `addBoundaryConstraint(...)` | Узлы по одну сторону от линии |
| `addFixedRelativeConstraint(...)` | Сохранение относительных позиций группы |

### ColaLayout — Clusters

| Метод | Описание |
|-------|----------|
| `createCluster(nodeIds, padding, margin)` | Создать кластер, возвращает ID |
| `addChildCluster(parentId, childId)` | Добавить кластер как дочерний |
| `setClusterBounds(clusterId, xMin, xMax, yMin, yMax)` | Установить границы кластера |

---

## Примеры использования (Dart)

### Базовый пример

```dart
import 'cola_interop.dart';

Future<void> main() async {
  // Инициализация WASM модуля (один раз)
  await ColaInterop.init();
  
  // Создание layout с 5 узлами
  final layout = ColaLayout(nodeCount: 5, idealEdgeLength: 100);
  
  // Установка начальных позиций и размеров узлов
  for (int i = 0; i < 5; i++) {
    layout.setNode(i, x: i * 50.0, y: 0, width: 40, height: 30);
  }
  
  // Добавление рёбер (граф: 0-1-2-3-4)
  layout.addEdge(0, 1);
  layout.addEdge(1, 2);
  layout.addEdge(2, 3);
  layout.addEdge(3, 4);
  
  // Включить предотвращение перекрытий
  layout.setAvoidOverlaps(true);
  
  // Запустить layout
  layout.run();
  
  // Получить результаты
  final positions = layout.getPositions();
  for (int i = 0; i < positions.length; i++) {
    print('Node $i: (${positions[i].x}, ${positions[i].y})');
  }
  
  // Освободить ресурсы
  layout.dispose();
}
```

### Separation Constraint — минимальное расстояние

```dart
// Узел 1 должен быть минимум на 50 пикселей правее узла 0
layout.addSeparationConstraint(
  dimension: ConstraintDimension.horizontal,
  leftNode: 0,
  rightNode: 1,
  gap: 50,
  isEquality: false,  // <= (неравенство)
);

// Узел 1 должен быть РОВНО на 100 пикселей ниже узла 0
layout.addSeparationConstraint(
  dimension: ConstraintDimension.vertical,
  leftNode: 0,
  rightNode: 1,
  gap: 100,
  isEquality: true,  // == (равенство)
);
```

### Alignment Constraint — выравнивание узлов

```dart
// Выровнять узлы 0, 1, 2 по горизонтали (одинаковый Y)
layout.addAlignmentConstraint(
  dimension: ConstraintDimension.horizontal,
  nodeIds: [0, 1, 2],
);

// Выровнять узлы 3, 4, 5 по вертикали (одинаковый X)
layout.addAlignmentConstraint(
  dimension: ConstraintDimension.vertical,
  nodeIds: [3, 4, 5],
);
```

### Distribution Constraint — равномерное распределение

```dart
// Сначала создаём alignments (каждый alignment = группа узлов на линии)
final align1 = layout.addAlignmentConstraint(
  dimension: ConstraintDimension.horizontal,
  nodeIds: [0, 1],  // Первая колонка
);

final align2 = layout.addAlignmentConstraint(
  dimension: ConstraintDimension.horizontal,
  nodeIds: [2, 3],  // Вторая колонка
);

final align3 = layout.addAlignmentConstraint(
  dimension: ConstraintDimension.horizontal,
  nodeIds: [4, 5],  // Третья колонка
);

// Распределить колонки равномерно по горизонтали
// ВАЖНО: dimension должна совпадать с alignments!
layout.addDistributionConstraint(
  dimension: ConstraintDimension.horizontal,
  alignmentIds: [align1, align2, align3],
  separation: 150,  // Фиксированное расстояние между колонками
);
```

### Page Boundary — ограничение области

```dart
// Все узлы должны быть внутри прямоугольника (0,0) - (800,600)
layout.addPageBoundary(
  xMin: 0,
  xMax: 800,
  yMin: 0,
  yMax: 600,
  weight: 100,  // Сила притяжения к границам
);
```

### Fixed Relative Constraint — сохранение относительных позиций

```dart
// Узлы 0, 1, 2 сохраняют свои относительные позиции друг к другу
layout.addFixedRelativeConstraint(
  nodeIds: [0, 1, 2],
  fixedPosition: true,  // Группа также пытается остаться на месте
);
```

### Orthogonal Edge Constraint — ортогональные связи

Ортогональные связи — это связи, которые идут строго горизонтально или вертикально.
Используйте этот constraint для BPMN-диаграмм и других схем с прямоугольной маршрутизацией.

```dart
// Связь между узлами 0 и 1 будет горизонтальной (одинаковый Y)
layout.addOrthogonalEdgeConstraint(
  dimension: ConstraintDimension.horizontal,
  leftNode: 0,
  rightNode: 1,
);

// Связь между узлами 1 и 2 будет вертикальной (одинаковый X)
layout.addOrthogonalEdgeConstraint(
  dimension: ConstraintDimension.vertical,
  leftNode: 1,
  rightNode: 2,
);
```

#### Пример: BPMN-диаграмма с ортогональными связями

```dart
// Создаём layout для BPMN-процесса
final layout = ColaLayout(nodeCount: 6, idealEdgeLength: 120);

// Устанавливаем узлы: Start -> Task1 -> Gateway -> Task2/Task3 -> End
layout.setNode(0, x: 50, y: 200, width: 40, height: 40);   // Start
layout.setNode(1, x: 150, y: 200, width: 100, height: 60); // Task1
layout.setNode(2, x: 300, y: 200, width: 50, height: 50);  // Gateway
layout.setNode(3, x: 450, y: 100, width: 100, height: 60); // Task2 (верхняя ветка)
layout.setNode(4, x: 450, y: 300, width: 100, height: 60); // Task3 (нижняя ветка)
layout.setNode(5, x: 600, y: 200, width: 40, height: 40);  // End

// Добавляем рёбра
layout.addEdge(0, 1);  // Start -> Task1
layout.addEdge(1, 2);  // Task1 -> Gateway
layout.addEdge(2, 3);  // Gateway -> Task2
layout.addEdge(2, 4);  // Gateway -> Task3
layout.addEdge(3, 5);  // Task2 -> End
layout.addEdge(4, 5);  // Task3 -> End

// Горизонтальные связи (узлы на одной высоте)
layout.addOrthogonalEdgeConstraint(
  dimension: ConstraintDimension.horizontal,
  leftNode: 0,
  rightNode: 1,
);
layout.addOrthogonalEdgeConstraint(
  dimension: ConstraintDimension.horizontal,
  leftNode: 1,
  rightNode: 2,
);

// Вертикальные связи от Gateway к веткам
layout.addOrthogonalEdgeConstraint(
  dimension: ConstraintDimension.vertical,
  leftNode: 2,
  rightNode: 3,
);
layout.addOrthogonalEdgeConstraint(
  dimension: ConstraintDimension.vertical,
  leftNode: 2,
  rightNode: 4,
);

// Включаем предотвращение перекрытий
layout.setAvoidOverlaps(true);

// Запускаем layout
layout.run();

// Получаем результаты
final positions = layout.getPositions();
```

#### Комбинирование с Separation Constraint

Для полного контроля над ортогональной раскладкой комбинируйте с separation constraints:

```dart
// Узел 1 справа от узла 0 на расстоянии минимум 80px
layout.addSeparationConstraint(
  dimension: ConstraintDimension.horizontal,
  leftNode: 0,
  rightNode: 1,
  gap: 80,
);

// И при этом они на одной горизонтальной линии
layout.addOrthogonalEdgeConstraint(
  dimension: ConstraintDimension.horizontal,
  leftNode: 0,
  rightNode: 1,
);
```

### Clusters — группировка узлов

```dart
// Создать кластер с узлами 0, 1, 2
final cluster1 = layout.createCluster(
  nodeIds: [0, 1, 2],
  padding: 20,  // Внутренний отступ
  margin: 10,   // Внешний отступ
);

// Создать второй кластер
final cluster2 = layout.createCluster(
  nodeIds: [3, 4, 5],
  padding: 20,
  margin: 10,
);

// Можно создать иерархию кластеров
// addChildCluster(parentId, childId) — parentId=0 означает root
```

### Desired Positions — притяжение к позиции

```dart
// Узел 0 притягивается к позиции (100, 100) с весом 10
layout.setDesiredPosition(
  nodeId: 0,
  x: 100,
  y: 100,
  weight: 10,  // Чем больше, тем сильнее притяжение
);

// Очистить все desired positions
layout.clearDesiredPositions();
```

### Node Locking — фиксация узлов

```dart
// Зафиксировать узел 0 в позиции (50, 50)
layout.lockNode(0, x: 50, y: 50);

// Разблокировать узел
layout.unlockNode(0);

// Снять все блокировки
layout.clearLocks();
```

### Анимация layout

```dart
// Способ 1: Использовать AnimatedLayout
final animator = AnimatedLayout(
  layout: layout,
  onTick: (positions) {
    // Обновить UI с новыми позициями
    setState(() {
      for (int i = 0; i < positions.length; i++) {
        nodes[i].x = positions[i].x;
        nodes[i].y = positions[i].y;
      }
    });
  },
  onComplete: () {
    print('Layout завершён!');
  },
);
animator.start();

// Способ 2: Ручной цикл
void animateLayout() {
  final converged = layout.tick();
  final positions = layout.getPositions();
  
  // Обновить UI
  updateNodePositions(positions);
  
  if (!converged) {
    // Запланировать следующий кадр
    Future.delayed(Duration(milliseconds: 16), animateLayout);
  }
}
```

### Оптимизация для больших графов

```dart
// Для графов с 500+ узлами включите neighbour stress
layout.setNeighbourStress(true);

// Уменьшите количество итераций
layout.setConvergence(
  tolerance: 0.001,      // Менее строгая сходимость
  maxIterations: 50,     // Меньше итераций
);
```

### Standalone Remove Overlaps

```dart
// Удалить перекрытия без полного layout
final rectangles = [
  Rectangle(x: 0, y: 0, width: 100, height: 50),
  Rectangle(x: 50, y: 25, width: 100, height: 50),  // Перекрывается!
  Rectangle(x: 120, y: 0, width: 80, height: 60),
];

final result = ColaInterop.removeOverlaps(rectangles);
// result содержит прямоугольники без перекрытий
```

---

## Производительность

| Сценарий | Время |
|----------|-------|
| 100 узлов, полный layout | ~10-20ms |
| 500 узлов, полный layout | ~30-50ms |
| 1000 узлов, полный layout | ~50-100ms |
| 1000 узлов + neighbour stress | ~30-50ms |
| Одна итерация (tick) | ~1-5ms |

**Размер WASM**: ~150KB (gzipped: ~50KB)

---

## Следующие шаги (Этап 2)

Для добавления маршрутизации связей (libavoid) потребуется:

1. Добавить исходники libavoid в сборку
2. Расширить C API функциями маршрутизации
3. Обновить JavaScript и Dart обёртки

---

## Troubleshooting

### "Cola not initialized"
Убедитесь, что `ColaInterop.init()` вызывается до создания `ColaLayout`.

### CORS ошибки при загрузке .wasm
Убедитесь, что сервер отдаёт правильный MIME-type для .wasm файлов:
```
Content-Type: application/wasm
```

### Медленная работа
- Включите `setNeighbourStress(true)` для больших графов
- Уменьшите `maxIterations` в `setConvergence()`
- Используйте `tick()` с прореживанием кадров для анимации

### Distribution Constraint не работает
- Убедитесь, что `dimension` в `addDistributionConstraint` совпадает с `dimension` в `addAlignmentConstraint`
- Alignment IDs должны быть валидными (возвращены из `addAlignmentConstraint`)

### Assertion errors (в debug сборке)
В production сборке assertions отключены (`-DNDEBUG`). Если вы видите assertion errors, пересоберите с `build_direct.bat`.
