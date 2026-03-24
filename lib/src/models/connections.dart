import 'dart:async';

import 'package:fbpmn/src/models/connection.dart';

class Connections {
  Set<Connection?>? top;
  Set<Connection?>? right;
  Set<Connection?>? bottom;
  Set<Connection?>? left;

  static double discreteness = 12.0;

  final _changesController = StreamController<String>.broadcast();
  Stream<String> get changesStream => _changesController.stream;

  Connections({this.top, this.right, this.bottom, this.left}) {
    top = {};
    right = {};
    bottom = {};
    left = {};
  }

  Map<String, Set<Connection?>> _toMap() {
    return {'top': top!, 'right': right!, 'bottom': bottom!, 'left': left!};
  }

  Set<Connection?>? get(String side) {
    var mapRep = _toMap();
    if (mapRep.containsKey(side)) {
      return mapRep[side];
    }
    throw ArgumentError('propery not found');
  }

  int length(String side) {
    final sideProp = get(side);
    return sideProp?.length ?? 0;
  }

  void _compactSideConnections(Set<Connection?> sideConnections) {
    if (sideConnections.isEmpty) {
      return;
    }

    final sortedList = sideConnections.toList();
    sortedList.sort((a, b) => (a?.index ?? 0).compareTo(b?.index ?? 0));

    for (int i = 0; i < sortedList.length; i++) {
      sortedList[i]!.index = i;
    }

    sideConnections
      ..clear()
      ..addAll(sortedList);
  }

  void compactAll() {
    _compactSideConnections(top!);
    _compactSideConnections(right!);
    _compactSideConnections(bottom!);
    _compactSideConnections(left!);
  }

  remove(String arrowId) {
    final oldLength = top!.length + right!.length + bottom!.length + left!.length;
    top = top!.where((connect) => connect!.id != arrowId).toSet();
    right = right!.where((connect) => connect!.id != arrowId).toSet();
    bottom = bottom!.where((connect) => connect!.id != arrowId).toSet();
    left = left!.where((connect) => connect!.id != arrowId).toSet();

    _compactSideConnections(top!);
    _compactSideConnections(right!);
    _compactSideConnections(bottom!);
    _compactSideConnections(left!);

    final newLength = top!.length + right!.length + bottom!.length + left!.length;
    
    if (oldLength != newLength) {
      _changesController.add('remove');
    }
  }

  removeAll() {
    final hadConnections = top!.isNotEmpty || right!.isNotEmpty || bottom!.isNotEmpty || left!.isNotEmpty;
    top!.clear();
    right!.clear();
    bottom!.clear();
    left!.clear();
    
    if (hadConnections) {
      _changesController.add('removeAll');
    }
  }

  Connection? add(String side, String arrowId) {
    final sideProp = get(side);
    final connection = sideProp?.firstWhere(
      (conn) => conn!.id == arrowId,
      orElse: () => null,
    );

    if (connection != null) {
      return connection;
    }

    // Удаляем коннектор со всех других сторон, если он там есть
    final sides = ['top', 'right', 'bottom', 'left'];
    for (final otherSide in sides) {
      if (otherSide != side) {
        final otherSideProp = get(otherSide);
        final oldLength = otherSideProp?.length ?? 0;
        final filtered = otherSideProp?.where((conn) => conn!.id != arrowId).toSet();
        if (filtered != null && filtered.length != oldLength) {
          // Обновляем сторону с отфильтрованными коннектами
          switch (otherSide) {
            case 'top':
              top = filtered;
              _compactSideConnections(top!);
              break;
            case 'right':
              right = filtered;
              _compactSideConnections(right!);
              break;
            case 'bottom':
              bottom = filtered;
              _compactSideConnections(bottom!);
              break;
            case 'left':
              left = filtered;
              _compactSideConnections(left!);
              break;
          }
        }
      }
    }

    final newConn = Connection(id: arrowId);

    final existingIndexes = sideProp!
        .whereType<Connection>()
        .map((conn) => conn.index)
        .whereType<int>()
        .toSet();

    int nextIndex = 0;

    while (existingIndexes.contains(nextIndex)) {
      nextIndex++;
    }

    newConn.index = nextIndex;
    sideProp.add(newConn);

    final sidePropList = sideProp.toList();

    sidePropList.sort((a, b) => a!.index!.compareTo(b!.index!));
    sideProp.clear();
    sideProp.addAll(sidePropList);

    _changesController.add('add, all on sides left: ${get('left')?.length} top: ${get('top')?.length} right: ${get('right')?.length} bottom: ${get('bottom')?.length}');
    return newConn;
  }

  double getSideDelta(String side, Connection connection) {
    final n = connection.index ?? 0;
    if (n == 0) return 0;
    int sign = (n % 2 == 0) ? -1 : 1;
    int multiplier = ((n + 1) ~/ 2);
    return (multiplier * Connections.discreteness) * sign;
  }

  void dispose() {
    top?.clear();
    right?.clear();
    bottom?.clear();
    left?.clear();
    _changesController.close();
  }
}
