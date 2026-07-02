import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/fishing_location.dart';
import '../daily/daily_dialog.dart';
import '../weather/weather_screen.dart';
import '../bestiary/bestiary_tab.dart';
import '../fishing/fishing_screen.dart';
import '../gear/gear_tab.dart';
import '../profile/profile_window.dart';
import '../../shared/content_images.dart';
import '../shell/ui_kit.dart';
import '../shop/shop_tab.dart';
import '../skills/skills_screen.dart';
import '../tasks/tasks_screen.dart';
import '../tips/tips_screen.dart';
import '../tournaments/tournaments_tab.dart';
import 'region_store.dart';
import 'russia_geo.dart';

/// Карта России по субъектам (реальные границы, проекция Альберса) с зумом.
///
/// • Колесо/пинч/кнопки — масштаб 1–8×; пины водоёмов не растут при зуме
///   (контр-масштаб), подписи появляются при приближении.
/// • Каждый регион кликабелен: подсветка при наведении, панель с водоёмами.
/// • Внизу — меню разделов: Снаряжение · Магазин · Достижения · Бестиарий ·
///   Турниры · Профиль (открываются окнами поверх карты).
class RussiaMapScreen extends ConsumerStatefulWidget {
  const RussiaMapScreen({super.key});

  @override
  ConsumerState<RussiaMapScreen> createState() => _RussiaMapScreenState();
}

