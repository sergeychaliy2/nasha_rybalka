import 'dart:math' as math;

import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/fish_species.dart';
import '../../domain/entities/fishing_location.dart';
import '../../domain/entities/gear.dart';
import '../../domain/entities/player.dart';
import '../../domain/services/bite_calculator.dart';
import '../../domain/services/tuning.dart';
import '../../domain/value_objects/currency.dart';
import '../../domain/value_objects/fishing_enums.dart';
import '../../domain/value_objects/weight.dart';
import '../../shared/content_images.dart';
import '../../shared/rendering/fish_icons.dart';
import '../../shared/sound_service.dart';
import '../../shared/rendering/gear_icons.dart';
import '../../shared/rendering/spring.dart';
import '../gear/gear_tab.dart';
import '../map/russia_geo.dart';
import '../shell/ui_kit.dart';
import '../tournaments/tournament.dart';
import '../weather/weather_forecast.dart';
import 'depth_model.dart';
import 'echo_sounder_device.dart';
import 'fishing_painter.dart';
import 'water_masks.dart';

/// Фазы рыбалки на локации.
enum Phase { freeWater, casting, waiting, bite, fight, landed }

/// Полноценная сцена ловли: фотофон локации + Canvas-снасть с физикой,
/// подключённая к доменному ядру.
///
/// • Поклёвку определяет [BiteCalculator] по пулу видов локации и текущим
///   условиям (приманка/время/погода/глубина) — клюёт конкретный вид.
/// • Улов начисляется через [PlayerController.recordCatch] (серебро/опыт,
///   рост уровня, открытие вида в бестиарии).
/// • Снасть и эхолот берутся из [Loadout] игрока.
class FishingScreen extends ConsumerStatefulWidget {
  const FishingScreen({super.key, required this.locationId});

  final String locationId;

  @override
  ConsumerState<FishingScreen> createState() => _FishingScreenState();
}

