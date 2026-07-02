import 'dart:io';

import 'package:audioplayers/audioplayers.dart';

/// Пользовательские аудиофайлы (заменяются в админке, читаются игрой).
///
/// Лежат рядом с сейвом в общей папке игры и админки. Ключи: `music` (музыка
/// меню) и ключи эффектов из [Sfx] (`splash`, `bite`, …). Если файла нет —
/// используется встроенный ассет.
const _audioExts = ['wav', 'mp3', 'ogg', 'm4a', 'aac'];

String contentAudioDir() {
  final appData = Platform.environment['APPDATA'] ?? '.';
  return '$appData\\com.nasharybalka\\nasha_rybalka\\content_audio';
}

/// Путь к загруженному аудио для ключа (первое существующее расширение) или null.
String? contentAudioPath(String key) {
  final dir = contentAudioDir();
  for (final e in _audioExts) {
    final f = File('$dir\\$key.$e');
    if (f.existsSync()) return f.path;
  }
  return null;
}

bool hasContentAudio(String key) => contentAudioPath(key) != null;

/// Сохранить загруженный файл под ключ (с его расширением), убрав прочие
/// варианты этого ключа.
void saveContentAudio(String key, String ext, List<int> bytes) {
  deleteContentAudio(key);
  final dir = Directory(contentAudioDir())..createSync(recursive: true);
  File('${dir.path}\\$key.${ext.toLowerCase()}').writeAsBytesSync(bytes);
}

void deleteContentAudio(String key) {
  final dir = contentAudioDir();
  for (final e in _audioExts) {
    final f = File('$dir\\$key.$e');
    if (f.existsSync()) f.deleteSync();
  }
}

/// Источник для audioplayers: свой файл (если загружен) или встроенный ассет.
Source audioSource(String key, String assetFile) {
  final path = contentAudioPath(key);
  if (path != null) return DeviceFileSource(path);
  return AssetSource('audio/$assetFile');
}
