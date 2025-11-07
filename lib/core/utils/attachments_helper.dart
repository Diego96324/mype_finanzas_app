import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class AttachmentsHelper {
  static final ImagePicker _picker = ImagePicker();

  // Directorio base para guardar adjuntos
  static Future<Directory> _getAttachmentsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final attachments = Directory(p.join(dir.path, 'attachments'));
    if (!await attachments.exists()) {
      await attachments.create(recursive: true);
    }
    return attachments;
  }

  /// Abre cámara o galería, comprime y guarda el archivo en attachments/.
  /// Devuelve la ruta absoluta del archivo guardado, o null si se cancela.
  static Future<String?> pickAndSave({required ImageSource source}) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 95, // precompresión del picker
      );
      if (picked == null) return null;

      final bytes = await picked.readAsBytes();
      // Compresión adicional (objetivo: <= 1.5 MB)
      const targetSize = 1500 * 1024; // 1.5MB

      Uint8List out = bytes;
      if (out.length > targetSize) {
        // Primera pasada
        final firstPass = await FlutterImageCompress.compressWithList(
          out,
          minWidth: 1600,
          minHeight: 1600,
          quality: 80,
          format: CompressFormat.jpeg,
        );
        out = Uint8List.fromList(firstPass);

        // Segunda pasada sólo si sigue excediendo el tamaño
        if (out.length > targetSize) {
          final secondPass = await FlutterImageCompress.compressWithList(
            out,
            minWidth: 1280,
            minHeight: 1280,
            quality: 72,
            format: CompressFormat.jpeg,
          );
          out = Uint8List.fromList(secondPass);
        }
      }

      final attachmentsDir = await _getAttachmentsDir();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final filename = 'cb_$ts.jpg';
      final savePath = p.join(attachmentsDir.path, filename);
      final file = File(savePath);
      await file.writeAsBytes(out, flush: true);
      return savePath;
    } catch (e) {
      debugPrint('❌ Error al adjuntar imagen: $e');
      return null;
    }
  }

  /// Elimina un adjunto local si existe
  static Future<bool> deleteAttachment(String? path) async {
    if (path == null || path.isEmpty) return false;
    try {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
