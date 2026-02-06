// Модель атрибута бизнес-объекта
import 'package:flutter/material.dart';
import 'user_object.dart';

class Attribute {
  final String id;
  final String text;
  final String? boAttributeTypeId;
  final Map<String, dynamic>? params;
  final String style;
  final String qType;
  final String? qAttributeType;
  final String? qCompStatus;
  final String? originalId;
  final UserObject? userObject;
  final Offset position;
  final Size size;

  Attribute({
    required this.id,
    required this.text,
    required this.style,
    required this.qType,
    required this.position,
    required this.size,
    this.boAttributeTypeId,
    this.params,
    this.qAttributeType,
    this.qCompStatus,
    this.originalId,
    this.userObject,
  });

  factory Attribute.fromJson(Map<String, dynamic> json) {
    // Парсим geometry, если есть
    Offset position = Offset.zero;
    Size size = Size.zero;
    
    if (json.containsKey('geometry')) {
      final geometry = json['geometry'] as Map<String, dynamic>;
      final x = (geometry['x'] as num?)?.toDouble() ?? 0.0;
      final y = (geometry['y'] as num?)?.toDouble() ?? 0.0;
      final width = (geometry['width'] as num?)?.toDouble() ?? 0.0;
      final height = (geometry['height'] as num?)?.toDouble() ?? 0.0;
      
      position = Offset(x, y);
      size = Size(width, height);
    }

    // Парсим user_object, если есть
    UserObject? userObject;
    if (json.containsKey('user_object')) {
      userObject = UserObject.fromJson(json['user_object'] as Map<String, dynamic>);
    }

    return Attribute(
      id: json['id'] as String,
      text: json['label'] as String? ?? '',
      boAttributeTypeId: json['boAttributeTypeId'] as String?,
      params: json['params'] as Map<String, dynamic>?,
      style: json['style'] as String? ?? '',
      qType: json['qType'] as String? ?? 'attribute',
      qAttributeType: json['qAttributeType'] as String?,
      qCompStatus: json['qCompStatus'] as String?,
      originalId: json['originalId'] as String?,
      userObject: userObject,
      position: position,
      size: size,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'label': text,
      'style': style,
      'qType': qType,
    };

    if (boAttributeTypeId != null) {
      json['boAttributeTypeId'] = boAttributeTypeId;
    }

    if (params != null) {
      json['params'] = params;
    }

    if (qAttributeType != null) {
      json['qAttributeType'] = qAttributeType;
    }

    if (qCompStatus != null) {
      json['qCompStatus'] = qCompStatus;
    }

    if (originalId != null) {
      json['originalId'] = originalId;
    }

    if (userObject != null) {
      json['user_object'] = userObject!.toJson();
    }

    // Добавляем geometry, если позиция или размер не нулевые
    if (position != Offset.zero || size != Size.zero) {
      json['geometry'] = {
        'x': position.dx,
        'y': position.dy,
        'width': size.width,
        'height': size.height,
      };
    }

    return json;
  }

  /// Создает копию объекта с измененными полями
  Attribute copyWith({
    String? id,
    String? text,
    String? boAttributeTypeId,
    Map<String, dynamic>? params,
    String? style,
    String? qType,
    String? qAttributeType,
    String? qCompStatus,
    String? originalId,
    UserObject? userObject,
    Offset? position,
    Size? size,
  }) {
    return Attribute(
      id: id ?? this.id,
      text: text ?? this.text,
      boAttributeTypeId: boAttributeTypeId ?? this.boAttributeTypeId,
      params: params ?? this.params,
      style: style ?? this.style,
      qType: qType ?? this.qType,
      qAttributeType: qAttributeType ?? this.qAttributeType,
      qCompStatus: qCompStatus ?? this.qCompStatus,
      originalId: originalId ?? this.originalId,
      userObject: userObject ?? this.userObject,
      position: position ?? this.position,
      size: size ?? this.size,
    );
  }

  @override
  String toString() {
    return 'Attribute(id: $id, text: $text, qType: $qType, qAttributeType: $qAttributeType, userObject: $userObject)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Attribute &&
        other.id == id &&
        other.text == text &&
        other.boAttributeTypeId == boAttributeTypeId &&
        other.style == style &&
        other.qType == qType &&
        other.qAttributeType == qAttributeType &&
        other.qCompStatus == qCompStatus &&
        other.originalId == originalId &&
        other.userObject == userObject &&
        other.position == position &&
        other.size == size;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      text,
      boAttributeTypeId,
      style,
      qType,
      qAttributeType,
      qCompStatus,
      originalId,
      userObject,
      position,
      size,
    );
  }
}
