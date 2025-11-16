import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/network/api_client.dart';
import '../../core/device/device_service.dart';
import 'data/work_session_dao.dart';

class SyncService {
  SyncService._();

  /// Sincroniza sesiones cerradas (end_at != null) si hay conexión.
  static Future<void> syncIfConnected() async {
    // 1. Verificar conectividad antes de intentar sincronizar
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      throw Exception('Sin conexión a internet');
    }

    final dao = WorkSessionDao();
    final unsynced = await dao.getUnsyncedSessions();

    // 2. Si no hay sesiones pendientes, no hacemos nada
    if (unsynced.isEmpty) {
      return;
    }

    // 3. Identificador lógico del dispositivo
    final deviceUuid = await DeviceService().getDeviceUuid();

    // 4. Token de autenticación para la API Laravel (Sanctum)
    final token = await ApiClient.I.getToken();

    // 5. Construimos el payload para Laravel con clave "0", "1", "2"...
    final Map<String, dynamic> payload = {};

    for (var i = 0; i < unsynced.length; i++) {
      final row = unsynced[i];
      final localId = row['id'] as int;
      final startMs = row['start_at'] as int;
      final endMs = row['end_at'] as int?;

      final startedAt = DateTime.fromMillisecondsSinceEpoch(
        startMs,
      ).toIso8601String();

      final endedAt = endMs != null
          ? DateTime.fromMillisecondsSinceEpoch(endMs).toIso8601String()
          : null;

      payload['$i'] = {
        'device_session_uuid': '${deviceUuid}_$localId',
        'device_uuid': deviceUuid,
        'started_at': startedAt,
        'ended_at': endedAt,
        'duration_seconds': (row['total_seconds'] as int?) ?? 0,
        // Geolocalización futura
        'start_lat': null,
        'start_lng': null,
        'end_lat': null,
        'end_lng': null,
      };
    }

    // 6. Enviamos todo al backend — AHORA CORRECTAMENTE CON /api/
    await ApiClient.I.post(
      '/api/work-sessions/sync', // 👈 también con /api
      bearerToken: token,
      body: payload,
    );

    // 7. Si llegó aquí sin lanzar excepción, marcamos todo como sincronizado.
    for (final row in unsynced) {
      final localId = row['id'] as int;
      await dao.markSessionAsSynced(localId);
      await dao.markLocationsAsSynced(localId);
    }
  }
}
