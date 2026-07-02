import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/fish_species.dart';
import '../../domain/value_objects/fishing_enums.dart';
import '../../domain/value_objects/weight.dart';
import '../../shared/content_images.dart';
import '../../shared/rendering/fish_icons.dart';
import '../shell/ui_kit.dart';
import 'fish_meta.dart';

/// Раздел «Бестиарий»: трофеи (топ по весу) + коллекция видов с «портретами»
/// рыб. Фильтр по виду ловли (Все / хищник / мирная / донная / морская).
/// Пойманные открыты (тап → детальная карточка с изображением рыбы),
/// остальные — тёмным силуэтом.
class BestiaryTab extends ConsumerStatefulWidget {
  const BestiaryTab({super.key});

  @override
  ConsumerState<BestiaryTab> createState() => _BestiaryTabState();
}

class _BestiaryTabState extends ConsumerState<BestiaryTab> {
  String _family = 'Все';

  @override
  Widget build(BuildContext context) {
    final speciesAsync = ref.watch(speciesProvider);
    final player = ref.watch(playerControllerProvider).value;
    final discovered = player?.discoveredSpeciesIds ?? const <String>{};
    final counts = player?.speciesCounts ?? const <String, int>{};
    final best = player?.speciesBestGrams ?? const <String, int>{};
    final trophies = player?.trophies ?? const <Catch>[];

    return speciesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Ошибка: $e')),
      data: (species) {
        // Категории — по «семейству» вида, в порядке появления.
        final families = <String>['Все'];
        for (final s in species) {
          if (!families.contains(s.family)) families.add(s.family);
        }
        final shown = _family == 'Все'
            ? species
            : species.where((s) => s.family == _family).toList();
        // Сквозной номер вида «№ X / N» для карточки.
        final indexById = {
          for (var i = 0; i < species.length; i++) species[i].id: i + 1
        };

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (trophies.isNotEmpty) ...[
              const SectionTitle('Трофеи', icon: Icons.emoji_events_outlined),
              const SizedBox(height: 12),
              GamePanel(
                child: Column(
                  children: [
                    for (var i = 0; i < trophies.length && i < 5; i++)
                      _trophyRow(i + 1, trophies[i]),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            SectionTitle('Бестиарий  ·  ${discovered.length}/${species.length}',
                icon: Icons.menu_book_outlined),
            const SizedBox(height: 12),
            // Фильтр по виду ловли.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in families)
                  _familyChip(f, _familyLabel(f), _family == f),
              ],
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: shown.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 286,
                mainAxisExtent: 384,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemBuilder: (context, i) {
                final sp = shown[i];
                final open = discovered.contains(sp.id);
                return _SpeciesCard(
                  species: sp,
                  discovered: open,
                  count: counts[sp.id] ?? 0,
                  bestGrams: best[sp.id] ?? 0,
                  index: indexById[sp.id] ?? 0,
                  total: species.length,
                  onTap: open
                      ? () => showDialog<void>(
                            context: context,
                            builder: (_) => _SpeciesDialog(
                                species: sp,
                                count: counts[sp.id] ?? 0,
                                bestGrams: best[sp.id] ?? 0),
                          )
                      : null,
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _familyChip(String value, String label, bool active) {
    return GestureDetector(
      onTap: () => setState(() => _family = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? kGold.withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? kGold : Colors.white.withValues(alpha: 0.12),
              width: active ? 1.6 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? kGold : Colors.white70,
                fontSize: 12.5,
                fontWeight: FontWeight.w800)),
      ),
    );
  }

  static String _familyLabel(String f) => switch (f) {
        'Все' => 'Все',
        'хищник' => 'Хищники',
        'мирная' => 'Мирные',
        'донная' => 'Донные',
        'морская' => 'Морские',
        _ => f[0].toUpperCase() + f.substring(1),
      };

  Widget _trophyRow(int place, Catch c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        MedalBadge(place, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(c.speciesName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ),
        Text(c.weight.formatted,
            style: const TextStyle(
                color: kGold, fontSize: 14, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

/// Коллекционная карточка вида (TCG-стиль): рамка по редкости с подсветкой,
/// окно под фото 4:3 на фоне #11151A (фото `fish_<id>.png` ляжет без обработки;
/// пока нет — рисованный силуэт), имя+латынь, теги, статы и низ с приманками.
class _SpeciesCard extends StatelessWidget {
  const _SpeciesCard({
    required this.species,
    required this.discovered,
    required this.count,
    required this.bestGrams,
    required this.index,
    required this.total,
    required this.onTap,
  });

  final FishSpecies species;
  final bool discovered;
  final int count;
  final int bestGrams;
  final int index;
  final int total;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Карточка отражает РЕКОРДНЫЙ улов вида: цвет/свечение/лента — по
    // эффективной редкости самого крупного пойманного экземпляра.
    final hasRecord = discovered && bestGrams > 0;
    final effRarity = hasRecord
        ? catchRarity(species, Weight.grams(bestGrams))
        : species.rarity;
    final rc =
        discovered ? rarityColorOf(effRarity) : const Color(0xFF9AA4AD);
    final (glowA, glowB) = discovered ? rarityGlow(effRarity) : (0.0, 0.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: discovered
                ? const [Color(0xFF1C232B), Color(0xFF0F141A)]
                : const [Color(0xFF161B21), Color(0xFF0D1116)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: discovered ? rc : Colors.white.withValues(alpha: 0.10),
            width: 2,
          ),
          boxShadow: [
            const BoxShadow(
                color: Colors.black54, blurRadius: 18, offset: Offset(0, 10)),
            if (glowA > 0)
              BoxShadow(
                  color: rc.withValues(alpha: glowA),
                  blurRadius: glowB,
                  spreadRadius: 1),
          ],
        ),
        child: Stack(
          children: [
            // Верхний блик рамки по редкости.
            if (discovered)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Colors.transparent, rc, Colors.transparent]),
                  ),
                ),
              ),
            // Водяной знак-рыба.
            Positioned(
              right: -14,
              bottom: -18,
              child: Transform.flip(
                flipX: true,
                child: Icon(Icons.set_meal,
                    size: 150, color: Colors.white.withValues(alpha: 0.025)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Лента редкости + индекс.
                  Row(
                    children: [
                      if (discovered) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: rc,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: rc, blurRadius: 8)],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        discovered
                            ? rarityLabelOf(effRarity).toUpperCase()
                            : 'НЕ ОТКРЫТ',
                        style: TextStyle(
                          color: discovered
                              ? rc
                              : Colors.white.withValues(alpha: 0.4),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const Spacer(),
                      Text('№ $index / $total',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.34),
                              fontSize: 10.5)),
                    ],
                  ),
                  const SizedBox(height: 9),
                  // Окно под фото.
                  Expanded(child: _photoWindow(rc)),
                  const SizedBox(height: 9),
                  Text(
                    discovered ? species.name : '???',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: discovered
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                  Text(
                    discovered ? fishLatin(species.id) : 'поймай, чтобы открыть',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 10.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Теги: семейство + среда.
                  Row(
                    children: [
                      Flexible(
                          child: _tag(Icons.bolt,
                              discovered ? species.family : '—')),
                      const SizedBox(width: 6),
                      Flexible(
                        child: _tag(
                          species.habitat == Habitat.fresh
                              ? Icons.water_drop
                              : Icons.waves,
                          discovered ? habitatLabel(species.habitat) : '—',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  // Статы.
                  Row(
                    children: [
                      _stat(
                          'Рекорд',
                          hasRecord
                              ? Weight.grams(bestGrams).formatted
                              : (discovered
                                  ? 'до ${species.weightMax.formatted}'
                                  : '—')),
                      const SizedBox(width: 6),
                      _stat(
                          'Глубина', discovered ? topDepthLabel(species) : '—'),
                      const SizedBox(width: 6),
                      _stat('Поймано', discovered ? '$count' : '0'),
                    ],
                  ),
                  const SizedBox(height: 9),
                  // Низ: приманки + регион.
                  Container(
                    padding: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.phishing,
                            size: 13, color: kGold.withValues(alpha: 0.9)),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            discovered ? topLuresLabel(species, 2) : 'силуэт',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 10.5),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          discovered ? fishRegion(species.id) : '?',
                          style: TextStyle(
                            color: discovered
                                ? rc
                                : Colors.white.withValues(alpha: 0.35),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoWindow(Color rc) {
    final asset = species.photoAsset ?? fishPhotoAsset(species.id);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          center: Alignment(0, -1),
          radius: 1.1,
          colors: [Color(0xFF1A2027), Color(0xFF11151A)],
          stops: [0, 0.6],
        ),
        border: Border.all(color: rc.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(11),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (discovered)
              Align(
                alignment: const Alignment(0, -0.7),
                child: FractionallySizedBox(
                  widthFactor: 0.8,
                  heightFactor: 0.8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        rc.withValues(alpha: 0.28),
                        Colors.transparent
                      ]),
                    ),
                  ),
                ),
              ),
            // Фото вида (загруженное в админке → ассет) или силуэт-откат.
            contentImage(
              'fish_${species.id}',
              asset,
              fallback: (_) => Center(
                child:
                    FishIcon(species.id, discovered: discovered, size: 110),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: kGold),
          const SizedBox(width: 5),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          children: [
            Text(label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3)),
            const SizedBox(height: 2),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

/// Детальная карточка вида: крупное изображение рыбы, описание, оптимальные
/// приманка/глубина/время и счётчик.
class _SpeciesDialog extends StatelessWidget {
  const _SpeciesDialog(
      {required this.species, required this.count, required this.bestGrams});

  final FishSpecies species;
  final int count;
  final int bestGrams;

  @override
  Widget build(BuildContext context) {
    final hasRecord = bestGrams > 0;
    final effRarity = hasRecord
        ? catchRarity(species, Weight.grams(bestGrams))
        : species.rarity;
    final color = rarityColorOf(effRarity);
    final (glowA, glowB) = rarityGlow(effRarity);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          decoration: BoxDecoration(
            color: kPanelBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.7), width: 1.5),
            boxShadow: [
              const BoxShadow(
                  color: Colors.black87, blurRadius: 32, offset: Offset(0, 16)),
              if (glowA > 0)
                BoxShadow(
                    color: color.withValues(alpha: glowA),
                    blurRadius: glowB * 1.5,
                    spreadRadius: 2),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Крупное изображение рыбы (вода) + закрытие.
              Stack(
                children: [
                  Container(
                    height: 170,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0, -0.6),
                        radius: 1.0,
                        colors: [Color(0xFF1A2027), Color(0xFF11151A)],
                        stops: [0, 0.7],
                      ),
                    ),
                    child: contentImage(
                      'fish_${species.id}',
                      species.photoAsset ?? fishPhotoAsset(species.id),
                      fallback: (_) =>
                          Center(child: FishIcon(species.id, size: 230)),
                    ),
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child:
                            const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(rarityLabelOf(effRarity),
                          style: const TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(species.name,
                                style: displayStyle(size: 22))),
                        Text(species.family,
                            style: TextStyle(color: color, fontSize: 12.5)),
                      ],
                    ),
                    Text(fishLatin(species.id),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 12,
                            fontStyle: FontStyle.italic)),
                    const SizedBox(height: 10),
                    Text(species.description,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13, height: 1.4)),
                    const SizedBox(height: 14),
                    _row('Вес',
                        '${species.weightMin.formatted} – ${species.weightMax.formatted}'),
                    if (hasRecord)
                      _row('Ваш рекорд',
                          '${Weight.grams(bestGrams).formatted}  ·  ${rarityLabelOf(effRarity)}'),
                    _row('Лучшие приманки', _topLures(species)),
                    _row('Глубина', _topDepth(species)),
                    _row('Время', _topTime(species)),
                    _row('Поймано', '$count шт.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 130,
          child: Text(label,
              style: TextStyle(
                  color: kGold.withValues(alpha: 0.85), fontSize: 12.5)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ),
      ]),
    );
  }

  String _topLures(FishSpecies s) {
    final e = s.biteProfile.lureTypeWeights.entries
        .where((x) => x.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (e.isEmpty) return 'любые';
    return e.take(3).map((x) => LureType.fromCode(x.key).label).join(', ');
  }

  String _topDepth(FishSpecies s) {
    final w = s.biteProfile.depthWeights;
    if (_uniform(w.values)) return 'любая';
    final best = w.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return switch (best) {
      DepthZone.shallow => 'мелководье',
      DepthZone.mid => 'средняя',
      DepthZone.dropOff => 'свал',
      DepthZone.pit => 'яма',
    };
  }

  String _topTime(FishSpecies s) {
    final w = s.biteProfile.timeWeights;
    if (_uniform(w.values)) return 'в любое';
    final best = w.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return switch (best) {
      TimeOfDay.morning => 'утро',
      TimeOfDay.day => 'день',
      TimeOfDay.evening => 'вечер',
      TimeOfDay.night => 'ночь',
    };
  }

  bool _uniform(Iterable<double> values) {
    if (values.isEmpty) return true;
    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    return (hi - lo) < 0.001;
  }
}

Color rarityColorOf(Rarity r) => switch (r) {
      Rarity.common => const Color(0xFF9AA4AD),
      Rarity.uncommon => const Color(0xFF5FB85F),
      Rarity.rare => const Color(0xFF4E9CF5),
      Rarity.trophy => kGold,
      Rarity.legendary => const Color(0xFFB266FF),
    };

/// Сила свечения рамки по редкости: (alpha, blur). Обычная — без свечения,
/// дальше — ярче (нечастая → легендарная), как в дизайне карточек.
(double, double) rarityGlow(Rarity r) => switch (r) {
      Rarity.common => (0.0, 0.0),
      Rarity.uncommon => (0.22, 16.0),
      Rarity.rare => (0.34, 18.0),
      Rarity.trophy => (0.5, 22.0),
      Rarity.legendary => (0.62, 26.0),
    };

String rarityLabelOf(Rarity r) => switch (r) {
      Rarity.common => 'Обычная',
      Rarity.uncommon => 'Нечастая',
      Rarity.rare => 'Редкая',
      Rarity.trophy => 'Трофей',
      Rarity.legendary => 'Легендарная',
    };

String habitatLabel(Habitat h) => switch (h) {
      Habitat.fresh => 'пресная',
      Habitat.salt => 'солёная',
      Habitat.brackish => 'солоноватая',
    };

/// Топ-N рекомендованных приманок вида (по весам профиля поклёвки).
String topLuresLabel(FishSpecies s, int n) {
  final e = s.biteProfile.lureTypeWeights.entries
      .where((x) => x.value > 0)
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (e.isEmpty) return 'любые';
  return e.take(n).map((x) => LureType.fromCode(x.key).label).join(' · ');
}

/// Лучшая глубина вида (или «любая», если профиль ровный).
String topDepthLabel(FishSpecies s) {
  final w = s.biteProfile.depthWeights;
  if (_biteUniform(w.values)) return 'любая';
  final best = w.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  return switch (best) {
    DepthZone.shallow => 'мелко',
    DepthZone.mid => 'средняя',
    DepthZone.dropOff => 'свал',
    DepthZone.pit => 'яма',
  };
}

bool _biteUniform(Iterable<double> values) {
  if (values.isEmpty) return true;
  final lo = values.reduce((a, b) => a < b ? a : b);
  final hi = values.reduce((a, b) => a > b ? a : b);
  return (hi - lo) < 0.001;
}
