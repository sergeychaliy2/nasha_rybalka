import 'dart:io';

import 'package:flutter/material.dart';

/// Пользовательские картинки контента (загружаются в админке, читаются игрой).
///
/// Файлы лежат рядом с сейвом в AppData — папка общая у игры и админки,
/// поэтому загруженное в админке игра видит сразу (файл читается на отрисовке).
/// Ключи: `fish_<speciesId>`, `item_<gearId>`, `<stem фона локации>`.
String contentImagesDir() {
  final appData = Platform.environment['APPDATA'] ?? '.';
  return '$appData\\com.nasharybalka\\nasha_rybalka\\content_images';
}

File contentImageFile(String key) => File('${contentImagesDir()}\\$key.png');

bool hasContentImage(String key) => contentImageFile(key).existsSync();

/// Имя файла без пути и .png — ключ картинки для фонов локаций.
String assetStem(String assetPath) {
  final s = assetPath.split('/').last;
  return s.endsWith('.png') ? s.substring(0, s.length - 4) : s;
}

/// Картинка контента: файл-оверрайд из админки → бандл-ассет → [fallback].
Widget contentImage(
  String key,
  String asset, {
  BoxFit fit = BoxFit.cover,
  Alignment alignment = Alignment.center,
  Widget Function(BuildContext)? fallback,
}) {
  Widget fb(BuildContext c) =>
      fallback?.call(c) ?? const ColoredBox(color: Color(0xFF10161D));
  final f = contentImageFile(key);
  if (f.existsSync()) {
    return Image.file(
      f,
      fit: fit,
      alignment: alignment,
      errorBuilder: (c, _, _) => fb(c),
    );
  }
  if (asset.isEmpty) return Builder(builder: fb);
  return Image.asset(
    asset,
    fit: fit,
    alignment: alignment,
    errorBuilder: (c, _, _) => fb(c),
  );
}
