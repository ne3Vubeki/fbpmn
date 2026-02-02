import 'dart:ui';

import 'package:fbpmn/src/models/connection.dart';

class Connections {
  Set<Connection?>? top;
  Set<Connection?>? right;
  Set<Connection?>? bottom;
  Set<Connection?>? left;

  static double discreteness = 8.0;

  Connections({this.top, this.right, this.bottom, this.left}) {
    top = {};
    right = {};
    bottom = {};
    left = {};
  }

  Map<String, Set<Connection?>> _toMap() {
    return {'top': top!, 'right': right!, 'bottom': bottom!, 'left': left!};
  }

  Set<Connection?>? get(String propertyName) {
    var mapRep = _toMap();
    if (mapRep.containsKey(propertyName)) {
      return mapRep[propertyName];
    }
    throw ArgumentError('propery not found');
  }

  int length(String side) {
    final sideProp = get(side);
    return sideProp?.length ?? 0;
  }

  remove(String arrowId) {
    top = top!.where((connect) => connect!.id != arrowId).toSet();
    right = right!.where((connect) => connect!.id != arrowId).toSet();
    bottom = bottom!.where((connect) => connect!.id != arrowId).toSet();
    left = left!.where((connect) => connect!.id != arrowId).toSet();
  }

  removeAll() {
    top!.clear();
    right!.clear();
    bottom!.clear();
    left!.clear();
  }

  Connection? add(String side, String arrowId, Offset position) {
    final sideProp = get(side);
    final connection = sideProp?.firstWhere(
      (conn) => conn!.id == arrowId,
      orElse: () => null,
    );

    if (connection != null) {
      return connection;
    }

    int ind;
    final countSide = length(side);
    final newConn = Connection(id: arrowId, pos: position);

    for (ind = 0; ind < countSide; ind++) {
      final conn = sideProp!.toList()[ind];
      if (conn == null  || conn.index != ind) {
        newConn.index = ind;
        break;
      }
    }

    newConn.index = newConn.index ?? ind;
    sideProp?.add(newConn);

    final sidePropList = sideProp?.toList();

    sidePropList?.sort((a, b) => a!.index!.compareTo(b!.index!));
    sideProp?.clear();
    sideProp?.addAll(sidePropList as Iterable<Connection?>);

    return newConn;
  }

  double getSideDelta(String side, Connection connection) {
    final sideProp = get(side);
    final n = sideProp?.toList().indexOf(connection) ?? 0;
    if (n == 0) return 0;
    int sign = (n % 2 == 0) ? -1 : 1;
    int multiplier = ((n + 1) ~/ 2);
    return (multiplier * Connections.discreteness) * sign;
  }
}
