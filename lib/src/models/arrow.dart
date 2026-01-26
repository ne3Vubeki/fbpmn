// Модель стрелки/связи
import 'dart:ui';

class Arrow {
  final String id;
  final String qType; // arrowObject, qRelationship, qEdgeToJson
  String source; // ID источника
  String target; // ID цели
  Offset aPositionSource;
  Offset aPositionTarget;
  final String style;
  List<Map<String, dynamic>>? powers; // Опционально
  List<Map<String, dynamic>>? points; // Опционально
  final double strokeWidth;

  Arrow({
    required this.id,
    required this.qType,
    required this.source,
    required this.target,
    required this.style,
    this.aPositionSource = Offset.zero,
    this.aPositionTarget = Offset.zero,
    this.powers,
    this.points,
    this.strokeWidth = 1.0,
  });

  factory Arrow.fromJson(Map<String, dynamic> json) {
    final powers = (json['powers'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final points = (json['points'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    final arrow = Arrow(
      id: json['id'] as String,
      qType: json['qType'] as String,
      source: json['source'] as String,
      target: json['target'] as String,
      style: json['style'] as String? ?? '',
      strokeWidth: 1.0, // по умолчанию толщина 1
    );
    if (powers.isNotEmpty) {
      arrow.powers = powers;
    }
    if (points.isNotEmpty) {
      arrow.points = points;
    }
    return arrow;
  }

  Arrow copyWith({
    String? id,
    String? qType,
    String? source,
    String? target,
    String? style,
    List<Map<String, dynamic>>? powers,
    List<Map<String, dynamic>>? points,
    double? strokeWidth,
  }) {
    return Arrow(
      id: id ?? this.id,
      qType: qType ?? this.qType,
      source: source ?? this.source,
      target: target ?? this.target,
      style: style ?? this.style,
      powers: powers ?? this.powers,
      points: points ?? this.points,
      strokeWidth: strokeWidth ?? this.strokeWidth,
    );
  }
}
