// Модель Power (мощность связи)
class Power {
  final String id;
  final String value;
  final String style;
  final String qType;
  final String qCompStatus;
  final String connectable;
  final String side;

  Power({
    required this.id,
    required this.value,
    required this.style,
    required this.qType,
    required this.qCompStatus,
    required this.connectable,
    required this.side,
  });

  factory Power.fromJson(Map<String, dynamic> json) {
    return Power(
      id: json['id'] as String,
      value: json['value'] as String? ?? '',
      style: json['style'] as String? ?? '',
      qType: json['qType'] as String? ?? 'arrowPower',
      qCompStatus: json['qCompStatus'] as String? ?? '0',
      connectable: json['connectable'] as String? ?? '0',
      side: json['side'] as String? ?? '1',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'value': value,
      'style': style,
      'qType': qType,
      'qCompStatus': qCompStatus,
      'connectable': connectable,
      'side': side,
    };
  }

  Power copyWith({
    String? id,
    String? value,
    String? style,
    String? qType,
    String? qCompStatus,
    String? connectable,
    String? side,
  }) {
    return Power(
      id: id ?? this.id,
      value: value ?? this.value,
      style: style ?? this.style,
      qType: qType ?? this.qType,
      qCompStatus: qCompStatus ?? this.qCompStatus,
      connectable: connectable ?? this.connectable,
      side: side ?? this.side,
    );
  }

  @override
  String toString() {
    return 'Power(id: $id, value: $value, side: $side)';
  }
}
