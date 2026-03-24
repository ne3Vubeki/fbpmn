class AutoLayoutPresetId {
  static const String current = 'current';
  static const String dense = 'dense';
  static const String aggressiveDense = 'aggressive_dense';
}

/// Набор внутренних коэффициентов для post-repair фазы авто-раскладки.
///
/// Эти значения управляют не самим Cola-алгоритмом, а тем, как сервис
/// выбирает лучшие позиции при дополнительной ручной доводке схемы после Cola.
class AutoLayoutSettings {
  /// Включает анимацию перемещения узлов во время repair-фазы.
  ///
  /// Если `true`, пользователь видит поэтапное смещение узлов к найденным позициям.
  /// Если `false`, узлы мгновенно телепортируются в итоговые координаты repair.
  final bool animateRepair;

  /// Включает дополнительное стремление более связанных узлов к центральной части схемы.
  ///
  /// Чем больше связей у узла, тем сильнее штраф за удаление от центра,
  /// если этот флаг включён.
  final bool centerByConnectivity;

  /// Скорость анимации перемещения узлов.
  ///
  /// Значение ближе к `1.0` делает анимацию быстрее и резче,
  /// значение ближе к `0.2` — медленнее и заметнее визуально.
  ///
  /// Практический минимум: около `0.2`.
  /// Практический максимум: около `0.95`.
  final double animationSpeed;

  /// Вес площади пересечения узла с другими узлами.
  ///
  /// Чем больше значение, тем сильнее repair стремится убрать даже частичное
  /// геометрическое наложение прямоугольников узлов.
  ///
  /// Минимум по смыслу: `0.0` — площадь пересечения почти не влияет на выбор.
  /// Максимум по смыслу: чем выше значение, тем жёстче приоритет устранения overlap.
  final double nodeOverlapAreaWeight;

  /// Вес площади пересечения узла с маршрутами стрелок.
  ///
  /// Увеличение этого коэффициента заставляет алгоритм активнее избегать
  /// прохождения узлов через существующие траектории связей.
  ///
  /// Минимум по смыслу: `0.0` — пересечение со стрелками не штрафуется.
  /// Максимум по смыслу: чем выше значение, тем важнее обходить маршруты стрелок.
  final double arrowOverlapAreaWeight;

  /// Вес количества конфликтующих узлов, а не только площади конфликта.
  ///
  /// Даже небольшое пересечение с большим числом соседей становится дорогим,
  /// поэтому узел будет охотнее уходить в более свободную область.
  ///
  /// Минимум по смыслу: `0.0` — количество соседних конфликтов игнорируется.
  /// Максимум по смыслу: чем выше значение, тем сильнее штраф за сам факт множества конфликтов.
  final double nodeOverlapCountWeight;

  /// Вес количества пересечений со стрелками.
  ///
  /// Позволяет наказывать большое число контактов со связями, даже если площадь
  /// каждого отдельного пересечения невелика.
  ///
  /// Минимум по смыслу: `0.0` — число пересечений со стрелками не учитывается.
  /// Максимум по смыслу: чем выше значение, тем агрессивнее алгоритм уводит узел от связей.
  final double arrowOverlapCountWeight;

  /// Штраф за удаление от исходной позиции текущего repair-шага.
  ///
  /// Большие значения удерживают узел ближе к найденной ранее позиции,
  /// маленькие — позволяют агрессивнее смещать его ради устранения конфликтов.
  ///
  /// Минимум по смыслу: `0.0` — узел можно свободно уводить от исходной позиции.
  /// Максимум по смыслу: чем выше значение, тем труднее алгоритму сдвигать узел далеко.
  final double distanceWeight;

  /// Общий вес стремления к центру схемы.
  ///
  /// Чем больше значение, тем сильнее repair старается не распылять схему
  /// и сохранять компактность размещения.
  ///
  /// Минимум по смыслу: `0.0` — компактность вокруг центра почти не учитывается.
  /// Максимум по смыслу: чем выше значение, тем активнее алгоритм стягивает схему к центру.
  final double centerWeight;

