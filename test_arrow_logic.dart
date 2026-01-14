// Тестовая реализация для демонстрации логики
import 'package:flutter/material.dart';

// Упрощенная модель узла для тестирования
class TestNode {
  final String id;
  final String? parent;
  final bool? isCollapsed;
  
  TestNode({
    required this.id,
    this.parent,
    this.isCollapsed,
  });
}

// Моделируем логику нашего нового метода
class TestArrowPainter {
  final Map<String, TestNode> _nodeMap;
  
  TestArrowPainter(List<TestNode> nodes) : _nodeMap = {for (var node in nodes) node.id: node};
  
  /// Проверяет, является ли узел скрытым из-за свернутого родителя
  bool _isNodeHiddenByCollapsedParent(TestNode node) {
    String? currentParentId = node.parent;
    
    // Проверяем всю цепочку родителей
    while (currentParentId != null) {
      TestNode? parentNode = _nodeMap[currentParentId];
      if (parentNode != null && parentNode.isCollapsed == true) {
        return true;
      }
      // Переходим к следующему родителю
      currentParentId = parentNode?.parent;
    }
    
    return false;
  }
  
  void testLogic() {
    print('=== Тестирование логики скрытия узлов ===');
    
    // Создаем тестовые узлы: 
    // grandparent (свернут) -> parent -> child
    final grandparent = TestNode(id: 'grandparent', isCollapsed: true);
    final parent = TestNode(id: 'parent', parent: 'grandparent');
    final child = TestNode(id: 'child', parent: 'parent');
    
    // Узел, который не связан с свернутым родителем
    final unrelated = TestNode(id: 'unrelated');
    
    final nodes = [grandparent, parent, child, unrelated];
    final painter = TestArrowPainter(nodes);
    
    print('grandparent скрыт: ${painter._isNodeHiddenByCollapsedParent(grandparent)}'); // false, потому что у него нет родителя
    print('parent скрыт: ${painter._isNodeHiddenByCollapsedParent(parent)}'); // true, потому что grandparent свернут
    print('child скрыт: ${painter._isNodeHiddenByCollapsedParent(child)}'); // true, потому что у него есть свернутый родитель (grandparent)
    print('unrelated скрыт: ${painter._isNodeHiddenByCollapsedParent(unrelated)}'); // false, потому что у него нет родителя
    
    print('\n=== Дополнительный тест: обычный развернутый родитель ===');
    final expandedGrandParent = TestNode(id: 'expanded_grandparent', isCollapsed: false);
    final expandedParent = TestNode(id: 'expanded_parent', parent: 'expanded_grandparent');
    final expandedChild = TestNode(id: 'expanded_child', parent: 'expanded_parent');
    
    final expandedNodes = [expandedGrandParent, expandedParent, expandedChild];
    final expandedPainter = TestArrowPainter(expandedNodes);
    
    print('expanded_parent скрыт: ${expandedPainter._isNodeHiddenByCollapsedParent(expandedParent)}'); // false, потому что родитель не свернут
    print('expanded_child скрыт: ${expandedPainter._isNodeHiddenByCollapsedParent(expandedChild)}'); // false, потому что родители не свернуты
  }
}

void main() {
  final test = TestArrowPainter([]);
  test.testLogic();
}