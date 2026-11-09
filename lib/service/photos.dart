import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Guarda as fotos recebidas na conversa numa pasta privada do app.
/// Cada foto tem um id; o arquivo fica em <pasta do app>/fotos/<id>.jpg.
class PhotoStore {
  PhotoStore._();

  static String? _basePath;

  /// Chamada uma vez no início do app (main.dart).
  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final fotos = Directory('${dir.path}/fotos');
    if (!fotos.existsSync()) fotos.createSync(recursive: true);
    _basePath = fotos.path;
  }

  /// Caminho esperado do arquivo (null se a pasta ainda não está pronta).
  static String? pathFor(String photoId) {
    final base = _basePath;
    if (base == null) return null;
    return '$base/$photoId.jpg';
  }

  static bool exists(String photoId) {
    final path = pathFor(photoId);
    if (path == null) return false;
    return File(path).existsSync();
  }

  static Future<String> save(String photoId, List<int> bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final fotos = Directory('${dir.path}/fotos');
    if (!fotos.existsSync()) fotos.createSync(recursive: true);
    _basePath ??= fotos.path;
    final path = pathFor(photoId) ?? '${fotos.path}/$photoId.jpg';
    final file = File(path);
    if (!file.existsSync()) {
      await file.writeAsBytes(bytes, flush: true);
    }
    return path;
  }
}
