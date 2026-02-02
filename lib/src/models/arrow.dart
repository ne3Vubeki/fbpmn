// Модель стрелки/связи
import 'dart:ui';

import 'package:fbpmn/src/models/arrow_paths.dart';

class Arrow {
  final String id;
  final String qType; // arrowObject, qRelationship, qEdgeToJson
  final String style;

  String source; // ID источника
  String? sourceCache; // ID источника кеш
  String? sourceArrow; // тип стрелки
  String target; // ID цели
  String? targetCache; // ID цели кеш
  String? targetArrow; // тип стрелки

  List<Map<String, dynamic>>? powers; // Опционально
  List<Map<String, dynamic>>? points; // Опционально

  Offset aPositionSource;
  Offset aPositionTarget;
  ArrowPaths? paths;
  List<Offset>? coordinates;

  Arrow({
    required this.id,
    required this.qType,
    required this.source,
    required this.target,
    required this.style,
    this.paths,
    this.powers,
    this.points,
    this.aPositionSource = Offset.zero,
    this.aPositionTarget = Offset.zero,
  });

  factory Arrow.fromJson(Map<String, dynamic> json) {
    final powers = (json['powers'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final points = (json['points'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    final arrow = Arrow(
      id: json['id'] as String,
      qType: json['qType'] as String,
      source: json['source'] as String,
      target: json['target'] as String,
      style: json['style'] as String? ?? '',
    );

    // определяем по стилям окончание стрелок
    final style = arrow.style;
    final styleItems = style.split(';');
    Map styleMap = {};
    for (final item in styleItems) {
      final itemList = item.split('=');
      if (itemList.length == 2) {
        styleMap[itemList[0]] = itemList[1];
      }
    }
    if (styleMap['endArrow'] == 'block') {
      arrow.targetArrow = 'block';
    } else if (styleMap['endArrow'] == 'none' &&
        styleMap['startArrow'] == 'diamondThin' &&
        styleMap['startFill'] == '1') {
      arrow.sourceArrow = 'diamondThin';
    } else if (styleMap['endArrow'] == 'none' &&
        styleMap['startArrow'] == 'diamondThin' &&
        styleMap['startFill'] == '0') {
      arrow.sourceArrow = 'diamond';
    }

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
  }) {
    return Arrow(
      id: id ?? this.id,
      qType: qType ?? this.qType,
      source: source ?? this.source,
      target: target ?? this.target,
      style: style ?? this.style,
      powers: powers ?? this.powers,
      points: points ?? this.points,
    );
  }
}
