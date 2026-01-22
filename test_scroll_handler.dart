// Простой тестовый файл для проверки логики
import 'dart:math' as math;

void main() {
  // Тестирование логики масштабирования
  print("Тестирование логики масштабирования и центрирования");
  
  // Предположим, у нас есть видимая область 800x600
  double viewportWidth = 800.0;
  double viewportHeight = 600.0;
  
  // А узлы занимают область 2000x1000
  double contentWidth = 2000.0;
  double contentHeight = 1000.0;
  
  // Оставляем отступ
  double padding = 50.0;
  
  // Масштаб по ширине и высоте
  double scaleX = (viewportWidth - padding * 2) / contentWidth;
  double scaleY = (viewportHeight - padding * 2) / contentHeight;
  
  print("Масштаб по X: ${scaleX.toStringAsFixed(3)}");
  print("Масштаб по Y: ${scaleY.toStringAsFixed(3)}");
  
  // Берем минимальный масштаб
  double targetScale = math.min(scaleX, scaleY);
  print("Целевой масштаб: ${targetScale.toStringAsFixed(3)}");
  
  // Проверим, что он в пределах допустимого диапазона
  double minScale = 0.35;
  double maxScale = 5.0;
  targetScale = math.max(minScale, math.min(maxScale, targetScale));
  print("Ограниченный масштаб: ${targetScale.toStringAsFixed(3)}");
  
  // Центрируем
  double contentCenterX = 1000.0; // центр контента
  double contentCenterY = 500.0;  // центр контента
  
  double centerX = viewportWidth / 2 - contentCenterX * targetScale;
  double centerY = viewportHeight / 2 - contentCenterY * targetScale;
  
  print("Смещение X: ${centerX.toStringAsFixed(2)}");
  print("Смещение Y: ${centerY.toStringAsFixed(2)}");
}