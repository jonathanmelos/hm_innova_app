import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/network/api_client.dart';
import '../../core/device/device_service.dart';
import 'data/work_session_dao.dart';

class SyncService {
  SyncService._();

  /// Sincroniza sesiones cerradas (end_at != null)
  /// y ubicaciones pendientes si hay conexión.
  static Future<void> syncIfConnected() async {
    // 1. Verificar conectividad antes de intentar sincronizar
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      throw Exception('Sin conexión a internet');
    }

    final dao = WorkSessionDao();

    // 2. Traer pendientes (sesiones + ubicaciones)
    final unsyncedSessions = await dao.getUnsyncedSessions();
    final unsyncedLocations = await dao.getUnsyncedLocations();

    // Si no hay nada por enviar, salimos
    if (unsyncedSessions.isEmpty && unsyncedLocations.isEmpty) {
      return;
    }

    // 3. Identificador lógico del dispositivo
    final deviceUuid = await DeviceService().getDeviceUuid();

    // 4. Token de autenticación para la API Laravel (Sanctum)
    final token = await ApiClient.I.getToken();

    // ------------------------------------------------------------------
    // 5. Enviar SESIONES a /api/work-sessions/sync (igual que antes)
    // ------------------------------------------------------------------
    if (unsyncedSessions.isNotEmpty) {
      final Map<String, dynamic> payloadSessions = {};

      for (var i = 0; i < unsyncedSessions.length; i++) {
        final row = unsyncedSessions[i];
        final localId = row['id'] as int;
        final startMs = row['start_at'] as int;
        final endMs = row['end_at'] as int?;

        final startedAt = DateTime.fromMillisecondsSinceEpoch(
          startMs,
        ).toIso8601String();

        final endedAt = endMs != null
            ? DateTime.fromMillisecondsSinceEpoch(endMs).toIso8601String()
            : null;

        payloadSessions['$i'] = {
          'device_session_uuid': '${deviceUuid}_$localId',
          'device_uuid': deviceUuid,
          'started_at': startedAt,
          'ended_at': endedAt,
          'duration_seconds': (row['total_seconds'] as int?) ?? 0,
          // Geolocalización futura (inicio/fin) si algún día la calculas aquí
          'start_lat': null,
          'start_lng': null,
          'end_lat': null,
          'end_lng': null,
        };
      }

      await ApiClient.I.post(
        '/api/work-sessions/sync',
        bearerToken: token,
        body: payloadSessions,
      );

      // Marcar SOLO las sesiones como sincronizadas
      for (final row in unsyncedSessions) {
        final localId = row['id'] as int;
        await dao.markSessionAsSynced(localId);
        // 👇 OJO: ya NO marcamos las ubicaciones aquí
      }
    }

    // ------------------------------------------------------------------
    // 6. Enviar UBICACIONES a /api/work-session-locations/sync
    // ------------------------------------------------------------------
    if (unsyncedLocations.isNotEmpty) {
      final Map<String, dynamic> payloadLocations = {};

      for (var i = 0; i < unsyncedLocations.length; i++) {
        final row = unsyncedLocations[i];
        final localSessionId = row['session_id'] as int;
        final atMs = row['at'] as int;

        payloadLocations['$i'] = {
          // Misma convención que en las sesiones: deviceUuid + '_' + idLocal
          'device_session_uuid': '${deviceUuid}_$localSessionId',
          'recorded_at': DateTime.fromMillisecondsSinceEpoch(atMs)
              .toIso8601String(),
          'lat': row['lat'],
          'lng': row['lon'],
          'accuracy': row['accuracy'],
          'event_type': row['event_type'] ?? 'ping',
        };
      }

      await ApiClient.I.post(
        '/api/work-session-locations/sync',
        bearerToken: token,
        body: payloadLocations,
      );

      // Marcar ubicaciones como sincronizadas agrupando por sesión
      final sessionIds = unsyncedLocations
          .map((e) => e['session_id'] as int)
          .toSet()
          .toList();

      for (final sid in sessionIds) {
        await dao.markLocationsAsSynced(sid);
      }
    }
  }
}
