/// Простая числовая пружина для «живой» физики изгиба удилища и поплавка.
///
/// Критически/недо-демпфированная пружина даёт естественный хлёсткий ход:
/// при забросе удилище перехлёстывает цель и затухает, как настоящее.
class Spring {
  Spring({
    double value = 0,
    this.stiffness = 180,
    this.damping = 14,
  })  : _value = value,
        target = value;

  double _value;
  double _velocity = 0;

  /// Цель, к которой стремится пружина.
  double target;

  /// Жёсткость — как быстро тянет к цели.
  double stiffness;

  /// Затухание — насколько сильно гасит колебания.
  /// Меньше damping → больше «хлыста» и пружинистости на кончике.
  double damping;

  double get value => _value;
  double get velocity => _velocity;

  /// Мгновенно установить значение (без анимации).
  void snapTo(double v) {
    _value = v;
    target = v;
    _velocity = 0;
  }

  /// Толчок по скорости — для эффекта рывка/подсечки.
  void impulse(double v) => _velocity += v;

  /// Полу-неявный Эйлер: устойчив на больших dt.
  void update(double dt) {
    // Защита от скачков при просадке кадров.
    final step = dt.clamp(0.0, 1 / 30);
    final force = (target - _value) * stiffness - _velocity * damping;
    _velocity += force * step;
    _value += _velocity * step;
  }

  bool get isSettled =>
      (target - _value).abs() < 0.0005 && _velocity.abs() < 0.0005;
}
