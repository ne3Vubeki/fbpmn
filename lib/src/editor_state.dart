import 'package:flutter/material.dart';

import 'models/image_tile.dart';
import 'models/snap_line.dart';
import 'models/table.node.dart';
import 'models/arrow.dart';

/// Глобальное состояние редактора BPMN.
///
/// Хранит все данные, необходимые для работы холста: масштаб, позицию,
/// узлы, стрелки, тайлы, настройки отображения и состояние ввода.
/// Инициализируется из [properties], переданных при запуске приложения.
class EditorState {
  /// Свойства, переданные при инициализации приложения (из JS-окружения).
  /// Секция `config` используется для настройки начального состояния редактора.
  Map<String, dynamic> properties;

  EditorState(this.properties) {
    _applyConfig();
  }

  /// Применяет начальную конфигурацию из [properties]['config'].
  void _applyConfig() {
    // Конфигурация приходит из внешнего окружения и хранится в секции `config`.
    final config = properties['config'];
    if (config == null || config is! Map) return;

    // Проходим по всем переданным ключам и обновляем соответствующие поля состояния.
    // Здесь намеренно используется switch по строковым ключам внешней конфигурации.
    config.forEach((key, value) {
      switch (key.toString()) {
        // Включает snap-поведение редактора при ручном перемещении узлов.
        // Управляет прилипанием к сетке и соседним элементам во время drag-and-drop.
        case 'snapEnabled':
          if (value is bool) snapEnabled = value;

        // Показывает или скрывает визуальные границы растровых тайлов холста.
        // Используется в основном как отладочная настройка отображения.
        case 'showTileBorders':
          if (value is bool) showTileBorders = value;

        // Переключает способ отрисовки связей: прямые сегменты или кривые.
        // Влияет только на визуальное представление стрелок, а не на данные схемы.
        case 'useCurves':
          if (value is bool) useCurves = value;

        // Включает отображение служебной панели производительности.
        // Полезно для диагностики FPS и общей нагрузки при работе редактора.
        case 'showPerformance':
          if (value is bool) showPerformance = value;

        // Управляет отображением миниатюры схемы.
        // Если флаг выключен, thumbnail-обзор холста не показывается.
        case 'showThumbnail':
          if (value is bool) showThumbnail = value;

        // Включает специальный режим отображения, в котором остаются только коннекторы.
        // Используется для упрощённого просмотра связей без акцента на узлы.
        case 'onlyConnectors':
          if (value is bool) onlyConnectors = value;

        // Включает или отключает стартовый этап Cola в пайплайне автораскладки.
        // Если `false`, алгоритм сразу переходит к локальной расстановке без глобического смешивания.
        case 'autoLayoutUseCola':
          if (value is bool) autoLayoutUseCola = value;

        // Включает или отключает финальный этап доводки после основной расстановки.
        // Этот шаг пытается дополнительно уменьшить остаточные пересечения узлов и стрелок.
        case 'autoLayoutUsePolish':
          if (value is bool) autoLayoutUsePolish = value;

        // Разрешает прилипание к рядом расположенным узлам на этапе основной расстановки.
        // Сторона прилипания выбирается автоматически по сектору узла относительно центра схемы.
        case 'autoLayoutUseSnapOnRepair':
          if (value is bool) autoLayoutUseSnapOnRepair = value;

        // Разрешает такое же секторное прилипание на этапе финальной доводки.
        // Если выключено, доводка ищет позицию только на базе score-функции без прилипания к узлам.
        case 'autoLayoutUseSnapOnPolish':
          if (value is bool) autoLayoutUseSnapOnPolish = value;

        // Разрешает финальный нейроэтап автораскладки.
        case 'autoLayoutUseNeuralPolish':
          if (value is bool) autoLayoutUseNeuralPolish = value;

        // Разрешает локальный сбор обучающих samples для нейроэтапа автораскладки.
        case 'autoLayoutTrainNeuralPolish':
          if (value is bool) autoLayoutTrainNeuralPolish = value;

        // Разрешает сбор обучающих samples при ручном перемещении узлов.
        // Используется для накопления пользовательских правок как локального датасета.
        case 'manualLayoutTrainNeuralPolish':
          if (value is bool) manualLayoutTrainNeuralPolish = value;

        // Включает режим, в котором при выделении одного узла скрываются остальные неактивные элементы.
        // Используется для фокусировки на связанном фрагменте схемы.
        case 'selectAndHide':
          if (value is bool) selectAndHide = value;
      }
    });
  }

  setConfig(Map<String, dynamic> config) {
    properties['config'] = config;
    _applyConfig();
  }

  // ---------------------------------------------------------------------------
  // Масштаб и позиция холста
  // ---------------------------------------------------------------------------

  /// Текущий масштаб холста (1.0 = 100%).
  double scale = 1.0;

  /// Смещение холста относительно начала координат.
  Offset offset = Offset.zero;

  /// Дельта смещения при панорамировании.
  Offset delta = Offset.zero;

  // ---------------------------------------------------------------------------
  // Идентификация
  // ---------------------------------------------------------------------------

  /// Глобальный счётчик-идентификатор для генерации уникальных ID элементов.
  String globalId = '0000000000001';

  // ---------------------------------------------------------------------------
  // Схема
  // ---------------------------------------------------------------------------

  /// Текущая схема редактора.
  Map<String, dynamic> schema = {};

  // ---------------------------------------------------------------------------
  // Состояние ввода
  // ---------------------------------------------------------------------------

  /// Зажата ли клавиша Shift.
  bool isShiftPressed = false;

  /// Зажата ли клавиша Ctrl.
  bool isCtrlPressed = false;

  /// Выполняется ли панорамирование холста (drag пустого пространства).
  bool isPanning = false;

