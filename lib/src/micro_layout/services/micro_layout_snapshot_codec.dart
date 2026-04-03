import 'dart:convert';

import 'package:fbpmn/src/micro_layout/models/micro_layout_snapshot.dart';

class MicroLayoutSnapshotCodec {
  const MicroLayoutSnapshotCodec();

  String encode(MicroLayoutSnapshot snapshot) {
    return const JsonEncoder.withIndent('  ').convert(snapshot.toJson());
  }

  MicroLayoutSnapshot decode(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return MicroLayoutSnapshot.fromJson(json);
  }
}
