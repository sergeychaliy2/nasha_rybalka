/// Глобальные коэффициенты игры (баланс), правятся из админки.
///
/// Дефолты совпадают с историческим поведением. Оверрайды применяются на
/// старте (`ContentOverrides.applyToGame`), поэтому геймплей читает эти
/// статические поля напрямую — без прокидывания через конструкторы.
class Tuning {
  // --- Прокачка ---------------------------------------------------------------
  /// Граммы для перехода с 1-го на 2-й уровень (базовый шаг кривой).
  static double levelBase = 3000;

  /// Показатель кривой прокачки: требуется(level) = base * (level-1)^exp.
  static double levelExponent = 1.25;

  // --- Энергия ----------------------------------------------------------------
  static int maxEnergy = 100;
  static int energyRegenSeconds = 300;
  static int energyPerCast = 3;

  // --- Клёв -------------------------------------------------------------------
  /// Множитель шанса для видов семейства активной прикормки.
  static double chumBoost = 2.6;

  /// Множители шанса клёва по редкости вида (легендарные клюют реже).
  static double rarityCommon = 1.0;
  static double rarityUncommon = 0.7;
  static double rarityRare = 0.45;
  static double rarityTrophy = 0.28;
  static double rarityLegendary = 0.15;

  // --- Погода -----------------------------------------------------------------
  /// Сдвиг вероятности осадков в прогнозе: >0 — дожди чаще, <0 — реже.
  static double precipBias = 0;

  /// Множитель клёва в окно «перед дождём» (примета: рыба жаднее).
  static double preRainBiteBonus = 1.25;

  static void reset() => applyJson(const {});

  static Map<String, dynamic> toJson() => {
        'levelBase': levelBase,
        'levelExponent': levelExponent,
        'maxEnergy': maxEnergy,
        'energyRegenSeconds': energyRegenSeconds,
        'energyPerCast': energyPerCast,
        'chumBoost': chumBoost,
        'rarityCommon': rarityCommon,
        'rarityUncommon': rarityUncommon,
        'rarityRare': rarityRare,
        'rarityTrophy': rarityTrophy,
        'rarityLegendary': rarityLegendary,
        'precipBias': precipBias,
        'preRainBiteBonus': preRainBiteBonus,
      };

  static void applyJson(Map<String, dynamic> j) {
    double d(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    int i(String k, int def) => (j[k] as num?)?.toInt() ?? def;
    levelBase = d('levelBase', 3000);
    levelExponent = d('levelExponent', 1.25);
    maxEnergy = i('maxEnergy', 100);
    energyRegenSeconds = i('energyRegenSeconds', 300);
    energyPerCast = i('energyPerCast', 3);
    chumBoost = d('chumBoost', 2.6);
    rarityCommon = d('rarityCommon', 1.0);
    rarityUncommon = d('rarityUncommon', 0.7);
    rarityRare = d('rarityRare', 0.45);
    rarityTrophy = d('rarityTrophy', 0.28);
    rarityLegendary = d('rarityLegendary', 0.15);
    precipBias = d('precipBias', 0);
    preRainBiteBonus = d('preRainBiteBonus', 1.25);
  }
}
