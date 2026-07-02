import 'package:flutter/widgets.dart';

/// Помощники адаптивности. «Компактный» режим — телефоны (короткая сторона
/// экрана меньше планшета): там всё крупное для ПК не влезает, поэтому
/// уменьшаем размеры/отступы/шрифты.
extension Responsive on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);

  /// Телефон (в т.ч. ландшафтный): короткая сторона < 600 dp.
  bool get compact => MediaQuery.sizeOf(this).shortestSide < 600;

  /// Очень маленький экран по высоте (низкий ландшафт).
  bool get shortScreen => MediaQuery.sizeOf(this).height < 430;

  /// Выбор значения: обычное / компактное.
  T rv<T>(T normal, T compactValue) => compact ? compactValue : normal;

  /// Масштаб для компактных экранов (1.0 на планшете/ПК, меньше на телефоне).
  double get uiScale => compact ? (shortScreen ? 0.78 : 0.85) : 1.0;
}
