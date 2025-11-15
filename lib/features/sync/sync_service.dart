// lib/features/sync/sync_service.dart

import 'sync_repository.dart';

class SyncService {
  SyncService._internal();

  static final SyncService I = SyncService._internal();

  final SyncRepository _repo = SyncRepository();

  /// Aquí luego conectaremos con tu DB local (sqflite) para:
  /// - Leer sesiones pendientes
  /// - Enviarlas al backend
  /// - Marcarlas como sincronizadas
  Future<void> syncPendingSessions() async {
    // TODO: leer desde tu tabla local work_sessions
    // Ejemplo provisional (lista vacía):
    final pending = <Map<String, dynamic>>[];

    if (pending.isEmpty) return;

    await _repo.syncWorkSessions(pending);

    // TODO: marcar en DB local como sincronizadas
  }
}