class _RussiaMapScreenState extends ConsumerState<RussiaMapScreen>
    with SingleTickerProviderStateMixin {
  // Свой контроллер зума/панорамы: screen = scene * _s + _o.
  double _s = 1;
  Offset _o = Offset.zero;
  Size _viewport = Size.zero;
  double _pinchStartScale = 1;

  // Плавный зум по кнопкам (+/−/вся карта).
  late final AnimationController _zoomCtrl;
  double _sFrom = 1, _sTo = 1;
  Offset _oFrom = Offset.zero, _oTo = Offset.zero;

  @override
  void initState() {
    super.initState();
    _zoomCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280))
      ..addListener(() {
        final e = Curves.easeOutCubic.transform(_zoomCtrl.value);
        setState(() {
          _s = _sFrom + (_sTo - _sFrom) * e;
          _o = Offset.lerp(_oFrom, _oTo, e)!;
        });
      });
  }

  @override
  void dispose() {
    _zoomCtrl.dispose();
    super.dispose();
  }

  /// Плавный зум к якорю (для кнопок): анимируем масштаб и смещение.
  void _animateZoom(double factor, Offset anchor) {
    final next = (_s * factor).clamp(1.0, 8.0);
    if (next == _s) return;
    final k = next / _s;
    var o = anchor - (anchor - _o) * k;
    final minX = _viewport.width * (1 - next);
    final minY = _viewport.height * (1 - next);
    o = Offset(o.dx.clamp(minX, 0.0), o.dy.clamp(minY, 0.0));
    _sFrom = _s;
    _sTo = next;
    _oFrom = _o;
    _oTo = o;
    _zoomCtrl.forward(from: 0);
  }

  void _animateReset() {
    _sFrom = _s;
    _sTo = 1;
    _oFrom = _o;
    _oTo = Offset.zero;
    _zoomCtrl.forward(from: 0);
  }

  String? _hovered;
  String? _selected;
  _MapCache? _cache;
  bool _dailyShown = false; // авто-показ ежедневки — один раз за заход

  static const _navHeight = 60.0;

  // --- Кэш проекции -----------------------------------------------------------

  _MapCache _ensureCache(List<RuRegion> regions, Size size) {
    final c = _cache;
    if (c != null && c.size == size && identical(c.regions, regions)) return c;
    final bounds = RussiaMapTransform.projectedBoundsOf(
        regions.expand((r) => r.rings).expand((ring) => ring));
    final t = RussiaMapTransform.fitRaw(bounds, size, paddingFrac: 0.055);
    final paths = <(RuRegion, Path)>[];
    for (final r in regions) {
      final p = Path();
      for (final ring in r.rings) {
        for (var i = 0; i < ring.length; i++) {
          final q = t.map(ring[i].dx, ring[i].dy);
          if (i == 0) {
            p.moveTo(q.dx, q.dy);
          } else {
            p.lineTo(q.dx, q.dy);
          }
        }
        p.close();
      }
      paths.add((r, p));
    }
    final waterRegion = <String, String>{};
    for (final e in activeWaterGeo().entries) {
      for (final r in regions) {
        if (r.contains(e.value.$1, e.value.$2)) {
          waterRegion[e.key] = r.nameEn;
          break;
        }
      }
    }
    // Объединённый контур суши — строим один раз под размер.
    Path? land;
    for (final (_, p) in paths) {
      land = land == null ? p : Path.combine(PathOperation.union, land, p);
    }
    return _cache =
        _MapCache(size, regions, t, paths, waterRegion, land ?? Path());
  }

  RuRegion? _hit(Offset scenePos) {
    final c = _cache;
    if (c == null) return null;
    for (final (region, path) in c.paths) {
      if (path.contains(scenePos)) return region;
    }
    return null;
  }

  // --- Зум/панорама (якорь — точка под курсором) -------------------------------

  /// Не даём карте уезжать за края вьюпорта.
  void _clampPan() {
    final minX = _viewport.width * (1 - _s);
    final minY = _viewport.height * (1 - _s);
    _o = Offset(_o.dx.clamp(minX, 0.0), _o.dy.clamp(minY, 0.0));
  }

  /// Масштабирование с сохранением точки [anchor] (экранные координаты)
  /// на месте: zoom-to-cursor.
  void _applyZoom(double factor, Offset anchor) {
    final next = (_s * factor).clamp(1.0, 8.0);
    final k = next / _s;
    if (k == 1) return;
    _o = anchor - (anchor - _o) * k;
    _s = next;
    _clampPan();
    setState(() {});
  }

  void _panBy(Offset delta) {
    if (_s <= 1) return;
    _o += delta;
    _clampPan();
    setState(() {});
  }


  // --- UI ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final regionsAsync = ref.watch(russiaRegionsProvider);
    final locationsAsync = ref.watch(locationsProvider);
    final player = ref.watch(playerControllerProvider).value;
    final unlocked = player?.unlockedLocationIds ?? const <String>{};

    // Один раз за заход показываем ежедневную награду, если доступна.
    if (!_dailyShown && player != null && player.dailyAvailable) {
      _dailyShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showDailyReward(context);
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A141D),
      body: regionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка карты: $e')),
        data: (regions) => locationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Ошибка: $e')),
          data: (all) {
            final waters = all
                .where(
                    (l) => l.countryId == 'ru' && activeWaterGeo().containsKey(l.id))
                .toList();
            return LayoutBuilder(builder: (context, c) {
              final size = Size(c.maxWidth, c.maxHeight);
              final mapSize = Size(size.width, size.height - _navHeight);
              _viewport = mapSize;
              final cache = _ensureCache(regions, mapSize);
              return Column(
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Свой вьюер: колесо и дабл-клик зумят в точку курсора,
                        // драг — панорама, пинч — масштаб с якорем в фокусе.
                        Listener(
                          onPointerSignal: (e) {
                            if (e is PointerScrollEvent) {
                              final k =
                                  math.exp(-e.scrollDelta.dy / 380);
                              _applyZoom(k, e.localPosition);
                            }
                          },
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onDoubleTapDown: (d) => _applyZoom(
                                _s < 4 ? 2.0 : 1 / _s, d.localPosition),
                            onScaleStart: (d) => _pinchStartScale = _s,
                            onScaleUpdate: (d) {
                              if (d.scale != 1) {
                                _applyZoom(
                                    (_pinchStartScale * d.scale) / _s,
                                    d.localFocalPoint);
                              } else {
                                _panBy(d.focalPointDelta);
                              }
                            },
                            child: ClipRect(
                              child: Transform(
                                transform: Matrix4.identity()
                                  ..translateByDouble(_o.dx, _o.dy, 0, 1)
                                  ..scaleByDouble(_s, _s, 1, 1),
                                child: SizedBox(
                                  width: mapSize.width,
                                  height: mapSize.height,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      MouseRegion(
                                        onHover: (e) {
                                          final r = _hit(e.localPosition)
                                              ?.nameEn;
                                          if (r != _hovered) {
                                            setState(() => _hovered = r);
                                          }
                                        },
                                        onExit: (_) => setState(
                                            () => _hovered = null),
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTapUp: (d) {
                                            final r =
                                                _hit(d.localPosition);
                                            setState(() => _selected =
                                                r?.nameEn == _selected
                                                    ? null
                                                    : r?.nameEn);
                                          },
                                          child: CustomPaint(
                                            painter: _RegionsPainter(
                                              cache: cache,
                                              hovered: _hovered,
                                              selected: _selected,
                                            ),
                                          ),
                                        ),
                                      ),
                                      for (final loc in waters)
                                        _pin(context, loc, cache.t,
                                            open: unlocked
                                                    .contains(loc.id) ||
                                                loc.entryCost.amount == 0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_selected != null)
                          _regionPanel(cache, regions, waters, unlocked),
                        _topBar(context),
                        _zoomControls(mapSize),
                      ],
                    ),
                  ),
                  _bottomNav(context),
                ],
              );
            });
          },
        ),
      ),
    );
  }

  // --- Верхняя панель ---------------------------------------------------------

  /// Кнопка ежедневной награды с красной точкой, когда награда доступна.
  /// Кнопка перехода к прогнозу погоды (наша карта России).
  Widget _weatherButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const WeatherScreen()),
      ),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF15181C),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: const Icon(Icons.cloud_outlined,
            color: Color(0xFF8FC4DC), size: 20),
      ),
    );
  }

  Widget _giftButton(BuildContext context) {
    final available =
        ref.watch(playerControllerProvider).value?.dailyAvailable ?? false;
    return GestureDetector(
      onTap: () => showDailyReward(context),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF15181C),
              shape: BoxShape.circle,
              border: Border.all(
                  color: available ? kGold : Colors.white.withValues(alpha: 0.2)),
            ),
            child: Icon(Icons.card_giftcard,
                color: available ? kGold : Colors.white70, size: 20),
          ),
          if (available)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5483B),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: const Color(0xFF0A141D), width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final hoveredRu = _hovered == null ? null : ruRegionName(_hovered!);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF15181C),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                _giftButton(context),
                const SizedBox(width: 8),
                _weatherButton(context),
                const Spacer(),
                const StatusPill(),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [kGoldLight, kGold]),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 6)
                    ],
                  ),
                  child: const Text('КАРТА · РОССИЯ',
                      style: TextStyle(
                          color: kTextDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6)),
                ),
              ],
            ),
            if (hoveredRu != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kGold.withValues(alpha: 0.4)),
                  ),
                  child: Text(hoveredRu,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- Кнопки зума -------------------------------------------------------------

  Widget _zoomControls(Size viewport) {
    Widget btn(IconData icon, VoidCallback onTap, {String? tip}) {
      return Tooltip(
        message: tip ?? '',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF15181C).withValues(alpha: 0.9),
              shape: BoxShape.circle,
              border: Border.all(color: kGold.withValues(alpha: 0.5)),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 6)
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            btn(Icons.add,
                () => _animateZoom(1.5, viewport.center(Offset.zero)),
                tip: 'Приблизить'),
            btn(Icons.remove,
                () => _animateZoom(1 / 1.5, viewport.center(Offset.zero)),
                tip: 'Отдалить'),
            btn(Icons.fit_screen, _animateReset, tip: 'Вся карта'),
          ],
        ),
      ),
    );
  }

  // --- Нижнее меню разделов -----------------------------------------------------

  Widget _bottomNav(BuildContext context) {
    final items = <(IconData, String, Widget, bool)>[
      (Icons.backpack_outlined, 'СНАРЯЖЕНИЕ', const GearTab(), false),
      (Icons.storefront_outlined, 'МАГАЗИН', const ShopTab(), false),
      (Icons.account_tree_outlined, 'НАВЫКИ', const SkillsTree(), false),
      (Icons.assignment_outlined, 'ЗАДАНИЯ', const TasksScreen(), false),
      (Icons.menu_book_outlined, 'БЕСТИАРИЙ', const BestiaryTab(), false),
      (Icons.shield_outlined, 'ТУРНИРЫ', const TournamentsTab(), false),
      (Icons.person_outline, 'ПРОФИЛЬ', const ProfileWindowBody(), true),
    ];
    return Container(
      height: _navHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF101418),
        border: Border(top: BorderSide(color: kGold.withValues(alpha: 0.35))),
        boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 12)],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final (icon, label, body, _) in items)
              Expanded(
                child: InkWell(
                  onTap: () => GameWindow.show(
                      context, label.toLowerCase(), body),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 20, color: kGold),
                      const SizedBox(height: 3),
                      Text(label,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- Панель выбранного региона -------------------------------------------------

  Widget _regionPanel(_MapCache cache, List<RuRegion> regions,
      List<FishingLocation> waters, Set<String> unlocked) {
    final region = regions.where((r) => r.nameEn == _selected).firstOrNull;
    if (region == null) return const SizedBox.shrink();
    final regionWaters = waters
        .where((w) => cache.waterRegion[w.id] == region.nameEn)
        .toList();

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: HeaderPanel(
            header: region.nameRu,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (regionWaters.isEmpty)
                  Text(
                    'Водоёмы этого региона появятся в следующих обновлениях.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12.5),
                  )
                else
                  for (final w in regionWaters)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            unlocked.contains(w.id) ||
                                    w.entryCost.amount == 0
                                ? Icons.water
                                : Icons.lock,
                            size: 16,
                            color: kGold,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(w.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700)),
                          ),
                          GoldButton(
                            label: unlocked.contains(w.id) ||
                                    w.entryCost.amount == 0
                                ? 'На воду'
                                : '${w.entryCost.amount} 🪙',
                            onTap: () => unlocked.contains(w.id) ||
                                    w.entryCost.amount == 0
                                ? _waterSheet(context, w)
                                : _unlockDialog(context, w),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Пины водоёмов --------------------------------------------------------------

  Widget _pin(BuildContext context, FishingLocation loc, RussiaMapTransform t,
      {required bool open}) {
    final geo = activeWaterGeo()[loc.id]!;
    final p = t.map(geo.$1, geo.$2);
    const w = 110.0;
    final s = _s;
    final showLabel = s >= 1.6;
    return Positioned(
      left: p.dx - w / 2,
      top: p.dy - 13,
      width: w,
      child: Transform.scale(
        // Контр-масштаб: пин сохраняет экранный размер при зуме карты.
        scale: 1 / s,
        alignment: const Alignment(0, -0.6),
        child: GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onTap: () =>
              open ? _waterSheet(context, loc) : _unlockDialog(context, loc),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: open
                      ? const RadialGradient(
                          center: Alignment(-0.3, -0.4),
                          colors: [Color(0xFFF7F1DC), Color(0xFFD9CFAF)],
                        )
                      : null,
                  color: open ? null : const Color(0xFF3A4047),
                  border: Border.all(
                      color: open ? kGold : Colors.white38, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 5),
                  ],
                ),
                child: Icon(open ? Icons.water : Icons.lock,
                    size: 13,
                    color: open ? const Color(0xFF275B7A) : Colors.white54),
              ),
              if (showLabel) ...[
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                        color: open
                            ? kGold.withValues(alpha: 0.55)
                            : Colors.white24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(loc.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: open ? Colors.white : Colors.white60,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800)),
                      if (!open)
                        Text('🪙 ${loc.entryCost.amount}',
                            style: const TextStyle(
                                color: kGold, fontSize: 9.5)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- Карточка водоёма и оплата -----------------------------------------------

  void _waterSheet(BuildContext context, FishingLocation loc) {
    var tab = 0; // 0 — инфо, 1 — советы местного
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: const BoxDecoration(
            color: kPanelBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(top: BorderSide(color: kGold, width: 1.5)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.72,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: AspectRatio(
                        aspectRatio: 16 / 6,
                        child: contentImage(
                          assetStem(loc.primaryBackdrop),
                          loc.primaryBackdrop,
                          fallback: (_) =>
                              const ColoredBox(color: Color(0xFF1A1F25)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child:
                              Text(loc.name, style: displayStyle(size: 21)),
                        ),
                        _sheetTab(ctx, 'ИНФО', 0, tab,
                            () => setSheet(() => tab = 0)),
                        const SizedBox(width: 6),
                        _sheetTab(ctx, 'СОВЕТЫ', 1, tab,
                            () => setSheet(() => tab = 1)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: SingleChildScrollView(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          child: tab == 0
                              ? Column(
                                  key: const ValueKey('info'),
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(loc.description,
                                        style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.65),
                                            fontSize: 12.5,
                                            height: 1.35)),
                                    const SizedBox(height: 10),
                                    Row(children: [
                                      const Icon(Icons.water,
                                          size: 14, color: kGold),
                                      const SizedBox(width: 5),
                                      Text(
                                          'до ${loc.depthProfile.maxDepthMeters} м',
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12)),
                                      const SizedBox(width: 14),
                                      const Icon(Icons.set_meal,
                                          size: 14, color: kGold),
                                      const SizedBox(width: 5),
                                      Text('${loc.species.length} вид(ов)',
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12)),
                                    ]),
                                  ],
                                )
                              : Padding(
                                  key: const ValueKey('tips'),
                                  padding: const EdgeInsets.only(top: 2),
                                  child: LocationTips(locationId: loc.id),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GoldButton(
                        label: 'На воду',
                        icon: Icons.play_arrow_rounded,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _gateAndGo(loc);
                        },
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

  Widget _sheetTab(BuildContext context, String label, int me, int current,
      VoidCallback onTap) {
    final active = me == current;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? kGold.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? kGold : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? kGold : Colors.white60,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }

  /// Пропуск на воду только с собранной снастью — иначе окно с недостающим.
  void _gateAndGo(FishingLocation loc) {
    final catalog = ref.read(gearCatalogProvider).value ?? const [];
    final player = ref.read(playerControllerProvider).value;
    final byId = {for (final g in catalog) g.id: g};
    final missing = (player == null || byId.isEmpty)
        ? const <String>[]
        : ref.read(loadoutCheckProvider).missingFor(player, byId);
    if (missing.isEmpty) {
      Navigator.of(context).push(
        fishingCurtainRoute(
          FishingScreen(locationId: loc.id),
          caption: loc.name,
        ),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: HeaderPanel(
            header: 'Снасть не собрана',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Для выхода на воду не хватает:',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12.5)),
                const SizedBox(height: 8),
                for (final m in missing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(children: [
                      const Icon(Icons.cancel,
                          size: 14, color: Color(0xFFE5483B)),
                      const SizedBox(width: 8),
                      Text(m,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Позже',
                          style: TextStyle(color: Colors.white60)),
                    ),
                    const SizedBox(width: 8),
                    GoldButton(
                      label: 'Снаряжение',
                      icon: Icons.backpack,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        GameWindow.show(
                            context, 'Снаряжение', const GearTab());
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _unlockDialog(
      BuildContext context, FishingLocation loc) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: HeaderPanel(
            header: 'Открыть водоём',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(loc.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.monetization_on,
                        size: 16, color: kGold),
                    const SizedBox(width: 6),
                    Text('${loc.entryCost.amount}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Отмена',
                          style: TextStyle(color: Colors.white60)),
                    ),
                    const SizedBox(width: 10),
                    GoldButton(
                      label: 'Открыть',
                      icon: Icons.lock_open,
                      onTap: () async {
                        final res = await ref
                            .read(playerControllerProvider.notifier)
                            .unlockLocation(loc);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (!mounted) return;
                        final msg = switch (res) {
                          UnlockResult.ok => 'Водоём открыт!',
                          UnlockResult.notEnoughMoney =>
                            'Недостаточно монет',
                          _ => 'Не удалось открыть',
                        };
                        ScaffoldMessenger.of(this.context)
                          ..clearSnackBars()
                          ..showSnackBar(SnackBar(
                            content: Text(msg),
                            duration: const Duration(milliseconds: 1400),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: const Color(0xFF1A1F25),
                          ));
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Кэш проекции под конкретный размер: пути регионов и привязка водоёмов.
class _MapCache {
  _MapCache(this.size, this.regions, this.t, this.paths, this.waterRegion,
      this.landPath);

  final Size size;
  final List<RuRegion> regions;
  final RussiaMapTransform t;
  final List<(RuRegion, Path)> paths;
  final Map<String, String> waterRegion;

  /// Объединённый контур всей суши (для рельефа и каёмки берега).
  final Path landPath;
}

/// Художник: море, тень страны, регионы (заливка + границы), озёра, реки,
/// Москва. Подсветка hovered/selected.
class _RegionsPainter extends CustomPainter {
  _RegionsPainter({
    required this.cache,
    required this.hovered,
    required this.selected,
  });

  final _MapCache cache;
  final String? hovered;
  final String? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final t = cache.t;
    final land = cache.landPath;
    final w = size.shortestSide;

    // 1. Море — глубокий вертикальный градиент.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          const [Color(0xFF0E2230), Color(0xFF061016)],
        ),
    );
    // Ореол суши в воде (мягкое свечение берега) + тень (объём над морем).
    canvas.drawPath(
      land,
      Paint()
        ..color = const Color(0xFF1B3D4E).withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.02),
    );
    canvas.drawPath(
      land.shift(Offset(0, w * 0.01)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.012),
    );

    // 2. Регионы: заливка + тонкая граница.
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = const Color(0xFF0B141A).withValues(alpha: 0.7);
    for (var i = 0; i < cache.paths.length; i++) {
      final (region, path) = cache.paths[i];
      final isSel = region.nameEn == selected;
      final isHov = region.nameEn == hovered;
      final hue = 100 + (i * 37) % 40;
      final base = HSLColor.fromAHSL(
              1, hue.toDouble(), 0.22, isSel ? 0.235 : (isHov ? 0.2 : 0.155))
          .toColor();
      canvas.drawPath(path, Paint()..color = base);
      canvas.drawPath(path, border);
    }

    // 3. Рельеф — строго по суше.
    canvas.save();
    canvas.clipPath(land);
    final lb = land.getBounds();
    // Купол-освещение (мягкий свет сверху-центра).
    canvas.drawRect(
      lb,
      Paint()
        ..shader = ui.Gradient.radial(
          lb.topCenter + Offset(0, lb.height * 0.25),
          lb.longestSide * 0.7,
          [Colors.white.withValues(alpha: 0.05), const Color(0x00FFFFFF)],
        ),
    );
    _drawForests(canvas, land);
    _drawMountains(canvas, t, w);
    _drawLakes(canvas, t, w);
    _drawRivers(canvas, t, w);
    canvas.restore();

    // 4. Каёмка берега — холодный рим-лайт по контуру.
    canvas.drawPath(
      land,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = const Color(0xFF8FB7C9).withValues(alpha: 0.3),
    );

    // 5. Подсветка hovered/selected — поверх рельефа.
    for (final (region, path) in cache.paths) {
      final isSel = region.nameEn == selected;
      final isHov = region.nameEn == hovered;
      if (isSel || isHov) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSel ? 2.2 : 1.3
            ..color = kGold.withValues(alpha: isSel ? 0.95 : 0.6),
        );
      }
    }

    // 6. Москва.
    final moscow = t.map(kMoscow.$1, kMoscow.$2);
    _star(canvas, moscow, w * 0.008,
        Paint()..color = kGold.withValues(alpha: 0.9));
  }

  /// Сглаживание ломаной (Catmull-Rom → кубические безье) — «плавно».
  Path _smooth(List<Offset> p) {
    final path = Path();
    if (p.isEmpty) return path;
    path.moveTo(p.first.dx, p.first.dy);
    if (p.length < 3) {
      for (final q in p.skip(1)) {
        path.lineTo(q.dx, q.dy);
      }
      return path;
    }
    for (var i = 0; i < p.length - 1; i++) {
      final p0 = p[i == 0 ? 0 : i - 1];
      final p1 = p[i];
      final p2 = p[i + 1];
      final p3 = p[i + 2 < p.length ? i + 2 : p.length - 1];
      final c1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
      final c2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  /// Тайга: мягкие зелёные пятна (детерминированный разброс по суше).
  void _drawForests(Canvas canvas, Path land) {
    final b = land.getBounds();
    var seed = 1337;
    double rnd() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed / 0x7fffffff;
    }

    // Светлее и зеленее подложки — тогда лесные массивы читаются.
    const green = Color(0xFF2F5A34);
    const darkGreen = Color(0xFF1A3A20);
    for (var i = 0; i < 175; i++) {
      final fx = b.left + rnd() * b.width;
      final fy = b.top + rnd() * b.height;
      final r = b.shortestSide * (0.013 + rnd() * 0.028);
      final a = 0.22 + rnd() * 0.24;
      final c = rnd() < 0.4 ? darkGreen : green;
      canvas.drawCircle(
        Offset(fx, fy),
        r,
        Paint()
          ..shader = ui.Gradient.radial(Offset(fx, fy), r, [
            c.withValues(alpha: a),
            c.withValues(alpha: 0),
          ]),
      );
    }
  }

  /// Горные хребты — ряды пиков со светлой и теневой гранью и снежными
  /// шапками; под хребтом мягкая тень для объёма.
  void _drawMountains(Canvas canvas, RussiaMapTransform t, double w) {
    final peakW = w * 0.013;
    final peakH = w * 0.024;
    final spacing = w * 0.017;
    var seed = 4242;
    double rnd() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed / 0x7fffffff;
    }

    for (final ridge in kRanges) {
      final pts = [for (final (lon, lat) in ridge) t.map(lon, lat)];
      // Мягкая тень-основание под всем хребтом.
      canvas.drawPath(
        _smooth(pts).shift(Offset(w * 0.003, w * 0.007)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = peakH * 0.95
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF0A0E0A).withValues(alpha: 0.45)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.005),
      );
      // Пики вдоль гребня.
      final chain = _densify(pts, spacing);
      for (var i = 1; i < chain.length - 1; i++) {
        final c = chain[i];
        final h = peakH * (0.7 + rnd() * 0.7);
        final hw = peakW * (0.8 + rnd() * 0.5);
        final apex = c + Offset((rnd() - 0.5) * hw * 0.4, -h);
        final bl = c + Offset(-hw, 0);
        final br = c + Offset(hw, 0);
        // Теневая (правая) грань.
        canvas.drawPath(
          Path()
            ..moveTo(apex.dx, apex.dy)
            ..lineTo(br.dx, br.dy)
            ..lineTo(c.dx, c.dy)
            ..close(),
          Paint()..color = const Color(0xFF2C2920),
        );
        // Освещённая (левая) грань.
        canvas.drawPath(
          Path()
            ..moveTo(apex.dx, apex.dy)
            ..lineTo(bl.dx, bl.dy)
            ..lineTo(c.dx, c.dy)
            ..close(),
          Paint()..color = const Color(0xFF6E6147),
        );
        // Снежная шапка у высоких пиков.
        if (h > peakH * 1.05) {
          final s1 = Offset.lerp(apex, bl, 0.36)!;
          final s2 = Offset.lerp(apex, br, 0.36)!;
          canvas.drawPath(
            Path()
              ..moveTo(apex.dx, apex.dy)
              ..lineTo(s1.dx, s1.dy)
              ..lineTo(s2.dx, s2.dy)
              ..close(),
            Paint()..color = const Color(0xFFEAE4D6).withValues(alpha: 0.9),
          );
        }
      }
    }
  }

  /// Уплотнение ломаной точками через равные интервалы (для пиков).
  List<Offset> _densify(List<Offset> pts, double spacing) {
    final out = <Offset>[];
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      final n = math.max(1, ((b - a).distance / spacing).floor());
      for (var k = 0; k < n; k++) {
        out.add(Offset.lerp(a, b, k / n)!);
      }
    }
    out.add(pts.last);
    return out;
  }

  /// Озёра (Ладога/Онега): градиент глубины + лёгкий рим-лайт сверху.
  void _drawLakes(Canvas canvas, RussiaMapTransform t, double w) {
    void lake(Offset c, double rx, double ry) {
      final rect = Rect.fromCenter(center: c, width: rx, height: ry);
      canvas.drawOval(
        rect.inflate(w * 0.004),
        Paint()
          ..color = const Color(0xFF2A5A72).withValues(alpha: 0.25)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.004),
      );
      canvas.drawOval(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter,
              const [Color(0xFF2C5E78), Color(0xFF12303F)]),
      );
      canvas.drawArc(
        rect.deflate(w * 0.0015),
        math.pi * 1.05,
        math.pi * 0.9,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.0015
          ..color = const Color(0xFF8FC4DC).withValues(alpha: 0.4),
      );
    }

    lake(t.map(kLakeLadoga.$1, kLakeLadoga.$2), w * 0.03, w * 0.027);
    lake(t.map(kLakeOnega.$1, kLakeOnega.$2), w * 0.02, w * 0.026);
  }

  /// Реки и Байкал — плавные кривые с ореолом, руслом и бликом.
  void _drawRivers(Canvas canvas, RussiaMapTransform t, double w) {
    for (final river in kRivers) {
      final path = _smooth([for (final (lon, lat) in river) t.map(lon, lat)]);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.01
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF3E6E8C).withValues(alpha: 0.3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.004),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.0042
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF74A7C4),
      );
      canvas.drawPath(
        path.shift(Offset(0, -w * 0.001)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.0015
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFBFE0EE).withValues(alpha: 0.5),
      );
    }
    // Байкал — толще, как глубокое озеро-разлом.
    final bp = _smooth([for (final (lon, lat) in kBaikalLine) t.map(lon, lat)]);
    canvas.drawPath(
      bp,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.014
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF2A5A72).withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.004),
    );
    canvas.drawPath(
      bp,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.01
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF1E4A60),
    );
    canvas.drawPath(
      bp,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.004
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF3E7C98).withValues(alpha: 0.7),
    );
  }

  void _star(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RegionsPainter old) =>
      old.hovered != hovered ||
      old.selected != selected ||
      !identical(old.cache, cache);
}
