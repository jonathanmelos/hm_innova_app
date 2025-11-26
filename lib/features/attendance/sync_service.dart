// lib/features/attendance/sync_service.dart

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../../core/network/api_client.dart';
import '../../core/device/device_service.dart';
import 'data/work_session_dao.dart';

class SyncService {
  SyncService._();

  // 👇 IMPORTANTE: misma base URL que usas en HomePage
  // Si en algún momento cambias el dominio/puerto, recuerda actualizarlo aquí
  // o bien podríamos leerlo de ApiConfig.baseUrl.
  static const String _apiBaseUrl = 'http://192.168.0.100:8000';

  /// Sincroniza:
  /// - Sesiones cerradas
  /// - Fotos de inicio asociadas a esas sesiones (si existen)
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

    // ⚠️ IMPORTANTE:
    // Si no hay token (usuario no logueado todavía, o cerró sesión),
    // NO intentamos sincronizar nada para evitar 401 del backend.
    if (token == null || token.isEmpty) {
      // ignore: avoid_print
      print('SyncService: no hay token guardado, se omite la sincronización.');
      return;
    }

    // ------------------------------------------------------------------
    // 6. Enviar SESIONES a /api/work-sessions/sync
    //    y luego las FOTOS de inicio de esas sesiones (si existen)
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

      // 6.1 Primero sincronizamos las jornadas (JSON)
      await ApiClient.I.post(
        '/api/work-sessions/sync',
        bearerToken: token,
        body: payloadSessions,
      );

      // 6.2 Luego, para cada sesión, subimos las fotos de inicio si existen
      for (final row in unsyncedSessions) {
        final localId = row['id'] as int;

        final selfiePath = row['selfie_start'] as String?;
        final photoPath = row['photo_start'] as String?;

        bool mediaOk = true;

        // Solo intentamos subir si hay ambas fotos (selfie + contexto)
        if (selfiePath != null && photoPath != null) {
          mediaOk = await _uploadStartMediaForSession(
            localSessionId: localId,
            deviceUuid: deviceUuid, // 👈 NECESARIO PARA session_key
            selfiePath: selfiePath,
            sitePath: photoPath,
            token: token,
          );
        }

        // Solo si todo fue bien (sesión + fotos) marcamos como sincronizada.
        // Si las fotos fallan, dejamos synced=0 para reintentar en el próximo sync.
        if (mediaOk) {
          await dao.markSessionAsSynced(localId);
        } else {
          // ignore: avoid_print
          print(
            'SyncService: sesión $localId NO se marcó como synced porque falló la subida de fotos.',
          );
        }
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

  /// Sube las fotos de inicio (selfie + contexto) de una sesión concreta.
  /// Devuelve true si todo fue bien (status 200/201), false si hubo error.
  static Future<bool> _uploadStartMediaForSession({
    required int localSessionId,
    required String deviceUuid, // 👈 NECESARIO PARA construir session_key
    required String selfiePath,
    required String sitePath,
    required String? token,
  }) async {
    try {
      final uri = Uri.parse('$_apiBaseUrl/api/jornada/iniciar');

      final request = http.MultipartRequest('POST', uri);
      request.headers['Accept'] = 'application/json';

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // ⚠️ IMPORTANTE:
      // Usamos el MISMO patrón que en /api/work-sessions/sync:
      // device_session_uuid = "${deviceUuid}_$localSessionId"
      // Aquí lo llamamos session_key y el backend lo valida contra
      // work_sessions.device_session_uuid (ver JornadaFotosController).
      final sessionKey = '${deviceUuid}_$localSessionId';
      request.fields['session_key'] = sessionKey;

      request.files.add(
        await http.MultipartFile.fromPath('selfie_inicio', selfiePath),
      );
      request.files.add(
        await http.MultipartFile.fromPath('foto_contexto', sitePath),
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }

      // ignore: avoid_print
      print(
        'SyncService: fallo al subir fotos de sesion $localSessionId. '
        'Status: ${response.statusCode}. Body: ${response.body}',
      );
      return false;
    } catch (e) {
      // ignore: avoid_print
      print(
        'SyncService: excepción al subir fotos de sesión $localSessionId: $e',
      );
      return false;
    }
  }
}
