// lib/features/sync/sync_repository.dart

import 'package:http/http.dart' as http;

import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';

class SyncRepository {
  final ApiClient _client;

  SyncRepository({ApiClient? client}) : _client = client ?? ApiClient.I;

  /// Envía al backend las sesiones de trabajo pendientes.
  /// [sessions] debería ser una lista de mapas ya preparada para la API.
  Future<void> syncWorkSessions(List<Map<String, dynamic>> sessions) async {
    if (sessions.isEmpty) return;

    final http.Response resp = await _client.postJsonAuth(
      ApiEndpoints.workSessionsSync,
      body: {'sessions': sessions},
    );

    _client.decodeOrThrow(resp);
  }

  /// Obtiene el historial de sesiones desde el backend (opcional)
  Future<List<dynamic>> fetchRemoteSessions() async {
    final resp = await _client.getAuth(ApiEndpoints.workSessions);
    final data = _client.decodeOrThrow(resp);

    return (data['data'] ?? data['sessions'] ?? []) as List<dynamic>;
  }
}
