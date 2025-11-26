// lib/features/attendance/sync_triggers.dart

import 'sync_service.dart';

/// Pequeña capa para centralizar los puntos donde queremos
/// intentar sincronizar. Así tu código en otras pantallas
/// queda más legible: SyncTriggers.onWorkSessionFinished(), etc.
class SyncTriggers {
  /// Llamada desde el botón de "Sincronizar ahora" (manual).
  static Future<void> onManualSyncRequest() {
    return SyncService.syncIfConnected();
  }

  /// Llamar cuando el usuario finaliza una jornada de trabajo.
  static Future<void> onWorkSessionFinished() {
    return SyncService.syncIfConnected();
  }

  /// Llamar cuando se termina de registrar una pausa.
  static Future<void> onPauseFinished() {
    return SyncService.syncIfConnected();
  }

  /// Llamar cuando se registra un escaneo QR nuevo.
  static Future<void> onQrScanRegistered() {
    return SyncService.syncIfConnected();
  }

  /// Llamar cuando la app vuelve del background (si quieres).
  static Future<void> onAppResumed() {
    return SyncService.syncIfConnected();
  }
}
