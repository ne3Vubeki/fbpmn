// Модель стрелки/связи
import 'dart:ui';

import 'package:fbpmn/src/models/arrow_paths.dart';
import 'package:fbpmn/src/models/power.dart';

class Arrow {
  final String id;

  String qType; // arrowObject, qRelationship, qEdgeToJson
  String style;
  String source; // ID источника
  String? sourceCache; // ID источника кеш
  String? sourceArrow; // тип стрелки
  String target; // ID цели
  String? targetCache; // ID цели кеш
  String? targetArrow; // тип стрелки

  List<Power>? powers; // Опционально

  Offset aPositionSource;
  Offset aPositionTarget;
  ArrowPaths? paths; // Пути для рисования стрелки
  List<Rect>? rects; // Прямоугольники для проверки пересечений
  List<Offset>? coordinates; // Координаты для рисования стрелки
  String? sides;

  Arrow({
    required this.id,
    required this.qType,
    required this.source,
    required this.target,
    required this.style,
    this.paths,
    this.powers,
    this.aPositionSource = Offset.zero,
    this.aPositionTarget = Offset.zero,
    this.sides,
    this.sourceArrow,
    this.targetArrow,
  });

  factory Arrow.fromJson(Map<String, dynamic> json) {
    final powers = (json['powers'] as List<dynamic>? ?? [])
        .map((e) => Power.fromJson(e as Map<String, dynamic>))
        .toList();

    final arrow = Arrow(
      id: json['id'] as String,
      qType: json['qType'] as String,
      source: json['source'] as String,
      target: json['target'] as String,
      style: json['style'] as String? ?? '',
      sourceArrow: json['sourceArrow'] as String?,
      targetArrow: json['targetArrow'] as String?,
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
    return arrow;
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'qType': qType,
      'source': source,
      'target': target,
      'style': style,
    };

    if (sourceArrow != null) {
      json['sourceArrow'] = sourceArrow;
    }
    if (targetArrow != null) {
      json['targetArrow'] = targetArrow;
    }
    if (powers != null && powers!.isNotEmpty) {
      json['powers'] = powers!.map((power) => power.toJson()).toList();
    }

    return json;
  }

  Arrow copyWith({
    String? id,
    String? qType,
    String? source,
    String? target,
    String? style,
    List<Power>? powers,
    String? sourceArrow,
    String? targetArrow,
  }) {
    return Arrow(
      id: id ?? this.id,
      qType: qType ?? this.qType,
      source: source ?? this.source,
      target: target ?? this.target,
      style: style ?? this.style,
      powers: powers ?? this.powers,
      sourceArrow: sourceArrow ?? this.sourceArrow,
      targetArrow: targetArrow ?? this.targetArrow,
    );
  }
}
