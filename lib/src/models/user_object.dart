// Модель пользовательского объекта (user_object)
import 'package:flutter/material.dart';

class UserObject {
  final String id;
  final String? text;
  final String? img;
  final double? imgWidth;
  final double? imgHeight;
  final String? tooltip;
  final String style;
  final Offset position;
  final Size size;

  UserObject({
    required this.id,
    required this.style,
    required this.position,
    required this.size,
    this.text,
    this.img,
    this.imgWidth,
    this.imgHeight,
    this.tooltip,
  });

  factory UserObject.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>;
    
    final x = (geometry['x'] as num).toDouble();
    final y = (geometry['y'] as num).toDouble();
    final width = (geometry['width'] as num).toDouble();
    final height = (geometry['height'] as num).toDouble();

    final label = json['label'] as String? ?? '';
    
    // Парсим label на предмет HTML img или текста
    String? text;
    String? img;
    double? imgWidth;
    double? imgHeight;

    if (label.contains('<img')) {
      // Это HTML с изображением
      // Извлекаем src
      final srcRegex = RegExp(r'src="([^"]+)"');
      final srcMatch = srcRegex.firstMatch(label);
      if (srcMatch != null) {
        img = srcMatch.group(1);
      }

      // Извлекаем width
      final widthRegex = RegExp(r'width="(\d+)"');
      final widthMatch = widthRegex.firstMatch(label);
      if (widthMatch != null) {
        imgWidth = double.tryParse(widthMatch.group(1)!);
      }

      // Извлекаем height
      final heightRegex = RegExp(r'height="(\d+)"');
      final heightMatch = heightRegex.firstMatch(label);
      if (heightMatch != null) {
        imgHeight = double.tryParse(heightMatch.group(1)!);
      }
    } else {
      // Это обычный текст
      text = label;
    }

    return UserObject(
      id: json['id'] as String,
      text: text,
      img: img,
      imgWidth: imgWidth,
      imgHeight: imgHeight,
      tooltip: json['tooltip'] as String?,
      style: json['style'] as String? ?? '',
      position: Offset(x, y),
      size: Size(width, height),
    );
  }

  Map<String, dynamic> toJson() {
    // Восстанавливаем label из text или img
    String label;
    if (img != null) {
      label = '<img height="${imgHeight?.toInt() ?? 8}" width="${imgWidth?.toInt() ?? 18}" src="$img">';
    } else {
      label = text ?? '';
    }

    return {
      'id': id,
      'label': label,
      'tooltip': tooltip,
      'style': style,
      'geometry': {
        'x': position.dx,
        'y': position.dy,
        'width': size.width,
        'height': size.height,
      },
    };
  }

  /// Создает копию объекта с измененными полями
  UserObject copyWith({
    String? id,
    String? text,
    String? img,
    double? imgWidth,
    double? imgHeight,
    String? tooltip,
    String? style,
    Offset? position,
    Size? size,
  }) {
    return UserObject(
      id: id ?? this.id,
      text: text ?? this.text,
      img: img ?? this.img,
      imgWidth: imgWidth ?? this.imgWidth,
      imgHeight: imgHeight ?? this.imgHeight,
      tooltip: tooltip ?? this.tooltip,
      style: style ?? this.style,
      position: position ?? this.position,
      size: size ?? this.size,
    );
  }

  @override
  String toString() {
    return 'UserObject(id: $id, text: $text, img: $img, imgWidth: $imgWidth, imgHeight: $imgHeight, tooltip: $tooltip, position: $position, size: $size)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserObject &&
        other.id == id &&
        other.text == text &&
        other.img == img &&
        other.imgWidth == imgWidth &&
        other.imgHeight == imgHeight &&
        other.tooltip == tooltip &&
        other.style == style &&
        other.position == position &&
        other.size == size;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      text,
      img,
      imgWidth,
      imgHeight,
      tooltip,
      style,
      position,
      size,
    );
  }
}
