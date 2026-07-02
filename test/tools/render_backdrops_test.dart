// Генератор фонов локаций: рендерит BackdropPainter в PNG-файлы ассетов.
// Запуск (PowerShell):
//   $env:RENDER_BACKDROPS='1'; flutter test test/tools/render_backdrops_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nasha_rybalka/shared/rendering/backdrop_painter.dart';

void main() {
  final enabled = Platform.environment['RENDER_BACKDROPS'] == '1';

  test('рендер фонов локаций в assets/locations', () async {
    const size = Size(1600, 900);
    for (final e in kRuBackdropSpecs.entries) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      BackdropPainter(e.value).paint(canvas, size);
      final image = await recorder
          .endRecording()
          .toImage(size.width.toInt(), size.height.toInt());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('assets/locations/${e.key}.png');
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
      // ignore: avoid_print
      print('rendered ${file.path} (${bytes.lengthInBytes ~/ 1024} KB)');
    }
  }, skip: enabled ? false : 'только по флагу RENDER_BACKDROPS=1');
}
