class AutoLayoutPresetId {
  static const String current = 'current';
  static const String dense = 'dense';
  static const String aggressiveDense = 'aggressive_dense';
}

class AutoLayoutSettings {
  final bool animateRepair;
  final bool centerByConnectivity;
  final double animationSpeed;
  final double nodeOverlapAreaWeight;
  final double arrowOverlapAreaWeight;
  final double nodeOverlapCountWeight;
  final double arrowOverlapCountWeight;
  final double distanceWeight;
  final double centerWeight;

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
  });
}

class AutoLayoutPresets {
  static const Map<String, AutoLayoutSettings> values = {
    AutoLayoutPresetId.current: AutoLayoutSettings(
      animateRepair: true,
      centerByConnectivity: true,
      animationSpeed: 0.8,
      nodeOverlapAreaWeight: 1000.0,
      arrowOverlapAreaWeight: 700.0,
      nodeOverlapCountWeight: 5000.0,
      arrowOverlapCountWeight: 2500.0,
      distanceWeight: 1.0,
      centerWeight: 1.0,
    ),
    AutoLayoutPresetId.dense: AutoLayoutSettings(
      animateRepair: true,
      centerByConnectivity: true,
      animationSpeed: 0.82,
      nodeOverlapAreaWeight: 1300.0,
      arrowOverlapAreaWeight: 900.0,
      nodeOverlapCountWeight: 6500.0,
      arrowOverlapCountWeight: 3200.0,
      distanceWeight: 0.7,
      centerWeight: 1.7,
    ),
    AutoLayoutPresetId.aggressiveDense: AutoLayoutSettings(
      animateRepair: true,
      centerByConnectivity: true,
      animationSpeed: 0.88,
      nodeOverlapAreaWeight: 1700.0,
      arrowOverlapAreaWeight: 1200.0,
      nodeOverlapCountWeight: 9000.0,
      arrowOverlapCountWeight: 4500.0,
      distanceWeight: 0.35,
      centerWeight: 2.6,
    ),
  };

  static AutoLayoutSettings byId(String id) {
    return values[id] ?? values[AutoLayoutPresetId.current]!;
  }
}