class _FishingScreenState extends ConsumerState<FishingScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _time = 0;
  final _rnd = math.Random();
  static const _depthModel = DepthModel();

  // Снасть.
  final Spring _bend = Spring(value: 0.07, stiffness: 70, damping: 8);
  final Spring _floatDip = Spring(value: 0, stiffness: 130, damping: 12);
  final Spring _rodPull = Spring(value: 0, stiffness: 60, damping: 9);

  // Эффекты воды.
  final List<Ripple> _ripples = [];
  final List<Splash> _splashes = [];
  final List<FishSwirl> _swirls = [];

  // Разрешённая оснастка/контент (готовится в [_init]).
  bool _ready = false;
  String? _error;
  late FishingLocation _loc;
  late List<(SpeciesSpawn, FishSpecies)> _pool;
  RodItem? _rod;
  ReelItem? _reel;
  LureItem? _lure;
  EchoSounderItem? _echo;
  bool _echoOn = false; // открыто ли устройство-эхолот на воде
  FishingMode _mode = FishingMode.float;
  late List<GearItem> _catalog;
  late Map<String, GearItem> _gearById;

  // Условия сессии (влияют на алгоритм поклёвки).
  // Время суток циклится, пока приманка в воде; погода детерминирована локацией.
  TimeOfDay _timeOfDay = TimeOfDay.morning;
  Weather _weather = Weather.cloudy;
  double _dayClock = 0; // секунды «в воде» для смены времени суток
  static const _stageSeconds = 60.0; // длительность стадии (утро/день/...)
  int get _energyPerCast => Tuning.energyPerCast; // расход энергии на заброс
  DepthSample? _lastDepth;

  late final BiteCalculator _biteCalc;

  Phase _phase = Phase.freeWater;
  Offset _floatN = const Offset(0.42, 0.60);
  Offset _castTarget = const Offset(0.42, 0.60);
  static const _launchN = Offset(0.60, 0.06);

  double _castT = 0;
  double _lineTaut = 0;
  double _stateTimer = 0;
  double _rollTimer = 0;
  static const _rollEvery = 2.0; // как часто «проверяем» поклёвку
  double _biteWindow = 0;
  double _nextSwirl = 2;
  double _chumUntil = 0; // прикормка действует, пока _time < _chumUntil
  Set<String> _chumGroups = const {}; // активные биол. семейства прикормки
  double _retrieveT = 0; // прогресс проводки спиннинга (0 — заброс, 1 — у берега)
  double _castFar = 0; // дальность заброса 0..1 (дальше → медленнее проводка)
  double _depthFrac = 0.5; // спуск поплавка: 0 — у поверхности, 1 — у дна
  int _biteStyle = 0; // игра поплавка: 0 окунается, 1 подёргивания, 2 ведёт
  double _biteDrift = 1; // сторона увода при «ведёт»

  // Вываживание.
  double _tension = 0.5;
  bool _reeling = false;
  double _fightProgress = 0;
  double _reelAngle = 0;
  double _dangerHold = 0;
  double _slackHold = 0;
  double _power = 0.5; // тяжесть рыбы относительно удилища
  double _smooth = 0.5; // мягкость катушки

  // Что клюнуло сейчас (рыба) либо зацеп «мусора».
  BiteResult? _pending;
  FishSpecies? _pendingSpecies;
  TrashSpawn? _pendingTrash;

  // Ресурсные предупреждения (наживка/приманка).
  String? _alertTitle;
  String? _alertSub;
  Color _alertColor = kGold;
  double _alertUntil = 0;
  bool _alertReplaceAction = false;
  bool _warnedLowBait = false;

  // Уведомление о приближающемся ненастье (по прогнозу локации).
  double _wxShowAt = -1; // время появления по _time; <0 — не показывать
  int _wxRainHours = 0;
  bool _wxRainSnow = false;

  /// Дождь реально начнётся в сессии в этот момент [_time] (<0 — не ожидается).
  /// 1 «час» прогноза = 90 секунд сессии; до начала действует бонус клёва
  /// «перед дождём» (Tuning.preRainBiteBonus).
  double _rainStartAt = -1;
  bool _rainStarted = false;

  // Карточка результата.
  bool _decided = false;
  CatchOutcome? _outcome;

  // Турнир: защита от повторного завершения зачёта.
  bool _tournamentDone = false;

  static const _greenLo = 0.40;
  static const _greenHi = 0.76;

  @override
  void initState() {
    super.initState();
    _biteCalc = ref.read(biteCalculatorProvider);
    _ticker = createTicker(_onTick);
    _init();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // --- Подготовка контента/оснастки ----------------------------------------

  Future<void> _init() async {
    try {
      final repo = ref.read(contentRepositoryProvider);
      final loc = await repo.locationById(widget.locationId);
      if (loc == null) {
        setState(() => _error = 'Локация не найдена');
        return;
      }
      final allSpecies = await repo.species();
      final byId = {for (final s in allSpecies) s.id: s};
      final pool = <(SpeciesSpawn, FishSpecies)>[];
      for (final spawn in loc.species) {
        final sp = byId[spawn.speciesId];
        if (sp != null) pool.add((spawn, sp));
      }

      final catalog = await repo.gearCatalog();
      _catalog = catalog;
      _gearById = {for (final g in catalog) g.id: g};
      final player = await ref.read(playerControllerProvider.future);
      _resolveRig(player);
      _weather = _weatherFor(loc);
      // Прогноз: если скоро дождь/снег — покажем красивое уведомление на воде.
      final soon = _rainSoon(loc);
      if (soon != null) {
        _wxRainHours = soon.$1;
        _wxRainSnow = soon.$2;
        _wxShowAt = 1.6; // после «шторки» входа
        _rainStartAt = 1.6 + soon.$1 * 90.0; // дождь придёт по-настоящему
      }

      if (!mounted) return;
      setState(() {
        _loc = loc;
        _pool = pool;
        _ready = true;
      });
      _ticker.start();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// Пересобирает активную снасть из лоадаута игрока (вызывается при старте и
  /// после смены снасти в тэклбоксе прямо на воде).
  void _resolveRig(Player p) {
    final l = p.loadout;
    _mode = l.mode;
    final spin = _mode == FishingMode.spinning;
    _rod = _pick<RodItem>(
      _gearById,
      spin ? l.spinningRodId : l.rodId,
      spin ? GearCategory.spinningRod : GearCategory.rod,
      _catalog,
    );
    _reel = _pick<ReelItem>(
      _gearById,
      spin ? l.spinningReelId : l.floatReelId,
      spin ? GearCategory.spinningReel : GearCategory.floatReel,
      _catalog,
    );
    _lure = _pick<LureItem>(
      _gearById,
      spin ? l.lureId : l.baitId,
      null,
      _catalog,
    );
    final echoGear = l.echoSounderId == null
        ? null
        : _gearById[l.echoSounderId];
    _echo = echoGear is EchoSounderItem ? echoGear : null;
    _smooth = _reel?.smoothness ?? 0.5;
  }

  /// Находит предмет нужного типа по id из лоадаута; при пустом слоте — первый
  /// подходящий из каталога (надёжный фолбэк, даже если сейв без снаряжения).
  T? _pick<T extends GearItem>(
    Map<String, GearItem> byId,
    String? id,
    GearCategory? category,
    List<GearItem> catalog,
  ) {
    final bySlot = id == null ? null : byId[id];
    if (bySlot is T) return bySlot;
    for (final g in catalog) {
      if (g is T && (category == null || g.category == category)) return g;
    }
    return null;
  }

  // --- Тик/логика фаз -------------------------------------------------------

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 0.016
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _time += dt;

    _bend.update(dt);
    _floatDip.update(dt);
    _rodPull.update(dt);
    _advance(dt);
    _stepEffects(dt);

    // Суточный цикл идёт только пока приманка в воде (§10 ТЗ).
    if (_phase == Phase.casting ||
        _phase == Phase.waiting ||
        _phase == Phase.bite ||
        _phase == Phase.fight) {
      _dayClock += dt;
      _timeOfDay = TimeOfDay.values[(_dayClock ~/ _stageSeconds).toInt() % 4];
    }

    // Дождь из прогноза докатился до сессии: погода реально меняется
    // (визуал сцены и шансы клёва берут _weather напрямую).
    if (_rainStartAt > 0 && !_rainStarted && _time >= _rainStartAt) {
      _rainStarted = true;
      _weather = Weather.rain;
      SoundService.rainStart();
      _showAlert(
        _wxRainSnow ? 'Пошёл мокрый снег' : 'Пошёл дождь',
        'Погода переменилась — клёв меняется',
        const Color(0xFF5FA8E0),
        seconds: 4,
      );
    }

    setState(() {});
  }

  /// Погода на воде = прогноз «Сейчас» того же водоёма, что и на карте осадков
  /// (тот же детерминированный источник [WeatherForecast]). Так плашка погоды на
  /// сцене совпадает с тем, что игрок видел на карте, и через [BiteConditions]
  /// влияет на клёв.
  Weather _weatherFor(FishingLocation loc) {
    final d = DateTime.now();
    final daySeed = d.year * 1000 + d.month * 31 + d.day; // как в WeatherScreen
    final lat = activeWaterGeo()[loc.id]?.$2 ?? 56.0;
    final wx = WeatherForecast.at(
        locId: loc.id, lat: lat, hourAhead: 0, daySeed: daySeed);
    return switch (wx.kind) {
      WxKind.clear => Weather.clear,
      WxKind.partly => Weather.clear,
      WxKind.cloudy => Weather.cloudy,
      WxKind.rain => Weather.rain,
      WxKind.snow => Weather.rain,
    };
  }

  /// Скоро ли ненастье по прогнозу локации: ищем дождь/снег в ближайшие 3 ч.
  /// Возвращает (через сколько часов, снег ли) или null (если сейчас уже
  /// осадки или их не ожидается).
  (int, bool)? _rainSoon(FishingLocation loc) {
    final d = DateTime.now();
    final daySeed = d.year * 1000 + d.month * 31 + d.day;
    final lat = activeWaterGeo()[loc.id]?.$2 ?? 56.0;
    final now = WeatherForecast.at(
        locId: loc.id, lat: lat, hourAhead: 0, daySeed: daySeed);
    if (now.kind == WxKind.rain || now.kind == WxKind.snow) return null;
    for (var h = 1; h <= 3; h++) {
      final wx = WeatherForecast.at(
          locId: loc.id, lat: lat, hourAhead: h, daySeed: daySeed);
      if (wx.kind == WxKind.rain || wx.kind == WxKind.snow) {
        return (h, wx.kind == WxKind.snow);
      }
    }
    return null;
  }

  /// Тёплый/холодный тинт сцены по времени суток.
  Color _timeTint() => switch (_timeOfDay) {
    TimeOfDay.morning => const Color(0x33FFB066),
    TimeOfDay.day => const Color(0x00000000),
    TimeOfDay.evening => const Color(0x44FF7A3D),
    TimeOfDay.night => const Color(0x66061018),
  };

  void _advance(double dt) {
    _stateTimer += dt;

    switch (_phase) {
      case Phase.freeWater:
        _bend.target = 0.06;
        _rodPull.target = 0;
        _lineTaut = _approach(_lineTaut, 0, dt, 2);
        _ambientLife(dt);
        break;

      case Phase.casting:
        _castT = (_castT + dt / 0.7).clamp(0.0, 1.0);
        if (_castT < 0.30) {
          _bend.target = -0.20;
          _floatN = _launchN;
          _lineTaut = 1;
        } else {
          _bend.target = 0.34 * (1 - (_castT - 0.3));
          final e = ((_castT - 0.30) / 0.70).clamp(0.0, 1.0);
          final eased = Curves.easeIn.transform(e);
          final arc = math.sin(eased * math.pi) * 0.10;
          _floatN = Offset.lerp(_launchN, _castTarget, eased)! - Offset(0, arc);
          _lineTaut = 1;
        }
        if (_castT >= 1) {
          _floatN = _castTarget;
          SoundService.splash();
          _splash(_castTarget, 16, 0.20);
          _ring(_castTarget, 64, 1.0);
          _ring(_castTarget, 38, 0.7);
          _bend.target = 0.08;
          _retrieveT = 0;
          _enter(Phase.waiting);
          _rollTimer = 0;
        }
        break;

      case Phase.waiting:
        _bend.target = 0.08;
        _lineTaut = _approach(_lineTaut, 0.25, dt, 2);
        _ambientLife(dt);
        if (_mode == FishingMode.spinning) {
          // Спиннинг: клёв только во время проводки — удержание катушки тянет
          // приманку к берегу. Без проводки приманка просто стоит, поклёвок нет.
          if (_reeling) {
            // Дальний заброс подматывается дольше.
            _retrieveT =
                (_retrieveT + dt * 0.32 * (1 - 0.5 * _castFar)).clamp(0.0, 1.0);
            // Подтягиваем приманку ВНИЗ к берегу (ближний край воды), не вверх.
            _floatN = Offset.lerp(
              _castTarget,
              Offset(_castTarget.dx, DepthModel.waterBottomN),
              Curves.easeIn.transform(_retrieveT),
            )!;
            _bend.target = 0.14 + 0.05 * math.sin(_time * 11);
            _rollTimer += dt;
            if (_rollTimer >= _rollEvery * 0.7) {
              _rollTimer = 0;
              _tryBite();
            }
            if (_retrieveT >= 1) _resetToFreeWater(); // приманка у берега
          }
        } else {
          // Поплавок: пассивный клёв по таймеру (прикормка ускоряет).
          _rollTimer += dt;
          final every = _time < _chumUntil ? _rollEvery * 0.6 : _rollEvery;
          if (_rollTimer >= every) {
            _rollTimer = 0;
            _tryBite();
          }
        }
        break;

      case Phase.bite:
        _lineTaut = _approach(_lineTaut, 1, dt, 6);
        if (_mode == FishingMode.float) {
          _bend.target = 0.14;
          switch (_biteStyle) {
            case 0: // окунается — поплавок уходит под воду
              _floatDip.target = 0.95;
            case 1: // подёргивания — частые мелкие рывки
              _floatDip.target =
                  0.2 + 0.45 * (0.5 + 0.5 * math.sin(_time * 20));
              if (_rnd.nextDouble() < dt * 9) _ring(_floatN, 20, 0.7);
            default: // ведёт/приподнимает — поплавок всплывает и идёт в сторону
              _floatDip.target = 0.05;
              _floatN = Offset(
                (_floatN.dx + _biteDrift * dt * 0.03).clamp(0.06, 0.94),
                _floatN.dy,
              );
          }
        } else {
          // Спиннинг: поплавка нет — грузится кончик удилища.
          _bend.target = 0.30 + math.sin(_time * 9) * 0.05;
        }
        if (_rnd.nextDouble() < dt * 5) _ring(_floatN, 24, 0.6);
        if (_stateTimer >= _biteWindow) _missBite();
        break;

      case Phase.fight:
        _stepFight(dt);
        break;

      case Phase.landed:
        _bend.target = 0.05;
        _rodPull.target = 0;
        _floatDip.target = 0;
        break;
    }
  }

  /// «Выходы рыбы»: частота отражает плотность видов локации (много рыбы —
  /// чаще буруны), размер буруна — вес конкретной рыбы (крупная — большой
  /// всплеск). Так на глаз читается, много ли рыбы и крупная ли она.
  void _ambientLife(double dt) {
    _nextSwirl -= dt;
    if (_nextSwirl > 0) return;
    // Активность точки и масштаб «самой крупной» — из пула видов.
    var activity = 0.0;
    var maxG = 1;
    for (final (spawn, sp) in _pool) {
      activity += (spawn.floatChance + spawn.spinningChance) / 2;
      if (sp.weightMax.grams > maxG) maxG = sp.weightMax.grams;
    }
    // Чем выше активность — тем короче интервал между выходами.
    final interval =
        (3.5 / activity.clamp(0.35, 4.0)) * (0.65 + _rnd.nextDouble() * 0.9);
    _nextSwirl = interval.clamp(0.8, 7.0);

    // Размер выхода — по весу случайной рыбы (с тем же смещением к мелкому).
    var sizeFrac = 0.3;
    final pick = _pickAmbient();
    if (pick != null) {
      final lo = pick.$2.weightMin.grams;
      final hi = pick.$2.weightMax.grams;
      final t = math.pow(_rnd.nextDouble(), 2.6).toDouble();
      final g = lo + (hi - lo) * t;
      sizeFrac = (g / maxG).clamp(0.08, 1.0);
    }
    // «Выход» рыбы — только по воде (не на островах/берегу): пробуем точки.
    Offset? p;
    for (var tries = 0; tries < 12; tries++) {
      final cand = Offset(
        0.06 + _rnd.nextDouble() * 0.82,
        0.46 + _rnd.nextDouble() * 0.30,
      );
      if (waterAt(_bgStem, cand.dx, cand.dy)) {
        p = cand;
        break;
      }
    }
    if (p == null) return; // воды не нашли — без выхода
    _swirls.add(FishSwirl(
      posN: p,
      life: 1.0 + sizeFrac * 0.8,
      dir: _rnd.nextBool() ? 1 : -1,
      scale: 0.7 + sizeFrac * 1.7,
    ));
    _ring(p, 20 + sizeFrac * 55, 0.5 + sizeFrac * 0.3);
    _splash(p, 3 + (sizeFrac * 8).round(), 0.04 + sizeFrac * 0.12);
  }

  /// Случайный вид локации, взвешенный по базовому шансу (для «выходов рыбы»).
  (SpeciesSpawn, FishSpecies)? _pickAmbient() {
    if (_pool.isEmpty) return null;
    var total = 0.0;
    for (final (spawn, _) in _pool) {
      total += (spawn.floatChance + spawn.spinningChance) / 2;
    }
    if (total <= 0) return _pool[_rnd.nextInt(_pool.length)];
    var pick = _rnd.nextDouble() * total;
    for (final e in _pool) {
      pick -= (e.$1.floatChance + e.$1.spinningChance) / 2;
      if (pick <= 0) return e;
    }
    return _pool.last;
  }

  /// Проба поклёвки доменным алгоритмом. Клюёт — если [BiteCalculator] вернул вид.
  void _tryBite() {
    // Иногда вместо рыбы цепляется «мусор» (§9.8) — коряга/сеть и т.п.
    for (final t in _loc.trash) {
      if (_rnd.nextDouble() < t.chance) {
        _pendingTrash = t;
        _pending = null;
        _pendingSpecies = null;
        _startBite();
        return;
      }
    }
    if (_pool.isEmpty) return;
    final result = _biteCalc.roll(_pool, _conditions(), _rnd);
    if (result == null) return;
    _pendingTrash = null;
    _pendingSpecies = _pool
        .where((e) => e.$2.id == result.speciesId)
        .firstOrNull
        ?.$2;
    // Навык «Чутьё на трофей» подтягивает вес к максимуму вида.
    final bias = ref.read(skillEffectsProvider).trophyBias;
    if (bias > 0 && _pendingSpecies != null) {
      final maxG = _pendingSpecies!.weightMax.grams;
      final boosted = (result.weight.grams * (1 + bias)).round().clamp(0, maxG);
      _pending = BiteResult(
        speciesId: result.speciesId,
        weight: Weight.grams(boosted),
      );
    } else {
      _pending = result;
    }
    _startBite();
  }

  BiteConditions _conditions() {
    var bonus =
        (_timeOfDay == TimeOfDay.morning && _loc.morningBonusMinutes > 0)
        ? 1.25
        : 1.0;
    // Премиум «Путина»/«Сезон»: клёв активнее на 15 %.
    final tier =
        ref.read(playerControllerProvider).value?.activePremiumTier ?? 0;
    if (tier >= 2) bonus *= 1.15;
    // Навык «Острый глаз».
    bonus *= 1 + ref.read(skillEffectsProvider).biteBonus;
    // Прикормка: пока действует — точка клюёт активнее.
    if (_time < _chumUntil) bonus *= 1.6;
    // Примета «перед дождём»: пока дождь надвигается, но ещё не начался,
    // рыба жаднее (коэффициент правится в админке).
    if (_rainStartAt > 0 && !_rainStarted) bonus *= Tuning.preRainBiteBonus;
    return BiteConditions(
      mode: _mode,
      lureTypeCode: _lure?.lureType.code ?? LureType.worm.code,
      lureSize: _lure?.size ?? LureSize.medium,
      lureColor: _lure?.color ?? LureColor.natural,
      time: _timeOfDay,
      weather: _weather,
      // Поплавок: глубина из выставленного спуска; спиннинг: глубина проводки.
      depthZone: _mode == FishingMode.float
          ? _setDepthZone()
          : (_lastDepth?.zone ?? DepthZone.mid),
      locationBonus: bonus,
      // Прикормка по биологическим семействам действует, пока активна.
      chumGroups: _time < _chumUntil ? _chumGroups : const {},
    );
  }

  /// Зона глубины из выставленного спуска поплавка (мелко→средне→свал→яма).
  DepthZone _setDepthZone() {
    if (_depthFrac < 0.25) return DepthZone.shallow;
    if (_depthFrac < 0.55) return DepthZone.mid;
    if (_depthFrac < 0.80) return DepthZone.dropOff;
    return DepthZone.pit;
  }

  void _startBite() {
    HapticFeedback.mediumImpact();
    _floatDip.snapTo(0.2);
    _ring(_floatN, 30, 0.8);
    // Поплавок играет по-разному: окунается / подёргивается / ведёт.
    if (_mode == FishingMode.float) {
      _biteStyle = _rnd.nextInt(3);
      _biteDrift = _rnd.nextBool() ? 1.0 : -1.0;
    }
    _enter(Phase.bite);
    // Навык «Реакция» удлиняет окно подсечки.
    _biteWindow = 2.2 + ref.read(skillEffectsProvider).strikeWindow;
    // Наживка/приманка расходуется при РАЗРЕШЕНИИ поклёвки (промах/улов/сход),
    // а не на старте — см. _missBite/_land/_fishOff.
  }

  /// Остаток активной наживки/приманки в рюкзаке.
  int _activeBaitQty(Player? p) {
    if (p == null || _lure == null) return 0;
    return p.inventory
        .where((e) => e.gearId == _lure!.id)
        .fold<int>(0, (s, e) => s + e.quantity);
  }

  /// Тратит единицу активного расходника и показывает пороговые предупреждения.
  Future<void> _consumeActiveBait(String what) async {
    final lure = _lure;
    if (lure == null) return;
    final left = await ref
        .read(playerControllerProvider.notifier)
        .consumeBait(lure.id);
    if (!mounted || left < 0) return;
    if (left == 0) {
      _showAlert(
        '$what закончилась!',
        'Заброс недоступен — замени из рюкзака',
        const Color(0xFFE5483B),
        replaceAction: true,
        seconds: 6,
      );
    } else if (left <= 5 && !_warnedLowBait) {
      _warnedLowBait = true;
      _showAlert(
        '$what заканчивается',
        'Осталось: $left шт.',
        kGold,
        replaceAction: true,
        seconds: 4,
      );
    }
  }

  /// Красивое уведомление поверх сцены (с кнопкой «Заменить» при нужде).
  void _showAlert(
    String title,
    String sub,
    Color color, {
    bool replaceAction = false,
    double seconds = 4,
  }) {
    _alertTitle = title;
    _alertSub = sub;
    _alertColor = color;
    _alertReplaceAction = replaceAction;
    _alertUntil = _time + seconds;
  }

  void _missBite() {
    _floatDip.target = 0;
    _ring(_floatN, 40, 0.7);
    _pending = null;
    _pendingSpecies = null;
    _pendingTrash = null;
    if (_mode == FishingMode.float) {
      // Поплавок: не подсёк — рыба утащила наживку. Сматываем для переброса.
      _consumeActiveBait('Наживка');
      _resetToFreeWater();
    } else {
      // Спиннинг: приманка цела (многоразовая), продолжаем проводку.
      _enter(Phase.waiting);
      _rollTimer = 0;
    }
  }

  void _strike() {
    if (_phase != Phase.bite) return;
    HapticFeedback.heavyImpact();
    _bend.impulse(6);
    _floatDip.snapTo(0);
    _splash(_floatN, 10, 0.12);
    _ring(_floatN, 44, 0.9);
    _beginFight();
  }

  void _beginFight() {
    if (_pendingTrash != null) {
      // «Мусор» вытаскивается легко.
      _power = 0.4;
      _tension = 0.55;
      _fightProgress = 0;
      _dangerHold = 0;
      _slackHold = 0;
      _enter(Phase.fight);
      return;
    }
    // Сложность от снасти: тяжёлая рыба у предела удилища тянет сильнее,
    // мягкая катушка гасит рывки.
    final rodMax = (_rod?.maxWeight.grams ?? 3000).toDouble();
    final fishG = (_pending?.weight.grams ?? 1000).toDouble();
    _power = (fishG / rodMax).clamp(0.15, 1.6);
    _tension = 0.55;
    _fightProgress = 0;
    _dangerHold = 0;
    _slackHold = 0;
    _enter(Phase.fight);
    if (_power > 1.0) {
      _toast('Рыба тяжелее удилища — риск обрыва!');
    }
  }

  void _stepFight(double dt) {
    final fx = ref.read(skillEffectsProvider);
    // Рывки рыбы — сумма гармоник; амплитуда растёт с тяжестью рыбы.
    final fishPull =
        (0.34 +
            0.22 * math.sin(_time * 2.4) +
            0.14 * math.sin(_time * 6.1 + 1)) *
        (0.7 + 0.5 * _power);
    // Навык «Плавный ход» добавляет к подмотке.
    final reelGain = _reeling
        ? (0.95 * (0.7 + 0.5 * _smooth) + fx.reelGain)
        : 0.0;
    _tension += (reelGain - fishPull) * dt;
    _tension = _tension.clamp(0.0, 1.0);

    final inGreen = _tension >= _greenLo && _tension <= _greenHi;
    if (inGreen && _reeling) {
      // Навык «Терпение» ускоряет прогресс вываживания.
      _fightProgress +=
          (0.16 + 0.10 * _smooth) /
          (0.7 + 0.6 * _power) *
          (1 + fx.fightProgress) *
          dt;
    }

    if (_reeling) _reelAngle += dt * (9 + 6 * _smooth);

    // Поза удилища: кончик нагружен к поплавку (bend), а сам бланк при подмотке
    // заводится к игроку (pull); на рывке рыбы — отпускается вперёд.
    _bend.target = 0.24 + _tension * 0.5 + fishPull * 0.18;
    var pullT = _reeling ? 0.82 : 0.20;
    pullT -= (fishPull - 0.34).clamp(0.0, 1.0) * 0.5;
    _rodPull.target = pullT.clamp(0.05, 0.95);

    // Опасные зоны: перетяг (обрыв) / слабина (сход). Перетяг острее на рыбе
    // тяжелее удилища; навык «Крепкая рука» добавляет запас.
    final breakLimit = (_power > 1.0 ? 0.9 : 1.3) + fx.breakForgive;
    if (_tension > 0.95) {
      // Навык «Хладнокровие» замедляет накопление перетяга.
      _dangerHold += dt * (1 - fx.dangerSlow);
      if (_dangerHold > breakLimit) return _breakOff();
    } else {
      _dangerHold = math.max(0, _dangerHold - dt);
    }
    if (_tension < 0.05) {
      _slackHold += dt;
      // Навык «Чуткая снасть» даёт больше времени до схода.
      if (_slackHold > 1.6 + fx.lineForgive) return _fishOff();
    } else {
      _slackHold = math.max(0, _slackHold - dt);
    }

    // Вываживание тянет рыбу ВНИЗ к берегу (ближний край воды), не вверх.
    _floatN = Offset.lerp(
      _castTarget,
      Offset(_castTarget.dx, DepthModel.waterBottomN),
      _fightProgress * 0.85,
    )!;
    if (_rnd.nextDouble() < dt * 5) _ring(_floatN, 22, 0.5);

    if (_fightProgress >= 1) _land();
  }

  void _breakOff() {
    _bend.impulse(-7);
    _pending = null;
    _pendingSpecies = null;
    _pendingTrash = null;
    _enter(Phase.freeWater);
    _floatN = _launchN;
    _toast('Обрыв! Перетянул леску.');
    // Спиннинг: обрыв уносит приманку.
    if (_mode == FishingMode.spinning) _consumeActiveBait('Приманка');
  }

  void _fishOff() {
    // Сход: для поплавка наживка потеряна.
    if (_mode == FishingMode.float) _consumeActiveBait('Наживка');
    _pending = null;
    _pendingSpecies = null;
    _pendingTrash = null;
    _enter(Phase.freeWater);
    _floatN = _launchN;
    _toast('Сход. Рыба сорвалась.');
  }

  void _land() {
    HapticFeedback.heavyImpact();
    // Наживка использована (поплавок). Приманка спиннинга — многоразовая.
    if (_mode == FishingMode.float && _pendingSpecies != null) {
      _consumeActiveBait('Наживка');
    }
    _splash(_floatN, 22, 0.26);
    _ring(_floatN, 80, 1);
    _ring(_floatN, 50, 0.8);
    _decided = false;
    _outcome = null;
    _enter(Phase.landed);
  }

  // --- Запись улова ---------------------------------------------------------

  Future<void> _decide(bool keep) async {
    final sp = _pendingSpecies;
    final w = _pending?.weight;
    if (sp == null || w == null) {
      _resetToFreeWater();
      return;
    }
    final notifier = ref.read(playerControllerProvider.notifier);
    final outcome = await notifier.recordCatch(sp, w, keep: keep);
    // Турнирный зачёт: вес любой пойманной рыбы идёт в общий результат.
    await notifier.addTournamentWeight(w.grams);
    if (!mounted) return;
    setState(() {
      _decided = true;
      _outcome = outcome;
    });
  }

  // --- Эффекты --------------------------------------------------------------

  void _stepEffects(double dt) {
    for (final r in _ripples) {
      r.age += dt;
    }
    _ripples.removeWhere((r) => r.isDead);
    for (final s in _swirls) {
      s.age += dt;
    }
    _swirls.removeWhere((s) => s.isDead);

    const gravity = 0.9;
    for (final s in _splashes) {
      s.age += dt;
      s.posN += s.velN * dt;
      s.velN = Offset(s.velN.dx * 0.98, s.velN.dy + gravity * dt);
    }
    _splashes.removeWhere((s) => s.isDead);
  }

  /// Масштаб по «дальности»: чем выше точка на воде (меньше dy), тем дальше от
  /// берега и тем мельче должны быть поплавок/круги/брызги (перспектива).
  double _depthScale(double dyN) =>
      (0.5 + ((dyN - 0.44) / 0.36) * 0.5).clamp(0.45, 1.0);

  void _ring(Offset posN, double maxR, double strength) {
    _ripples.add(
      Ripple(
        posN: posN,
        maxRadius: maxR * _depthScale(posN.dy),
        life: 1.4,
        strength: strength,
      ),
    );
  }

  void _splash(Offset posN, int count, double power) {
    final ds = _depthScale(posN.dy);
    for (var i = 0; i < count; i++) {
      final ang = -math.pi / 2 + (_rnd.nextDouble() - 0.5) * 1.8;
      final speed = power * (0.4 + _rnd.nextDouble());
      _splashes.add(
        Splash(
          posN: posN,
          velN: Offset(math.cos(ang), math.sin(ang)) * speed * ds,
          life: 0.5 + _rnd.nextDouble() * 0.4,
          size: (1.4 + _rnd.nextDouble() * 2.2) * ds,
        ),
      );
    }
  }

  // --- Действия игрока ------------------------------------------------------

  /// Ключ маски воды — имя файла фона без пути и расширения (`ru_<id>`).
  String get _bgStem {
    final s = _loc.primaryBackdrop.split('/').last;
    return s.endsWith('.png') ? s.substring(0, s.length - 4) : s;
  }

  /// Ближайшая к [t] точка воды в разумной зоне заброса (или null).
  Offset? _nearestWater(Offset t) {
    for (var r = 1; r <= 12; r++) {
      for (var dy = -r; dy <= r; dy++) {
        for (var dx = -r; dx <= r; dx++) {
          if (dx.abs() != r && dy.abs() != r) continue; // только «кольцо»
          final x = t.dx + dx / kWaterMaskW;
          final y = t.dy + dy / kWaterMaskH;
          if (y < 0.46 || y > 0.82 || x < 0.05 || x > 0.86) continue;
          if (waterAt(_bgStem, x, y)) return Offset(x, y);
        }
      }
    }
    return null;
  }

  void _castTo(Offset localN) {
    if (_phase == Phase.fight || _phase == Phase.bite) return;
    final player = ref.read(playerControllerProvider).value;
    // Без наживки/приманки заброс невозможен — подскажем заменить.
    if (_activeBaitQty(player) <= 0) {
      _showAlert(
        _mode == FishingMode.spinning
            ? 'Приманка закончилась!'
            : 'Наживка закончилась!',
        'Замени из рюкзака, чтобы продолжить',
        const Color(0xFFE5483B),
        replaceAction: true,
        seconds: 5,
      );
      return;
    }
    // Энергия: заброс требует сил. Премиум и турнир — без расхода.
    final freeCast =
        player == null || player.activePremiumTier > 0 || player.inTournament;
    if (!freeCast) {
      if (player.currentEnergy < _energyPerCast) {
        _showLowEnergy(player);
        return;
      }
      ref.read(playerControllerProvider.notifier).spendEnergy(_energyPerCast);
    }
    // Заброс — только в открытую воду по маске локации: не в небо, не на
    // берег/острова/камни. Если тап не по воде — притягиваем к ближайшей воде;
    // совсем нет воды рядом — заброса нет.
    var t = Offset(
      localN.dx.clamp(0.06, 0.84),
      localN.dy.clamp(0.46, 0.82),
    );
    if (!waterAt(_bgStem, t.dx, t.dy)) {
      final nearest = _nearestWater(t);
      if (nearest == null) return;
      t = nearest;
    }
    _castTarget = t;
    // Дальность: чем выше по воде (меньше dy) — тем дальше заброшено.
    _castFar = ((0.74 - t.dy) / (0.74 - 0.48)).clamp(0.0, 1.0);
    _lastDepth = _depthModel.sampleAt(t.dy, _loc.depthProfile);
    _castT = 0;
    _floatDip.snapTo(0);
    _enter(Phase.casting);
    HapticFeedback.selectionClick();
  }

  void _enter(Phase p) {
    // Звуковая обратная связь по ключевым фазам.
    if (p == Phase.bite) SoundService.bite();
    if (p == Phase.landed) SoundService.catchFish();
    setState(() {
      _phase = p;
      _stateTimer = 0;
    });
  }

  void _resetToFreeWater() {
    _pending = null;
    _pendingSpecies = null;
    _pendingTrash = null;
    _decided = false;
    _outcome = null;
    _retrieveT = 0;
    _enter(Phase.freeWater);
    _floatN = _launchN;
    _floatDip.snapTo(0);
    _bend.snapTo(0.06);
    _rodPull.snapTo(0);
  }

  /// Смотать снасть без улова: удочка «достаётся» по нажатию катушки.
  void _retrieveRig() {
    _splash(_floatN, 8, 0.08);
    _ring(_floatN, 30, 0.5);
    _resetToFreeWater();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1A1F25),
        ),
      );
  }

  // --- UI -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ошибка')),
        body: Center(child: Text(_error!)),
      );
    }
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Живой профиль (наживка/баланс обновляются после улова и покупок).
    final player = ref.watch(playerControllerProvider).value;
    final tournamentActive =
        player != null && player.inTournament && !_tournamentDone;
    if (tournamentActive) {
      final ends = player.tournamentEndsAt;
      final remain = ends == null
          ? 0
          : ends.difference(DateTime.now()).inSeconds;
      if (remain <= 0) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _finishTournament(player),
        );
      }
    }

    return PopScope(
      // Любой выход со сцены — через подтверждение (рыбалка завершится).
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, c) {
            final size = Size(c.maxWidth, c.maxHeight);
            return Stack(
              fit: StackFit.expand,
              children: [
                contentImage(
                  assetStem(_loc.primaryBackdrop),
                  _loc.primaryBackdrop,
                  alignment: Alignment.centerLeft,
                  fallback: (_) =>
                      const ColoredBox(color: Color(0xFF0E141A)),
                ),
                const _SceneScrim(),
                // Тинт времени суток поверх фото (день — прозрачно, ночь — синё).
                IgnorePointer(child: ColoredBox(color: _timeTint())),
                CustomPaint(
                  painter: FishingPainter(
                    time: _time,
                    bend: _bend.value,
                    pull: _rodPull.value,
                    reelAngle: _reelAngle,
                    floatPosN: _floatN,
                    floatDip: _floatDip.value,
                    lineTaut: _lineTaut,
                    ripples: _ripples,
                    splashes: _splashes,
                    swirls: _swirls,
                    showRig: _phase != Phase.freeWater,
                    showReel: _phase == Phase.fight,
                    rain: _weather == Weather.rain,
                    spinning: _mode == FishingMode.spinning,
                    lureVisibility: _mode == FishingMode.spinning
                        ? (0.12 + 0.6 * _retrieveT).clamp(0.12, 0.78).toDouble()
                        : 1.0,
                    floatScale: _depthScale(_floatN.dy),
                  ),
                ),
                // Слой заброса/подсечки — НАД фоном и рендером, но ПОД
                // интерфейсом: тап по воде ловится здесь, а нажатия на кнопки
                // и панели сверху доходят до них (они выше этого слоя).
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) {
                      if (_phase == Phase.bite) {
                        _strike();
                      } else if (_phase == Phase.freeWater) {
                        // Заброс только со «свободной воды»: когда уже заброшено,
                        // тап по воде ничего не перезабрасывает.
                        _castTo(Offset(
                          d.localPosition.dx / size.width,
                          d.localPosition.dy / size.height,
                        ));
                      }
                    },
                    child: const SizedBox.expand(),
                  ),
                ),
                const Align(
                  alignment: Alignment.topCenter,
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: StatusPill(showSkillsButton: false),
                    ),
                  ),
                ),
                if (_phase == Phase.freeWater) ..._cornerButtons(),
                if (tournamentActive) _tournamentHud(player),
                if (_alertTitle != null && _time < _alertUntil) _alertBanner(),
                if (_wxShowAt >= 0 &&
                    _time >= _wxShowAt &&
                    _time < _wxShowAt + 7)
                  _weatherNotice(),
                if (_echo != null && !_echoOn) _echoButton(),
                if (_echo != null && _echoOn) _echoDeviceOverlay(),
                _bottomBar(player),
                if (_phase == Phase.freeWater || _phase == Phase.waiting)
                  _chumPill(player),
                if (_phase == Phase.freeWater && _mode == FishingMode.float)
                  _depthControl(),
                if (_phase == Phase.freeWater) _castHint(),
                if (_phase == Phase.bite) _strikePrompt(),
                if (_phase == Phase.landed) _catchCard(),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Круглые кнопки по углам (как в рефе): слева профиль/достижения/турниры,
  /// справа магазин/карта/снаряжение. На время турнира кнопка «Турниры»
  /// У воды только то, что реально на рыбалке: рюкзак со снастями (сменить
  /// оснастку/наживку) и выход к карте. Магазин/бестиарий/достижения/турниры/
  /// профиль — это «база», они в нижнем меню карты, а не у воды.
  List<Widget> _cornerButtons() {
    return [
      // Слева: уйти к карте + инфо о месте (что знаешь о споте).
      Positioned(
        left: 12,
        top: 10,
        child: SafeArea(
          child: Column(
            children: [
              CircleIconButton(
                icon: Icons.map,
                tooltip: 'К карте',
                onTap: _confirmExit,
              ),
              const SizedBox(height: 12),
              CircleIconButton(
                icon: Icons.info_outline,
                tooltip: 'О месте',
                onTap: _locationInfo,
              ),
            ],
          ),
        ),
      ),
      // Рюкзак со снастями: переоснаститься/сменить наживку на месте.
      Positioned(
        right: 12,
        top: 10,
        child: SafeArea(
          child: CircleIconButton(
            icon: Icons.backpack,
            tooltip: 'Снаряжение',
            onTap: () => _openWin(
              'Снаряжение',
              const GearTab(shopAllowed: false),
              refreshRig: true,
            ),
          ),
        ),
      ),
    ];
  }

  /// Открывает игровое окно поверх сцены; при необходимости пересобирает
  /// снасть после закрытия (смена экипировки/покупки).
  Future<void> _openWin(
    String title,
    Widget body, {
    bool refreshRig = false,
  }) async {
    await GameWindow.show(context, title, body);
    if (!mounted || !refreshRig) return;
    final p = ref.read(playerControllerProvider).value;
    if (p != null) {
      setState(() {
        _resolveRig(p);
        // Пополнил запас — пороговое предупреждение снова активно.
        if (_activeBaitQty(p) > 5) _warnedLowBait = false;
      });
    }
  }

  /// Быстрый выбор наживки/приманки прямо на воде — из купленного в рюкзаке.
  Future<void> _pickBaitOnWater() async {
    final spin = _mode == FishingMode.spinning;
    final cat = spin ? GearCategory.lure : GearCategory.bait;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Consumer(builder: (context, ref, _) {
        final p = ref.watch(playerControllerProvider).value;
        if (p == null) return const SizedBox.shrink();
        final owned = _catalog
            .where((g) =>
                g.category == cat &&
                p.inventory.any((e) => e.gearId == g.id && e.quantity > 0))
            .toList();
        final activeId = _lure?.id;
        return Container(
          decoration: const BoxDecoration(
            color: kPanelBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(top: BorderSide(color: kGold, width: 1.5)),
          ),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Container(width: 4, height: 18, color: kGold),
                  const SizedBox(width: 8),
                  Text(spin ? 'Приманка' : 'Наживка',
                      style: displayStyle(size: 18)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(sheetCtx).pop();
                      _openWin('Снаряжение', const GearTab(shopAllowed: false),
                          refreshRig: true);
                    },
                    icon: const Icon(Icons.backpack, size: 16, color: kGold),
                    label: const Text('Тэклбокс',
                        style: TextStyle(color: kGold, fontSize: 12)),
                  ),
                ]),
              ),
              if (owned.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'В рюкзаке нет ${spin ? 'приманок' : 'наживки'}. '
                    'Открой тэклбокс или загляни в магазин на базе.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12.5),
                  ),
                )
              else
                Flexible(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                    shrinkWrap: true,
                    children: [
                      for (final g in owned)
                        _baitTile(sheetCtx, g, p, g.id == activeId),
                    ],
                  ),
                ),
            ]),
          ),
        );
      }),
    );
  }

  Widget _baitTile(BuildContext sheetCtx, GearItem g, Player p, bool active) {
    final qty = p.inventory
        .where((e) => e.gearId == g.id)
        .fold<int>(0, (s, e) => s + e.quantity);
    final sub = g is LureItem ? g.lureType.label : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () async {
          await ref.read(playerControllerProvider.notifier).equip(g);
          final np = await ref.read(playerControllerProvider.future);
          if (!mounted) return;
          setState(() => _resolveRig(np));
          if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
          _toastBait('Наживка: ${g.name}');
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: active
                ? kGold.withValues(alpha: 0.13)
                : Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: active ? kGold : Colors.white12,
                width: active ? 1.6 : 1),
          ),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE9E4D8), Color(0xFFC9C2B2)],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kGold.withValues(alpha: 0.4)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: GearIcon(g.category, size: 40),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(g.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(sub,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 10.5)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('×$qty',
                style: const TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.w800)),
            const SizedBox(width: 10),
            Icon(active ? Icons.check_circle : Icons.arrow_forward_ios,
                color: active ? kGold : Colors.white38,
                size: active ? 20 : 14),
          ]),
        ),
      ),
    );
  }

  void _toastBait(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A1F25),
      ));
  }

  // --- Турнир: HUD и завершение --------------------------------------------

  /// Верхний HUD турнира: обратный отсчёт, текущий зачёт и кнопка «Завершить».
  Widget _tournamentHud(Player player) {
    final ends = player.tournamentEndsAt;
    final remain =
        (ends == null ? 0 : ends.difference(DateTime.now()).inSeconds).clamp(
          0,
          99999,
        );
    final mm = (remain ~/ 60).toString().padLeft(2, '0');
    final ss = (remain % 60).toString().padLeft(2, '0');
    final low = remain <= 15;
    final kg = (player.tournamentScore / 1000).toStringAsFixed(2);
    const danger = Color(0xFFE5483B);
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 52),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kGold.withValues(alpha: 0.7)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer, size: 16, color: low ? danger : kGold),
                const SizedBox(width: 6),
                Text(
                  '$mm:$ss',
                  style: TextStyle(
                    color: low ? danger : Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Container(
                  width: 1,
                  height: 18,
                  color: Colors.white24,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                const Icon(Icons.scale, size: 16, color: kGold),
                const SizedBox(width: 6),
                Text(
                  '$kg кг',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _finishTournament(player),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: kGold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kGold),
                    ),
                    child: const Text(
                      'Завершить',
                      style: TextStyle(
                        color: kGold,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Подтверждение выхода: уход к карте = конец рыбалки (или турнира).
  void _confirmExit() {
    final player = ref.read(playerControllerProvider).value;
    final inT = player != null && player.inTournament && !_tournamentDone;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: HeaderPanel(
            header: inT ? 'Завершить турнир?' : 'Покинуть рыбалку?',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  inT
                      ? 'Выход к карте досрочно завершит турнир — зачёт подведут '
                            'по текущему улову.'
                      : 'Вернуться к карте? Ловля на этом месте завершится.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: GoldButton(
                      label: inT ? 'Завершить' : 'К карте',
                      icon: Icons.map,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        if (inT) {
                          _finishTournament(player);
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Остаться',
                        style: TextStyle(color: Colors.white60)),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Завершает турнир: считает место среди ботов, начисляет приз, показывает
  /// итоговую таблицу и выходит со сцены.
  Future<void> _finishTournament(Player player) async {
    if (_tournamentDone) return;
    _tournamentDone = true;
    final notifier = ref.read(playerControllerProvider.notifier);
    final t = tournamentById(player.activeTournamentId);
    if (t == null) {
      await notifier.abandonTournament();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final seed =
        t.id.hashCode ^
        player.tournamentScore ^
        (player.tournamentEndsAt?.millisecondsSinceEpoch ?? 0);
    final result = computeTournamentResult(t, player.tournamentScore, seed);
    await notifier.awardTournament(
      silver: result.prizeSilver,
      gold: result.prizeGold,
      won: result.won,
    );
    if (!mounted) return;
    await _showTournamentResult(result);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _showTournamentResult(TournamentResult r) {
    String kg(int g) => '${(g / 1000).toStringAsFixed(2)} кг';
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 580),
          child: HeaderPanel(
            header: r.won
                ? 'Победа!'
                : r.podium
                ? 'Призовое место!'
                : 'Турнир завершён',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (r.place <= 3)
                      MedalBadge(r.place, size: 40)
                    else
                      Text('#${r.place}', style: displayStyle(size: 32)),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${r.place} место из ${r.total}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Ваш зачёт: ${kg(r.playerScore)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Приз: ',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const Icon(Icons.circle, size: 12, color: kSilver),
                      const SizedBox(width: 4),
                      Text(
                        '${r.prizeSilver}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (r.prizeGold > 0) ...[
                        const SizedBox(width: 14),
                        const Icon(Icons.circle, size: 12, color: kGold),
                        const SizedBox(width: 4),
                        Text(
                          '${r.prizeGold}',
                          style: const TextStyle(
                            color: kGold,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: r.rows.length,
                    itemBuilder: (context, i) {
                      final row = r.rows[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 6,
                        ),
                        decoration: BoxDecoration(
                          color: row.isMe
                              ? kGold.withValues(alpha: 0.14)
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          border: row.isMe
                              ? Border.all(color: kGold.withValues(alpha: 0.6))
                              : null,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 36,
                              child: row.place <= 3
                                  ? MedalBadge(row.place, size: 20)
                                  : Text(
                                      '${row.place}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                row.player,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: row.isMe ? kGold : Colors.white,
                                  fontWeight: row.isMe
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              kg(row.rating),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                GoldButton(
                  label: 'Готово',
                  icon: Icons.check,
                  onTap: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Окно «нет сил»: предлагает перекус из рюкзака для восстановления энергии.
  void _showLowEnergy(Player player) {
    final foods = player.inventory
        .where((e) => e.category == GearCategory.energy)
        .toList();
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: HeaderPanel(
            header: 'Силы на исходе',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Энергия восстанавливается со временем (1 ед./мин). '
                  'Перекуси, чтобы продолжить ловлю прямо сейчас.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                if (foods.isEmpty)
                  const Text(
                    'Перекусов нет — отдохни или загляни в магазин за кофе.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFE5483B), fontSize: 12.5),
                  )
                else
                  for (final e in foods)
                    if (_gearById[e.gearId] case final item?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.local_cafe,
                              size: 18,
                              color: kGold,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${item.name} ×${e.quantity}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            GoldButton(
                              label:
                                  '+${item.price.amount.clamp(20, Player.maxEnergy).toInt()}',
                              icon: Icons.bolt,
                              onTap: () async {
                                final gained = await ref
                                    .read(playerControllerProvider.notifier)
                                    .useEnergyItem(item);
                                if (ctx.mounted) Navigator.of(ctx).pop();
                                if (mounted && gained > 0) {
                                  ScaffoldMessenger.of(context)
                                    ..clearSnackBars()
                                    ..showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Восстановлено +$gained энергии',
                                        ),
                                        duration: const Duration(
                                          milliseconds: 1300,
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: const Color(
                                          0xFF1A1F25,
                                        ),
                                      ),
                                    );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text(
                      'Закрыть',
                      style: TextStyle(color: Colors.white60),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Прикормить точку: тратит 1 прикормку из рюкзака и временно усиливает клёв.
  Future<void> _chum() async {
    if (_time < _chumUntil) return;
    final p = ref.read(playerControllerProvider).value;
    // Владеемые прикормки (с их семействами и длительностью).
    final owned = <LureItem>[];
    for (final e in p?.inventory ?? const <InventoryEntry>[]) {
      if (e.category == GearCategory.groundbait) {
        final g = _gearById[e.gearId];
        if (g is LureItem && !owned.any((o) => o.id == g.id)) owned.add(g);
      }
    }
    if (owned.isEmpty) {
      _sceneToast('Нет прикормки — купи в магазине на берегу');
      return;
    }
    // Если прикормка одна — используем сразу; иначе даём выбрать семейство.
    final chosen =
        owned.length == 1 ? owned.first : await _pickGroundbait(owned);
    if (chosen == null || !mounted) return;
    final left =
        await ref.read(playerControllerProvider.notifier).consumeBait(chosen.id);
    if (!mounted || left < 0) return;
    // Универсальная (пустой список) бустит все семейства, что есть в водоёме.
    final groups = chosen.targetGroups.isEmpty
        ? _pool.map((e) => e.$2.group).where((g) => g.isNotEmpty).toSet()
        : chosen.targetGroups.toSet();
    setState(() {
      _chumUntil = _time + chosen.chumSeconds.toDouble();
      _chumGroups = groups;
    });
    HapticFeedback.lightImpact();
    _splash(_castTarget, 12, 0.12);
    _ring(_castTarget, 44, 0.8);
    final what = chosen.targetGroups.isEmpty
        ? 'все семейства'
        : chosen.targetGroups.join(', ');
    _sceneToast('Прикормка ($what) — клёв активнее (${chosen.chumSeconds} с)');
  }

  /// Выбор прикормки из рюкзака, когда их несколько разных.
  Future<LureItem?> _pickGroundbait(List<LureItem> owned) {
    return showModalBottomSheet<LureItem>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: kPanelBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(top: BorderSide(color: kGold, width: 1.5)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text('Прикормить точку',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900)),
              ),
              for (final g in owned)
                ListTile(
                  leading:
                      const Icon(Icons.grass, color: Color(0xFF5FB85F)),
                  title: Text(g.name,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13.5)),
                  subtitle: Text(
                      '${_groupsLabel(g.targetGroups)} · ${g.chumSeconds} с',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11.5)),
                  onTap: () => Navigator.of(ctx).pop(g),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  static String _groupsLabel(List<String> groups) =>
      groups.isEmpty ? 'универсальная — все семейства' : 'для: ${groups.join(', ')}';

  void _sceneToast(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(milliseconds: 1400),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1A1F25),
        ),
      );
  }

  /// Кнопка/индикатор прикормки (слева снизу, над панелью снасти).
  Widget _chumPill(Player? player) {
    final active = _time < _chumUntil;
    final owned =
        player?.inventory.any((e) => e.category == GearCategory.groundbait) ??
        false;
    if (!active && !owned) return const SizedBox.shrink();
    final remain = active ? (_chumUntil - _time).ceil() : 0;
    final color = active ? const Color(0xFF5FB85F) : kGold;
    return Positioned(
      left: 16,
      bottom: 110,
      child: GestureDetector(
        onTap: active ? null : _chum,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.85)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.grass, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                active ? 'Прикормка · $remain с' : 'Прикормить',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Панель «О месте»: погода/время, рельеф дна и какие виды тут водятся
  /// (открытые — с именем и весом; прочие — силуэт «?»). Для осознанной ловли.
  void _locationInfo() {
    final player = ref.read(playerControllerProvider).value;
    final known = player?.discoveredSpeciesIds ?? const <String>{};
    final tIcon = switch (_timeOfDay) {
      TimeOfDay.morning || TimeOfDay.evening => Icons.wb_twilight,
      TimeOfDay.day => Icons.wb_sunny,
      TimeOfDay.night => Icons.bedtime,
    };
    final tLabel = switch (_timeOfDay) {
      TimeOfDay.morning => 'Утро',
      TimeOfDay.day => 'День',
      TimeOfDay.evening => 'Вечер',
      TimeOfDay.night => 'Ночь',
    };
    final wIcon = switch (_weather) {
      Weather.clear => Icons.wb_sunny,
      Weather.cloudy => Icons.cloud,
      Weather.rain => Icons.water_drop,
    };
    final wLabel = switch (_weather) {
      Weather.clear => 'Ясно',
      Weather.cloudy => 'Пасмурно',
      Weather.rain => 'Дождь',
    };
    final shape = switch (_loc.depthProfile.shape) {
      'dropOff' => 'свал',
      'pit' => 'яма',
      'ridge' => 'гряда',
      _ => 'ровное дно',
    };
    // Плотность («клёв») и типичный размер рыбы — то же, что и в «выходах».
    var activity = 0.0;
    var sumMaxG = 0;
    for (final (spawn, sp) in _pool) {
      activity += (spawn.floatChance + spawn.spinningChance) / 2;
      sumMaxG += sp.weightMax.grams;
    }
    final avgMaxG = _pool.isEmpty ? 0 : sumMaxG ~/ _pool.length;
    final actLabel = activity > 2.0
        ? 'высокий'
        : activity > 1.0
            ? 'средний'
            : 'слабый';
    final sizeLabel = avgMaxG > 7000
        ? 'крупная'
        : avgMaxG > 2500
            ? 'средняя'
            : 'некрупная';
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 600),
          child: HeaderPanel(
            header: 'О месте',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_loc.name, style: displayStyle(size: 18)),
                if (_loc.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _loc.description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _infoChip(wIcon, wLabel),
                    _infoChip(tIcon, tLabel),
                    _infoChip(
                      Icons.waves,
                      'до ${_loc.depthProfile.maxDepthMeters} м · $shape',
                    ),
                    _infoChip(Icons.show_chart, 'Клёв: $actLabel'),
                    _infoChip(Icons.straighten, 'Рыба: $sizeLabel'),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Здесь водится',
                  style: TextStyle(
                    color: kGold,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _pool.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final spawn = _pool[i].$1;
                      final sp = _pool[i].$2;
                      final isKnown = known.contains(sp.id);
                      return Row(
                        children: [
                          FishIcon(sp.id, discovered: isKnown, size: 48),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isKnown ? sp.name : 'Неизвестный вид',
                                  style: TextStyle(
                                    color: isKnown
                                        ? Colors.white
                                        : Colors.white54,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  isKnown
                                      ? '${sp.family} · ${spawn.weightMin.formatted}–${spawn.weightMax.formatted}'
                                      : 'Поймай, чтобы открыть',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isKnown) _rarityTag(sp.rarity),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text(
                      'Закрыть',
                      style: TextStyle(color: Colors.white60),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: kGold),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    ),
  );

  Color _rarityColor(Rarity r) => switch (r) {
        Rarity.common => const Color(0xFF9AA4AD),
        Rarity.uncommon => const Color(0xFF5FB85F),
        Rarity.rare => const Color(0xFF4E9CF5),
        Rarity.trophy => kGold,
        Rarity.legendary => const Color(0xFFB266FF),
      };

  Widget _rarityTag(Rarity r) {
    final label = switch (r) {
      Rarity.common => 'обычная',
      Rarity.uncommon => 'нечастая',
      Rarity.rare => 'редкая',
      Rarity.trophy => 'трофей',
      Rarity.legendary => 'легенда',
    };
    final color = _rarityColor(r);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Баннер ресурсного предупреждения: плавный выезд сверху, цветная рамка,
  /// при необходимости — кнопка «Заменить» (рюкзак, без покупок).
  /// Красивое уведомление о приближающемся дожде/снеге по прогнозу локации.
  Widget _weatherNotice() {
    final e = _time - _wxShowAt; // 0..7
    final a = math.min((e * 3).clamp(0.0, 1.0), ((7 - e) * 2.2).clamp(0.0, 1.0));
    final snow = _wxRainSnow;
    final accent = snow ? const Color(0xFFBFD8EC) : const Color(0xFF5FA8E0);
    final title = snow ? 'Надвигается снег' : 'Надвигается дождь';
    // 1 «час» прогноза = 90 секунд сессии — говорим игроку реальное время.
    final mins = _wxRainHours * 1.5;
    final whenTxt = mins == mins.roundToDouble()
        ? 'через ~${mins.round()} мин'
        : 'через ~${mins.toStringAsFixed(1)} мин';
    final sub = snow
        ? 'Начнётся $whenTxt · погода переменится — лови активнее'
        : 'Начнётся $whenTxt · перед дождём рыба жаднее — лови!';
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 54),
          child: Opacity(
            opacity: a,
            child: Transform.translate(
              offset: Offset(0, (1 - a) * -18),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 470),
                padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      accent.withValues(alpha: 0.22),
                      const Color(0xFF10161D).withValues(alpha: 0.96),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: accent.withValues(alpha: 0.8), width: 1.4),
                  boxShadow: [
                    BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 18),
                    const BoxShadow(color: Colors.black54, blurRadius: 10),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 46,
                      height: 40,
                      child: CustomPaint(
                        painter: _RainCloudPainter(_time, accent, snow),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(title,
                              style: TextStyle(
                                  color: accent,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text(sub,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 11.5,
                                  height: 1.25)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _alertBanner() {
    final lifeLeft = _alertUntil - _time;
    final aIn = ((_alertUntil - lifeLeft) * 4).clamp(0.0, 1.0); // появление
    final aOut = (lifeLeft * 2.5).clamp(0.0, 1.0); // затухание
    final a = math.min(aIn, aOut);
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 56),
          child: Opacity(
            opacity: a,
            child: Transform.translate(
              offset: Offset(0, (1 - a) * -14),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF14181D).withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _alertColor, width: 1.6),
                  boxShadow: [
                    BoxShadow(
                      color: _alertColor.withValues(alpha: 0.35),
                      blurRadius: 16,
                    ),
                    const BoxShadow(color: Colors.black54, blurRadius: 10),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notification_important,
                      color: _alertColor,
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _alertTitle ?? '',
                            style: TextStyle(
                              color: _alertColor,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (_alertSub != null)
                            Text(
                              _alertSub!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 11.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_alertReplaceAction) ...[
                      const SizedBox(width: 12),
                      GoldButton(
                        label: 'Заменить',
                        icon: Icons.backpack,
                        onTap: () {
                          _alertUntil = 0;
                          _openWin(
                            'Снаряжение',
                            const GearTab(shopAllowed: false),
                            refreshRig: true,
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Подсказка на свободной воде.
  /// Настройка спуска (глубины) поплавка — «разрез воды»: зоны глубины с
  /// подсветкой активной, контур дна по форме водоёма, призрачные рыбы на
  /// разных горизонтах (намёк), поплавок и крючок-слайдер с пилюлей глубины.
  Widget _depthControl() {
    return Align(
      alignment: const Alignment(0.92, -0.04),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (d) => setState(() {
          _depthFrac = (_depthFrac + d.delta.dy / 234).clamp(0.0, 1.0);
        }),
        child: SizedBox(
          width: 140,
          height: 286,
          child: CustomPaint(
            painter: _DepthColumnPainter(
              depthFrac: _depthFrac,
              maxDepthMeters: _loc.depthProfile.maxDepthMeters,
              shape: _loc.depthProfile.shape,
              zone: _setDepthZone(),
              time: _time,
            ),
          ),
        ),
      ),
    );
  }

  Widget _castHint() {
    return Align(
      alignment: const Alignment(0, 0.42),
      child: IgnorePointer(
        child: Text(
          'Тапни по воде — заброс',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 14,
            fontWeight: FontWeight.w700,
            shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
          ),
        ),
      ),
    );
  }

  /// Панель эхолота — содержимое зависит от возможностей модели в лоадауте.
  /// Кнопка вызова эхолота (слева) — когда устройство свёрнуто.
  Widget _echoButton() {
    return SafeArea(
      child: Align(
        alignment: const Alignment(-1, 0.12),
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: GestureDetector(
            onTap: () => setState(() => _echoOn = true),
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1E2A26), Color(0xFF0E1814)],
                ),
                border: Border.all(color: const Color(0xFF2EE6A6), width: 1.6),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF2EE6A6).withValues(alpha: 0.3),
                      blurRadius: 12),
                ],
              ),
              child: const Icon(Icons.radar, color: Color(0xFF2EE6A6), size: 26),
            ),
          ),
        ),
      ),
    );
  }

  /// Развёрнутое устройство-эхолот (живой экран, настройки, выключение).
  Widget _echoDeviceOverlay() {
    return SafeArea(
      child: Align(
        alignment: const Alignment(-0.94, 0.05),
        child: EchoSounderDevice(
          echo: _echo!,
          profile: _loc.depthProfile,
          depthMeters: _lastDepth?.meters,
          fishInZone: _pool.length,
          biteActive: _phase == Phase.bite,
          castActive: _phase == Phase.waiting ||
              _phase == Phase.bite ||
              _phase == Phase.fight,
          rigDepthFrac: _echoRigDepthFrac(),
          rigXFrac: _castTarget.dx,
          targets: _echoTargets(),
          onClose: () => setState(() => _echoOn = false),
        ),
      ),
    );
  }

  /// Глубина крючка для эхолота 0..1: задаётся слайдером (`_depthFrac`), а при
  /// подтягивании/вываживании уменьшается — крючок «ползёт» вверх к поверхности.
  double _echoRigDepthFrac() {
    final double pull = switch (_phase) {
      Phase.waiting => _reeling ? _retrieveT : 0.0,
      Phase.fight => _fightProgress.clamp(0.0, 1.0).toDouble(),
      _ => 0.0,
    };
    return (_depthFrac * (1 - pull)).clamp(0.0, 1.0).toDouble();
  }

  /// Цели для эхолота — реальные рыбы пула локации: то, что видно на сонаре,
  /// то и клюёт. Размер — по макс. весу вида, глубина — по любимой зоне,
  /// частота появления — по обилию (шансу клёва).
  List<EchoTarget> _echoTargets() {
    if (_pool.isEmpty) return const [];
    var maxG = 1;
    for (final (_, sp) in _pool) {
      if (sp.weightMax.grams > maxG) maxG = sp.weightMax.grams;
    }
    return [
      for (final (spawn, sp) in _pool)
        EchoTarget(
          sizeFrac: (sp.weightMax.grams / maxG).clamp(0.12, 1.0).toDouble(),
          depthFrac: _zoneDepthFrac(sp),
          abundance: ((spawn.floatChance + spawn.spinningChance) / 2)
              .clamp(0.05, 1.0)
              .toDouble(),
          minKg: sp.weightMin.grams / 1000,
          maxKg: sp.weightMax.grams / 1000,
        ),
    ];
  }

  double _zoneDepthFrac(FishSpecies sp) {
    final w = sp.biteProfile.depthWeights;
    if (w.isEmpty) return 0.5;
    final best = w.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return switch (best) {
      DepthZone.shallow => 0.28,
      DepthZone.mid => 0.5,
      DepthZone.dropOff => 0.72,
      DepthZone.pit => 0.9,
    };
  }

  /// Нижняя панель по рефу: овал наживки · параметры снасти · белая полоса
  /// (натяжение/прогресс) · большая катушка справа.
  Widget _bottomBar(Player? player) {
    var baitQty = 0;
    if (player != null && _lure != null) {
      for (final e in player.inventory) {
        if (e.gearId == _lure!.id) {
          baitQty = e.quantity;
          break;
        }
      }
    }
    final tIcon = switch (_timeOfDay) {
      TimeOfDay.morning || TimeOfDay.evening => Icons.wb_twilight,
      TimeOfDay.day => Icons.wb_sunny,
      TimeOfDay.night => Icons.bedtime,
    };
    final wIcon = switch (_weather) {
      Weather.clear => Icons.wb_sunny,
      Weather.cloudy => Icons.cloud,
      Weather.rain => Icons.water_drop,
    };

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Наживка/приманка — тап открывает быстрый выбор из рюкзака.
              GestureDetector(
                onTap: _pickBaitOnWater,
                child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(22),
                  border: baitQty <= 5
                      ? Border.all(
                          color:
                              (baitQty == 0 ? const Color(0xFFE5483B) : kGold)
                                  .withValues(
                                    alpha: 0.65 + 0.35 * math.sin(_time * 6),
                                  ),
                          width: 2.4 + math.sin(_time * 6) * 0.8,
                        )
                      : null,
                  boxShadow: [
                    const BoxShadow(color: Colors.black45, blurRadius: 8),
                    if (baitQty == 0)
                      BoxShadow(
                        color: const Color(
                          0xFFE5483B,
                        ).withValues(alpha: 0.3 + 0.2 * math.sin(_time * 6)),
                        blurRadius: 14,
                      ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bug_report,
                      size: 20,
                      color: Color(0xFF8A6A3B),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '$baitQty',
                      style: const TextStyle(
                        color: Color(0xFF24282E),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.unfold_more,
                        size: 15, color: Color(0xFF8A6A3B)),
                  ],
                ),
                ),
              ),
              const SizedBox(width: 10),
              // Параметры снасти.
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF24282E).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _rigStat(
                      Icons.phishing,
                      '${((_rod?.maxWeight.grams ?? 0) / 1000).toStringAsFixed(0)} кг',
                    ),
                    _rigDot(),
                    _rigStat(
                      Icons.settings,
                      '${((_reel?.maxWeight.grams ?? 0) / 1000).toStringAsFixed(0)} кг',
                    ),
                    _rigDot(),
                    _rigStat(Icons.linear_scale, _lineLabel()),
                    _rigDot(),
                    _rigStat(Icons.anchor, _hookLabel()),
                    _rigDot(),
                    Icon(tIcon, size: 15, color: Colors.white60),
                    const SizedBox(width: 6),
                    Icon(wIcon, size: 15, color: Colors.white60),
                  ],
                ),
              ),
              // Шкала натяжения и катушка нужны только когда снасть в воде —
              // до заброса их не показываем.
              if (_phase != Phase.freeWater) ...[
                const SizedBox(width: 10),
                Expanded(child: _whiteBar()),
                const SizedBox(width: 12),
                GestureDetector(
                  onTapDown: (_) {
                    SoundService.reelClick();
                    if (_phase == Phase.bite) {
                      _strike();
                    } else if (_phase == Phase.fight) {
                      _reeling = true;
                    } else if (_phase == Phase.waiting) {
                      if (_mode == FishingMode.spinning) {
                        _reeling = true; // удержание — проводка к берегу
                      } else {
                        _retrieveRig(); // удочка — смотать снасть
                      }
                    }
                  },
                  onTapUp: (_) => _reeling = false,
                  onTapCancel: () => _reeling = false,
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        center: Alignment(-0.3, -0.4),
                        colors: [Colors.white, Color(0xFFD8DCE0)],
                      ),
                      border: Border.all(
                        color: _phase == Phase.fight
                            ? kGold
                            : const Color(0xFF3A4047),
                        width: 3,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CustomPaint(painter: _ReelKnobPainter(_reelAngle)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Предел лески/шнура и метраж из лоадаута.
  String _lineLabel() {
    final p = ref.read(playerControllerProvider).value;
    if (p != null) {
      final id = _mode == FishingMode.spinning
          ? p.loadout.braidId
          : p.loadout.lineId;
      final item = id == null ? null : _gearById[id];
      if (item is LineItem) {
        return '${(item.maxWeight.grams / 1000).toStringAsFixed(0)} кг/${item.lengthMeters} м';
      }
    }
    return '—';
  }

  String _hookLabel() {
    final p = ref.read(playerControllerProvider).value;
    final id = p?.loadout.hookId;
    final item = id == null ? null : _gearById[id];
    if (item is HookItem) {
      return '${(item.escapeChance * 100).round()} %';
    }
    return _mode == FishingMode.spinning ? '—' : '0 %';
  }

  Widget _rigStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: kGold),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _rigDot() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Container(
      width: 3,
      height: 3,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
    ),
  );

  /// Белая полоса: на забросе — заполнение, на вываживании — зелёная зона,
  /// маркер натяжения и тонкая линия прогресса.
  Widget _whiteBar() {
    return SizedBox(
      height: 26,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(13),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 8),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                if (_phase == Phase.casting)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: w * _castT,
                    child: const ColoredBox(color: Color(0xFFF2C46B)),
                  ),
                if (_phase == Phase.fight) ...[
                  Positioned(
                    left: w * _greenLo,
                    width: w * (_greenHi - _greenLo),
                    top: 0,
                    bottom: 0,
                    child: ColoredBox(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    bottom: 0,
                    width: w * _fightProgress,
                    height: 5,
                    child: const ColoredBox(color: kGold),
                  ),
                  Positioned(
                    left: (w * _tension - 3).clamp(0.0, w - 6),
                    top: 1,
                    bottom: 1,
                    child: Container(
                      width: 6,
                      decoration: BoxDecoration(
                        color: _tension > 0.95 || _tension < 0.05
                            ? const Color(0xFFE5483B)
                            : const Color(0xFF24282E),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _strikePrompt() {
    final pulse = 0.5 + 0.5 * math.sin(_time * 10);
    return Align(
      alignment: const Alignment(0, -0.15),
      child: Opacity(
        opacity: 0.65 + 0.35 * pulse,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFE5483B).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(40),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'ПОДСЕЧКА',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _catchCard() {
    final sp = _pendingSpecies;
    final w = _pending?.weight;
    // Рамка и свечение карточки улова — по эффективной редкости пойманного
    // экземпляра: чем крупнее/реже рыба, тем ярче ореол (это момент-награда).
    final isCatch =
        _pendingTrash == null && !_decided && sp != null && w != null;
    final rarity = isCatch ? catchRarity(sp, w) : null;
    final rColor =
        rarity != null ? _rarityColor(rarity) : const Color(0xFFE6A23C);
    final (glowA, glowB) = switch (rarity) {
      Rarity.uncommon => (0.30, 24.0),
      Rarity.rare => (0.42, 30.0),
      Rarity.trophy => (0.60, 36.0),
      Rarity.legendary => (0.74, 44.0),
      _ => (0.0, 0.0),
    };
    return Center(
      child: TweenAnimationBuilder<double>(
        key: ValueKey(_decided),
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutBack,
        builder: (context, t, child) => Transform.scale(
          scale: 0.8 + 0.2 * t,
          child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF12161B).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: rColor, width: 1.8),
            boxShadow: [
              const BoxShadow(color: Colors.black87, blurRadius: 24),
              if (glowA > 0)
                BoxShadow(
                    color: rColor.withValues(alpha: glowA),
                    blurRadius: glowB,
                    spreadRadius: 2),
            ],
          ),
          child: _pendingTrash != null
              ? _trashBody(_pendingTrash!)
              : (_decided ? _resultBody() : _catchBody(sp, w)),
        ),
      ),
    );
  }

  Widget _catchBody(FishSpecies? sp, Weight? w) {
    final rarity = (sp != null && w != null) ? catchRarity(sp, w) : null;
    final rColor = rarity == null ? const Color(0xFFE6A23C) : _rarityColor(rarity);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          rarity == Rarity.legendary
              ? Icons.auto_awesome
              : rarity == Rarity.trophy
                  ? Icons.workspace_premium
                  : Icons.set_meal,
          color: rColor,
          size: 40,
        ),
        const SizedBox(height: 10),
        Text(
          sp?.name ?? 'Рыба',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          w?.formatted ?? '',
          style: TextStyle(
            color: rColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (rarity != null) ...[
          const SizedBox(height: 8),
          _rarityTag(rarity),
        ],
        if (sp != null) ...[
          const SizedBox(height: 6),
          Text(
            sp.family,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
        ],
        const SizedBox(height: 18),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _cardButton('Отпустить', Icons.water, false, () => _decide(false)),
            const SizedBox(width: 12),
            _cardButton('Забрать', Icons.check, true, () => _decide(true)),
          ],
        ),
      ],
    );
  }

  Widget _resultBody() {
    final o = _outcome;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          o?.leveledUp == true ? Icons.military_tech : Icons.check_circle,
          color: const Color(0xFFE6A23C),
          size: 40,
        ),
        const SizedBox(height: 10),
        if (o != null) ...[
          if (o.silver > 0)
            Text(
              '+${o.silver} серебра',
              style: const TextStyle(
                color: Color(0xFFC9CDD2),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          if (o.xp > 0)
            Text(
              '+${o.xp} опыта',
              style: const TextStyle(
                color: Color(0xFF7FB2FF),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          if (o.firstOfSpecies)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Новый вид в бестиарии!',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
              ),
            ),
          if (o.leveledUp)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Уровень ${o.newLevel}!',
                style: const TextStyle(
                  color: Color(0xFFE6A23C),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
        const SizedBox(height: 18),
        _cardButton('Продолжить', Icons.arrow_forward, true, _resetToFreeWater),
      ],
    );
  }

  Widget _trashBody(TrashSpawn t) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.delete_outline, color: Color(0xFFC9CDD2), size: 40),
        const SizedBox(height: 10),
        Text(
          t.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Зацеп — не рыба',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 18),
        _cardButton('Забрать', Icons.check, true, _takeTrash),
      ],
    );
  }

  Future<void> _takeTrash() async {
    final t = _pendingTrash;
    if (t == null) {
      _resetToFreeWater();
      return;
    }
    final span = t.rewardMax - t.rewardMin;
    final amount = t.rewardMin + (span > 0 ? _rnd.nextInt(span + 1) : 0);
    await ref.read(playerControllerProvider.notifier).credit(t.reward, amount);
    if (!mounted) return;
    _toast('+$amount ${t.reward == CurrencyType.gold ? 'золота' : 'серебра'}');
    _resetToFreeWater();
  }

  Widget _cardButton(
    String label,
    IconData i,
    bool primary,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: primary ? const Color(0xFFE6A23C) : Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: primary ? Colors.transparent : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(i, size: 18, color: primary ? Colors.black : Colors.white),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: primary ? Colors.black : Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _approach(double v, double target, double dt, double rate) {
    return v + (target - v) * (dt * rate).clamp(0.0, 1.0);
  }
}

/// Дымка/виньетка поверх фото — глубина сцены и читаемость интерфейса.
class _SceneScrim extends StatelessWidget {
  const _SceneScrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.30),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withValues(alpha: 0.45),
            ],
            stops: const [0, 0.22, 0.6, 1],
          ),
        ),
      ),
    );
  }
}

/// Мини-профиль дна для панели эхолота (силуэт рельефа по форме локации).
/// Рисует рыболовную катушку на кнопке: спул со спицами + кривошип-ручка.
/// Вращается на [angle] при подмотке — видно, что крутишь катушку.
/// Тучка с осадками для уведомления о погоде: покачивается, из неё сыплются
/// капли (дождь) или снежинки.
class _RainCloudPainter extends CustomPainter {
  _RainCloudPainter(this.t, this.accent, this.snow);
  final double t;
  final Color accent;
  final bool snow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final sway = math.sin(t * 1.4) * 1.2;
    final cx = w * 0.5 + sway, cy = h * 0.4;
    final cloud = Paint()..color = const Color(0xFFC2CDD6);
    canvas.drawCircle(Offset(cx - 9, cy + 2), 8, cloud);
    canvas.drawCircle(Offset(cx + 8, cy + 3), 7, cloud);
    canvas.drawCircle(Offset(cx, cy - 4), 9, cloud);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 14, cy + 1, 28, 8), const Radius.circular(5)),
      cloud,
    );
    final rnd = math.Random(3);
    for (var i = 0; i < 6; i++) {
      final bx = cx - 12 + rnd.nextDouble() * 24;
      final ph = rnd.nextDouble();
      final life = (t * (snow ? 0.7 : 1.6) + ph) % 1.0;
      final y = cy + 8 + life * (h - cy - 10);
      final al = (1 - life) * 0.9;
      if (snow) {
        canvas.drawCircle(
            Offset(bx + math.sin((life + ph) * 6) * 2, y),
            1.5,
            Paint()..color = Colors.white.withValues(alpha: al));
      } else {
        canvas.drawLine(
            Offset(bx, y),
            Offset(bx - 1.2, y + 5),
            Paint()
              ..color = accent.withValues(alpha: al)
              ..strokeWidth = 1.6
              ..strokeCap = StrokeCap.round);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RainCloudPainter old) => old.t != t;
}

class _ReelKnobPainter extends CustomPainter {
  _ReelKnobPainter(this.angle);
  final double angle;

  static const _col = Color(0xFF2F4D38);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    canvas.save();
    canvas.translate(r, r);
    canvas.rotate(angle);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..color = _col;
    final fill = Paint()..color = _col;
    // Обод спула.
    canvas.drawCircle(Offset.zero, r * 0.56, stroke);
    // Спицы спула.
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      canvas.drawLine(
        Offset(math.cos(a) * r * 0.2, math.sin(a) * r * 0.2),
        Offset(math.cos(a) * r * 0.52, math.sin(a) * r * 0.52),
        stroke,
      );
    }
    // Ось.
    canvas.drawCircle(Offset.zero, r * 0.15, fill);
    // Кривошип-ручка: плечо за ободом + рукоятка-кноб.
    canvas.drawLine(
      Offset.zero,
      Offset(r * 0.84, 0),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = _col,
    );
    canvas.drawCircle(Offset(r * 0.84, 0), r * 0.14, fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ReelKnobPainter old) => old.angle != angle;
}

/// «Разрез воды» для настройки спуска: вода-градиент, зоны глубины (активная
/// подсвечена), контур дна по форме, призрачные рыбы, поплавок и крючок.
class _DepthColumnPainter extends CustomPainter {
  _DepthColumnPainter({
    required this.depthFrac,
    required this.maxDepthMeters,
    required this.shape,
    required this.zone,
    required this.time,
  });

  final double depthFrac;
  final int maxDepthMeters;
  final String shape;
  final DepthZone zone;
  final double time;

  void _t(Canvas c, String s, Offset o, Color col, double size,
      {bool bold = false, bool right = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: col,
          fontSize: size,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, right ? Offset(o.dx - tp.width, o.dy) : o);
  }

  void _ghostFish(Canvas c, Offset p, double len, int dir) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.12);
    final body = Path()
      ..moveTo(p.dx + dir * len * 0.5, p.dy)
      ..quadraticBezierTo(p.dx, p.dy - len * 0.28, p.dx - dir * len * 0.5, p.dy)
      ..quadraticBezierTo(p.dx, p.dy + len * 0.28, p.dx + dir * len * 0.5, p.dy)
      ..close();
    c.drawPath(body, paint);
    final tail = Path()
      ..moveTo(p.dx - dir * len * 0.5, p.dy)
      ..lineTo(p.dx - dir * len * 0.72, p.dy - len * 0.18)
      ..lineTo(p.dx - dir * len * 0.72, p.dy + len * 0.18)
      ..close();
    c.drawPath(tail, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final rr = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    canvas.save();
    canvas.clipRRect(rr);

    // Вода — вертикальный градиент.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2C5A6E), Color(0xFF081722)],
        ).createShader(Offset.zero & size),
    );

    const surfaceY = 24.0;
    final bedY = h - 28;
    double yAt(double f) => surfaceY + (bedY - surfaceY) * f;

    // Зоны глубины (активная подсвечена золотом), подписи справа.
    const edges = [0.0, 0.25, 0.55, 0.80, 1.0];
    const names = ['мелко', 'средне', 'свал', 'яма'];
    final activeIdx = switch (zone) {
      DepthZone.shallow => 0,
      DepthZone.mid => 1,
      DepthZone.dropOff => 2,
      DepthZone.pit => 3,
    };
    for (var i = 0; i < 4; i++) {
      final y0 = yAt(edges[i]);
      final y1 = yAt(edges[i + 1]);
      if (i == activeIdx) {
        canvas.drawRect(
          Rect.fromLTRB(0, y0, w, y1),
          Paint()..color = kGold.withValues(alpha: 0.10),
        );
      }
      _t(canvas, names[i], Offset(w - 6, (y0 + y1) / 2 - 6),
          i == activeIdx ? kGold : Colors.white38, 9,
          right: true);
      if (i > 0) {
        canvas.drawLine(
          Offset(0, y0),
          Offset(w, y0),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.12)
            ..strokeWidth = 1,
        );
      }
    }

    // Призрачные рыбы на разных горизонтах (намёк на присутствие, без названий).
    for (var i = 0; i < 3; i++) {
      final fy = yAt([0.30, 0.56, 0.76][i]);
      final ph = time * 0.45 + i * 2.1;
      final fx = w * (0.32 + 0.36 * (0.5 + 0.5 * math.sin(ph)));
      _ghostFish(canvas, Offset(fx, fy), 10.0 + i * 3, math.sin(ph) >= 0 ? 1 : -1);
    }

    // Дно по форме водоёма.
    final amp = switch (shape) {
      'pit' => 9.0,
      'dropOff' => 13.0,
      'ridge' => 11.0,
      _ => 4.0,
    };
    final bed = Path()
      ..moveTo(0, h)
      ..lineTo(0, bedY);
    for (var x = 0.0; x <= w; x += 5) {
      final yy =
          bedY + amp * math.sin(x / w * math.pi * 2 + (shape == 'pit' ? 1.6 : 0));
      bed.lineTo(x, yy);
    }
    bed
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(bed, Paint()..color = const Color(0xFF112230));

    // Леска от поверхности к крючку.
    final hookY = yAt(depthFrac);
    canvas.drawLine(
      Offset(cx, surfaceY),
      Offset(cx, hookY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = 1.3,
    );

    // Поплавок на поверхности (лёгкий бобинг).
    final bob = math.sin(time * 2) * 1.4;
    canvas.drawCircle(
      Offset(cx, surfaceY + bob),
      4.5,
      Paint()..color = const Color(0xFFE5483B),
    );
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(cx, surfaceY + 7 + bob), width: 2, height: 7),
      Paint()..color = Colors.white70,
    );

    // Крючок с наживкой на выставленной глубине.
    canvas.drawCircle(
      Offset(cx, hookY),
      3.4,
      Paint()..color = const Color(0xFFC9A24A),
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx, hookY)
        ..quadraticBezierTo(cx + 5, hookY + 7, cx, hookY + 9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white70,
    );

    // Заголовок и «дно N м».
    _t(canvas, 'ГЛУБИНА', const Offset(6, 5), Colors.white70, 10, bold: true);
    _t(canvas, 'дно $maxDepthMeters м', Offset(6, h - 18), Colors.white38, 10);

    // Пилюля глубины у крючка.
    final lbl = '${(depthFrac * maxDepthMeters).toStringAsFixed(1)} м';
    final tp = TextPainter(
      text: TextSpan(
        text: lbl,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final pill = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx + 10, hookY - 9, tp.width + 12, 18),
      const Radius.circular(9),
    );
    canvas.drawRRect(pill, Paint()..color = Colors.black.withValues(alpha: 0.6));
    canvas.drawRRect(
      pill,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = kGold.withValues(alpha: 0.7),
    );
    tp.paint(canvas, Offset(cx + 16, hookY - 7));

    canvas.restore();
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = kGold.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(covariant _DepthColumnPainter old) =>
      old.depthFrac != depthFrac || old.time != time || old.zone != zone;
}
