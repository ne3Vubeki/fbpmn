// Модель стрелки/связи
import 'dart:ui';

class Arrow {
  final String id;
  final String qType; // arrowObject, qRelationship, qEdgeToJson
  final String source; // ID источника
  final String target; // ID цели
  final String style;
  final List<Map<String, dynamic>>? powers; // Опционально
  final List<Map<String, dynamic>>? points; // Опционально
  final double strokeWidth;

  Arrow({
    required this.id,
    required this.qType,
    required this.source,
    required this.target,
    required this.style,
    this.powers,
    this.points,
    this.strokeWidth = 1.0,
  });

  factory Arrow.fromJson(Map<String, dynamic> json) {
    return Arrow(
      id: json['id'] as String,
      qType: json['qType'] as String,
      source: json['source'] as String,
      target: json['target'] as String,
      style: json['style'] as String? ?? '',
      powers: (json['powers'] as List<dynamic>?)
          ?.map((e) => e.cast<String, dynamic>())
          .toList(),
      points: (json['points'] as List<dynamic>?)
          ?.map((e) => e.cast<String, dynamic>())
          .toList(),
      strokeWidth: 1.0, // по умолчанию толщина 1
    );
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