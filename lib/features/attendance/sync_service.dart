import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/db/app_database.dart';

class SyncService {
  static const String apiUrl = 'https://TU_BACKEND.com/api/sync-sessions'; // <-- tu endpoint real

  /// Compat: soporta tanto ConnectivityResult único como lista.
  static Future<bool> _hasConnection() async {
    final result = await Connectivity().checkConnectivity();

    // Nuevas versiones: List<ConnectivityResult>
    if (result is List<ConnectivityResult>) {
      return result.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet);
    }
    // Viejas versiones: ConnectivityResult
    return result != ConnectivityResult.none;
  }

  static Future<void> syncIfConnected() async {
    final ok = await _hasConnection();
    if (!ok) {
      debugPrint('[SYNC] Sin conexión, reintento luego.');
      return;
    }

    final db = await AppDatabase.instance;

    // Sesiones no sincronizadas
    final sessions = await db.query(
      'work_sessions',
      where: 'synced = 0 OR synced IS NULL',
    );

    for (final session in sessions) {
      final sessionId = session['id'] as int;

      final locations = await db.query(
        'session_locations',
        where: 'session_id = ? AND (synced = 0 OR synced IS NULL)',
        whereArgs: [sessionId],
        orderBy: 'at ASC',
      );

      final payload = {
        'session': session,
        'locations': locations,
      };

      try {
        final res = await http.post(
          Uri.parse(apiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );

        if (res.statusCode == 200) {
          await db.update(
            'work_sessions',
            {'synced': 1},
            where: 'id = ?',
            whereArgs: [sessionId],
          );
          await db.update(
            'session_locations',
            {'synced': 1},
            where: 'session_id = ? AND (synced = 0 OR synced IS NULL)',
            whereArgs: [sessionId],
          );
          debugPrint('[SYNC] OK sesión #$sessionId');
        } else {
          debugPrint('[SYNC] HTTP ${res.statusCode} sesión #$sessionId');
        }
      } catch (e) {
        debugPrint('[SYNC] Error sesión #$sessionId → $e');
      }
    }
  }
}
