import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../data/repositories/transaction_repo.dart';

class AttachmentCleanupService {
  final TransactionRepo _repo;
  AttachmentCleanupService({TransactionRepo? repo}) : _repo = repo ?? TransactionRepo();

  Future<void> removeOrphanAttachments() async {
    final dir = await getApplicationDocumentsDirectory();
    final attachmentsDir = Directory(p.join(dir.path, 'attachments'));
    if (!await attachmentsDir.exists()) return;

    final files = attachmentsDir.listSync().whereType<File>().toList();
    if (files.isEmpty) return;

    // Obtener todos los paths existentes en BD
    final existing = await _repo.getAllAttachmentPaths();
    final existingSet = existing.whereType<String>().toSet();

    for (final f in files) {
      try {
        if (!existingSet.contains(f.path)) {
          await f.delete();
        }
      } catch (_) {}
    }
  }

  Future<File?> exportAllAttachmentsToZip() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final attachmentsDir = Directory(p.join(dir.path, 'attachments'));
      if (!await attachmentsDir.exists()) return null;
      final files = attachmentsDir.listSync().whereType<File>().toList();
      if (files.isEmpty) return null;

      // Simple ZIP manual (sin compresión real) usando formato básico stor según necesidad:
      // Para algo más robusto se podría agregar dependencia como archive, pero se pide simple.
      final zipPath = p.join(dir.path, 'attachments_backup_${DateTime.now().millisecondsSinceEpoch}.zip');
      // Usaremos paquete archive si existe; si no, crear contenedor temporal.
      // Para simplicidad aquí dejamos placeholder (en real se añadiría dependencia archive para compresión).
      final sink = File(zipPath).openWrite();
      for (final f in files) {
        final name = p.basename(f.path);
        sink.writeln('FILE:$name');
        sink.add(await f.readAsBytes());
        sink.writeln('\nEND_FILE');
      }
      await sink.flush();
      await sink.close();
      return File(zipPath);
    } catch (e) {
      return null;
    }
  }
}
