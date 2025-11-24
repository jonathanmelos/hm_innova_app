import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/network/api_client.dart';
import '../../core/device/device_service.dart';
import 'data/work_session_dao.dart';

class SyncService {
  SyncService._();

  /// Sincroniza:
  /// - Sesiones cerradas
  /// - Ubicaciones pendientes
  /// - Pausas pendientes
  /// - Escaneos QR pendientes
  static Future<void> syncIfConnected() async {
    // 1. Verificar conectividad
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      throw Exception('Sin conexión a internet');
    }

    final dao = WorkSessionDao();

    // 2. Cargar pendientes
    final unsyncedSessions = await dao.getUnsyncedSessions();
    final unsyncedLocations = await dao.getUnsyncedLocations();
    final unsyncedPauses = await dao.getUnsyncedPauses();
    final unsyncedQrScans = await dao.getUnsyncedQrScans();

    // 3. Si no hay nada, salir
    if (unsyncedSessions.isEmpty &&
        unsyncedLocations.isEmpty &&
        unsyncedPauses.isEmpty &&
        unsyncedQrScans.isEmpty) {
      return;
    }

    // 4. Identificador del dispositivo
    final deviceUuid = await DeviceService().getDeviceUuid();

    // 5. Token Laravel Sanctum
    final token = await ApiClient.I.getToken();

    // ------------------------------------------------------------------
    // 6. Enviar SESIONES a /api/work-sessions/sync
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

      // Sessions → synced = 1
      for (final row in unsyncedSessions) {
        final localId = row['id'] as int;
        await dao.markSessionAsSynced(localId);
      }
    }

    // ------------------------------------------------------------------
    // 7. Enviar UBICACIONES a /api/work-session-locations/sync
    // ------------------------------------------------------------------
    if (unsyncedLocations.isNotEmpty) {
      final Map<String, dynamic> payloadLocations = {};

      for (var i = 0; i < unsyncedLocations.length; i++) {
        final row = unsyncedLocations[i];
        final sessionId = row['session_id'] as int;
        final atMs = row['at'] as int;

        payloadLocations['$i'] = {
          'device_session_uuid': '${deviceUuid}_$sessionId',
          'recorded_at': DateTime.fromMillisecondsSinceEpoch(
            atMs,
          ).toIso8601String(),
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

      // Marcar ubicaciones por sesión
      final sessionIds = unsyncedLocations
          .map((e) => e['session_id'] as int)
          .toSet()
          .toList();

      for (final sid in sessionIds) {
        await dao.markLocationsAsSynced(sid);
      }
    }

    // ------------------------------------------------------------------
    // 8. Enviar PAUSAS a /api/work-session-pauses/sync
    // ------------------------------------------------------------------
    if (unsyncedPauses.isNotEmpty) {
      final Map<String, dynamic> payloadPauses = {};

      for (var i = 0; i < unsyncedPauses.length; i++) {
        final row = unsyncedPauses[i];

        final localId = row['id'] as int;
        final sessionId = row['session_id'] as int;
        final startMs = row['start_at'] as int;
        final endMs = row['end_at'] as int?;

        payloadPauses['$i'] = {
          'local_id': localId,
          'device_session_uuid': '${deviceUuid}_$sessionId',
          'start_at': DateTime.fromMillisecondsSinceEpoch(
            startMs,
          ).toIso8601String(),
          'end_at': endMs != null
              ? DateTime.fromMillisecondsSinceEpoch(endMs).toIso8601String()
              : null,
        };
      }

      await ApiClient.I.post(
        '/api/work-session-pauses/sync',
        bearerToken: token,
        body: payloadPauses,
      );

      // Marcar pausas como sincronizadas
      final pauseIds = unsyncedPauses
          .map((e) => e['id'] as int)
          .toList(growable: false);

      await dao.markPausesAsSynced(pauseIds);
    }

    // ------------------------------------------------------------------
    // 9. Enviar QR SCANS a /api/work-session-scans/sync
    // ------------------------------------------------------------------
    if (unsyncedQrScans.isNotEmpty) {
      final Map<String, dynamic> payloadScans = {};

      for (var i = 0; i < unsyncedQrScans.length; i++) {
        final row = unsyncedQrScans[i];

        final localId = row['id'] as int;
        final sessionId = row['session_id'] as int;
        final scannedMs = row['scanned_at'] as int;

        payloadScans['$i'] = {
          'local_id': localId,
          'device_session_uuid': '${deviceUuid}_$sessionId',
          'project_code': row['project_code'],
          'area': row['area'],
          'description': row['description'],
          'scanned_at': DateTime.fromMillisecondsSinceEpoch(
            scannedMs,
          ).toIso8601String(),
        };
      }

      await ApiClient.I.post(
        '/api/work-session-scans/sync',
        bearerToken: token,
        body: payloadScans,
      );

      // Marcar QR como sincronizados
      final scanIds = unsyncedQrScans
          .map((e) => e['id'] as int)
          .toList(growable: false);

      await dao.markQrScansAsSynced(scanIds);
    }
  }
}