  /// Текущая позиция курсора мыши в координатах холста.
  Offset mousePosition = Offset.zero;

  // ---------------------------------------------------------------------------
  // Размеры и инициализация
  // ---------------------------------------------------------------------------

  /// Размер видимой области (viewport).
  Size viewportSize = Size.zero;

  /// Флаг завершения первичной инициализации холста.
  bool isInitialized = false;

  // ---------------------------------------------------------------------------
  // Узлы
  // ---------------------------------------------------------------------------

  /// Список всех узлов на холсте.
  final List<TableNode> nodes = [];

  /// Множество выделенных узлов.
  final Set<TableNode?> nodesSelected = {};

  /// Находится ли перетаскиваемый узел на верхнем слое отрисовки.
  String nodesIdOnTopLayer = '';

  /// Исходная позиция узла до начала перетаскивания.
  Offset originalNodePosition = Offset.zero;

  /// Выполняется ли перетаскивание узла.
  bool isNodeDragging = false;

  /// Смещение курсора относительно левого верхнего угла перетаскиваемого узла.
  Offset selectedNodeOffset = Offset.zero;

  /// Внутренние отступы рамки выделения узла.
  EdgeInsets framePadding = EdgeInsets.all(0);

  bool isAreaSelecting = false;

  Offset selectionStart = Offset.zero;

  Offset selectionCurrent = Offset.zero;

  TableNode? toggleSwimlaneNode;

  /// Узел ховеред
  TableNode? hoveredNode;

  // ---------------------------------------------------------------------------
  // Наведение на атрибуты узла
  // ---------------------------------------------------------------------------

  /// ID узла, над строкой атрибута которого находится курсор.
  String? hoveredAttributeNodeId;

  /// Индекс строки атрибута, над которой находится курсор.
  int? hoveredAttributeRowIndex;

  /// Курсор над левым кружком связи атрибута.
  bool hoveredAttributeCircleLeft = false;

  /// Курсор над правым кружком связи атрибута.
  bool hoveredAttributeCircleRight = false;

  // ---------------------------------------------------------------------------
  // Snap-прилипание
  // ---------------------------------------------------------------------------

  /// Активные snap-линии, отображаемые при перетаскивании узла.
  List<SnapLine> snapLines = [];

  /// Включено ли snap-прилипание узлов к сетке и другим узлам.
  bool snapEnabled = false;

  // ---------------------------------------------------------------------------
  // Стрелки (связи)
  // ---------------------------------------------------------------------------

  /// Список всех стрелок (связей) на холсте.
  final List<Arrow> arrows = [];

  /// Множество выделенных стрелок.
  final Set<Arrow?> arrowsSelected = {};

  /// Стрелка под курсором.
  Arrow? hoveredArrow;

  /// Нужно ли проигнорировать следующий pointer down на канвасе.
  bool ignoreNextCanvasPointerDown = false;

  /// Создаваемая стрелка.
  Arrow? arrowCreated;

  /// Стартовая сторона создания новой связи.
  String? arrowCreatedStartSide;

  /// Был ли следующий клик сделан по target-кружку создаваемой связи.
  bool ignoreNextCreatedArrowCancel = false;

  // ---------------------------------------------------------------------------
  // Подсветка
  // ---------------------------------------------------------------------------

  /// ID узлов, подсвеченных как связанные с текущим выделением.
  final Set<String> highlightedNodeIds = {};

  // ---------------------------------------------------------------------------
  // Тайлы (растровый кэш холста)
  // ---------------------------------------------------------------------------

  /// Список тайлов, на которые разбит холст для оптимизации отрисовки.
  Map<String, ImageTile> imageTiles = {};

  /// Список обновленных тайлов
  Set<String> updatedImageTileIds = {};

  /// Отображать ли границы тайлов (для отладки).
  bool showTileBorders = true;

  /// Отображать только коннекторы.
  bool onlyConnectors = false;

  /// Режим который при выборе узла скрывает остальные не подсвеченные узлы и связи
  bool selectAndHide = false;

  // ---------------------------------------------------------------------------
  // Прочие флаги состояния
  // ---------------------------------------------------------------------------

  /// Выполняется ли асинхронная загрузка данных.
  bool isLoading = false;

  /// Режим автораскладки: скрывает рамки выделения во время расчёта layout.
  bool isAutoLayoutMode = false;

  /// Использовать ли кривые Безье для отрисовки стрелок.
  bool useCurves = false;

  /// Отображать ли миниатюру (thumbnail) холста.
  bool showThumbnail = true;

  /// Отображать ли панель производительности (FPS и прочее).
  bool showPerformance = false;

  bool autoLayoutUseCola = true;

  bool autoLayoutUsePolish = true;

  bool autoLayoutUseSnapOnRepair = false;

  bool autoLayoutUseSnapOnPolish = false;

  bool autoLayoutUseNeuralPolish = false;

  /// Включает сбор samples для обучения нейромодели во время этапов автораскладки.
  bool autoLayoutTrainNeuralPolish = false;

  /// Включает сбор samples при ручном перемещении узлов с фиксацией результата при deselect.
  bool manualLayoutTrainNeuralPolish = false;

  /// Время выполнения текущего процесса раскладки или обучения для отображения в overlay.
  int autoLayoutElapsedMilliseconds = 0;

  /// Текущий прогресс длительного процесса в процентах для progress bar в overlay.
  double? currentLayoutProcessProgress;

  /// Показывать ли кнопку остановки в overlay текущего процесса.
  bool currentLayoutProcessCanStop = true;

  /// Активен ли в текущем процессе раскладки сбор samples для обучения AI.
  bool currentLayoutProcessAiCollecting = false;

  /// Название текущего этапа раскладки или обучения, отображаемое в overlay.
  String currentLayoutProcess = '';
}
