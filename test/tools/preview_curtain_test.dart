// Превью кадров «занавеса-заброса» в PNG для глазного контроля.
// Запуск (PowerShell): $env:PREVIEW_CURTAIN='1'; flutter test test/tools/preview_curtain_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nasha_rybalka/features/shell/ui_kit.dart';

void main() {
  final enabled = Platform.environment['PREVIEW_CURTAIN'] == '1';
  test('кадры занавеса', () async {
    const size = Size(700, 1000);
    Directory('build/curtain').createSync(recursive: true);
    for (final t in [0.25, 0.45, 0.55, 0.72, 0.85]) {
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      paintHookCatchPreview(canvas, size, t, 'Ладожское озеро');
      final img = await rec
          .endRecording()
          .toImage(size.width.toInt(), size.height.toInt());
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('build/curtain/curtain_${(t * 100).toInt()}.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    }
    // ignore: avoid_print
    print('curtain frames written to build/curtain/');
  }, skip: enabled ? false : 'PREVIEW_CURTAIN=1');
}
