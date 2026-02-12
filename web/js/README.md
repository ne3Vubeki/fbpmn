# Cola WASM - Библиотека для constraint-based layout графов

Эта директория содержит WASM-обёртку для библиотек libvpsc и libcola, предназначенную для использования в Flutter Web приложениях.

## Структура файлов

```
wasm/
├── cola_api.h          # C API заголовочный файл
├── cola_api.cpp        # C API реализация
├── CMakeLists.txt      # CMake конфигурация для Emscripten
├── build.bat           # Скрипт сборки для Windows
├── build.sh            # Скрипт сборки для Linux/Mac
├── cola_wrapper.js     # JavaScript обёртка для удобного API
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

### ColaLayout

| Метод | Описание |
|-------|----------|
| `setNode(id, x, y, width, height)` | Установить позицию и размер узла |
| `addEdge(source, target)` | Добавить ребро между узлами |
| `addSeparationConstraint(...)` | Добавить ограничение разделения |
| `addAlignmentConstraint(...)` | Добавить ограничение выравнивания |
| `setAvoidOverlaps(enable)` | Включить/выключить предотвращение перекрытий |
| `run()` | Запустить layout до сходимости |
| `tick()` | Выполнить одну итерацию (для анимации) |
| `makeFeasible()` | Сделать конфигурацию допустимой |
| `getPositions()` | Получить позиции всех узлов |
| `getStress()` | Получить текущее значение stress |
| `dispose()` | Освободить ресурсы |

### Constraints (Ограничения)

#### Separation Constraint
Ограничение разделения: `leftNode + gap <= rightNode`

```dart
layout.addSeparationConstraint(
  dimension: ConstraintDimension.horizontal,
  leftNode: 0,
  rightNode: 1,
  gap: 50,
  isEquality: false,
);
```

#### Alignment Constraint
Выравнивание узлов на одной линии:

```dart
layout.addAlignmentConstraint(
  dimension: ConstraintDimension.vertical,
  nodeIds: [0, 1, 2, 3],  // Эти узлы будут на одной вертикальной линии
);
```

## Производительность

- **1000 узлов**: ~50-100ms для полного layout
- **Анимация**: ~16ms на итерацию (60 FPS)
- **Размер WASM**: ~150-200KB (gzipped: ~50KB)

## Следующие шаги (Этап 2)

Для добавления маршрутизации связей (libavoid) потребуется:

1. Добавить исходники libavoid в CMakeLists.txt
2. Расширить C API функциями маршрутизации
3. Обновить JavaScript и Dart обёртки

## Troubleshooting

### "Cola not initialized"
Убедитесь, что `initCola()` вызывается до создания `ColaLayout`.

### CORS ошибки при загрузке .wasm
Убедитесь, что сервер отдаёт правильный MIME-type для .wasm файлов:
```
Content-Type: application/wasm
```

### Медленная работа
- Уменьшите `maxIterations` в `setConvergence()`
- Используйте `tick()` с прореживанием кадров для анимации