  final double connectedNodeDistanceWeight;

  final double connectedNodeDirectionWeight;

  final double attributeClusterWeight;

  const AutoLayoutSettings({
    required this.animateRepair,
    required this.centerByConnectivity,
    required this.animationSpeed,
    required this.nodeOverlapAreaWeight,
    required this.arrowOverlapAreaWeight,
    required this.nodeOverlapCountWeight,
    required this.arrowOverlapCountWeight,
    required this.distanceWeight,
    required this.centerWeight,
    required this.connectedNodeDistanceWeight,
    required this.connectedNodeDirectionWeight,
    required this.attributeClusterWeight,
  });
}

class AutoLayoutPresets {
  static const Map<String, AutoLayoutSettings> values = {
    /// Базовый профиль с наиболее сбалансированным поведением.
    ///
    /// Подходит как основной режим по умолчанию:
    /// - умеренно борется с пересечениями,
    /// - не слишком далеко уводит узлы от результата Cola,
    /// - удерживает схему относительно компактной без чрезмерной агрессии.
    AutoLayoutPresetId.current: AutoLayoutSettings(
      animateRepair: true,
      centerByConnectivity: true,
      animationSpeed: 0.9,
      nodeOverlapAreaWeight: 1000.0,
      arrowOverlapAreaWeight: 700.0,
      nodeOverlapCountWeight: 5000.0,
      arrowOverlapCountWeight: 2500.0,
      distanceWeight: 1.0,
      centerWeight: 1.0,
      connectedNodeDistanceWeight: 0.42,
      connectedNodeDirectionWeight: 0.2,
      attributeClusterWeight: 0.24,
    ),

    /// Более плотный профиль с усиленным приоритетом устранения конфликтов.
    ///
    /// В сравнении с `current`:
    /// - сильнее штрафует пересечения узлов и стрелок,
    /// - заметно строже относится к числу конфликтов,
    /// - одновременно сильнее тянет схему к компактному центру,
    /// - но чуть меньше сохраняет первоначальную «инерцию» Cola-раскладки.
    AutoLayoutPresetId.dense: AutoLayoutSettings(
      animateRepair: true,
      centerByConnectivity: true,
      animationSpeed: 0.9,
      nodeOverlapAreaWeight: 1450.0,
      arrowOverlapAreaWeight: 950.0,
      nodeOverlapCountWeight: 7200.0,
      arrowOverlapCountWeight: 3400.0,
      distanceWeight: 1.35,
      centerWeight: 1.35,
      connectedNodeDistanceWeight: 0.68,
      connectedNodeDirectionWeight: 0.34,
      attributeClusterWeight: 0.44,
    ),

    /// Самый агрессивный профиль для максимально плотной доводки схемы.
    ///
    /// В сравнении с остальными профилями:
    /// - максимально жёстко штрафует любые пересечения,
    /// - особенно сильно реагирует на множественные конфликты,
    /// - слабо штрафует удаление от исходной позиции repair,
    /// - очень активно стягивает результат к центру схемы.
    ///
    /// Этот профиль полезен, когда важнее компактность и устранение конфликтов,
    /// чем сохранение исходной формы, предложенной Cola.
    AutoLayoutPresetId.aggressiveDense: AutoLayoutSettings(
      animateRepair: true,
      centerByConnectivity: true,
      animationSpeed: 0.9,
      nodeOverlapAreaWeight: 2300.0,
      arrowOverlapAreaWeight: 1650.0,
      nodeOverlapCountWeight: 13000.0,
      arrowOverlapCountWeight: 6800.0,
      distanceWeight: 0.18,
      centerWeight: 3.6,
      connectedNodeDistanceWeight: 1.1,
      connectedNodeDirectionWeight: 0.58,
      attributeClusterWeight: 0.82,
    ),
  };

  static AutoLayoutSettings byId(String id) {
    return values[id] ?? values[AutoLayoutPresetId.current]!;
  }
}
