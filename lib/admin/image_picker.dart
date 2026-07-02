import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../shared/content_images.dart';

const _gold = Color(0xFFE4B857);
const _panel = Color(0xFF161C23);

/// Пикер картинки контента в админке: превью того, что видит игрок
/// (файл-оверрайд → бандл-ассет → векторный фолбэк) + «Загрузить…»/«Удалить».
/// Файл кладётся в общую папку `content_images` — игра читает её напрямую.
class AdminImagePicker extends StatefulWidget {
  const AdminImagePicker({
    super.key,
    required this.imageKey,
    required this.asset,
    this.label = 'Изображение',
    this.width = 150,
    this.height = 110,
    this.fallback,
  });

  /// Ключ файла (`fish_<id>` / `item_<id>` / stem фона локации).
  final String imageKey;

  /// Бандл-ассет, который используется, пока нет загруженного файла.
  final String asset;
  final String label;
  final double width;
  final double height;
  final Widget Function(BuildContext)? fallback;

  @override
  State<AdminImagePicker> createState() => _AdminImagePickerState();
}

class _AdminImagePickerState extends State<AdminImagePicker> {
  bool get _hasOverride => hasContentImage(widget.imageKey);

  Future<void> _pick() async {
    const group = XTypeGroup(
      label: 'Изображения',
      extensions: ['png', 'jpg', 'jpeg', 'webp'],
    );
    final file = await openFile(acceptedTypeGroups: const [group]);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final target = contentImageFile(widget.imageKey);
    target.parent.createSync(recursive: true);
    target.writeAsBytesSync(bytes);
    await FileImage(target).evict();
    if (mounted) {
      setState(() {});
      _toast('Загружено: ${file.name}');
    }
  }

  Future<void> _delete() async {
    final f = contentImageFile(widget.imageKey);
    if (f.existsSync()) {
      await FileImage(f).evict();
      f.deleteSync();
    }
    if (mounted) {
      setState(() {});
      _toast('Своя картинка удалена — вернулась встроенная');
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
        content: Text(m),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _panel));

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: widget.width,
              height: widget.height,
              child: contentImage(
                widget.imageKey,
                widget.asset,
                fallback: widget.fallback ??
                    (_) => const ColoredBox(
                          color: Color(0xFF0B1016),
                          child: Icon(Icons.image_not_supported_outlined,
                              color: Colors.white24, size: 30),
                        ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(_hasOverride ? 'своя картинка' : 'встроенная',
                  style: TextStyle(
                      color: _hasOverride
                          ? const Color(0xFF56C271)
                          : Colors.white38,
                      fontSize: 11)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.upload, size: 16, color: _gold),
                label: const Text('Загрузить…',
                    style: TextStyle(color: _gold, fontSize: 12)),
              ),
              if (_hasOverride)
                TextButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: Color(0xFFE5726A)),
                  label: const Text('Удалить',
                      style:
                          TextStyle(color: Color(0xFFE5726A), fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
