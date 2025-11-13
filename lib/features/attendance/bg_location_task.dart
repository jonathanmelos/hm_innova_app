import 'dart:async';
import 'dart:isolate';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import 'data/work_session_dao.dart';
import '../../core/db/app_database.dart';

/// Tarea en segundo plano: guarda ubicación (lat/lon/accuracy) en cada tick.
class BgLocationTask extends TaskHandler {
  late WorkSessionDao _dao;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    _dao = WorkSessionDao();
    // ignore: avoid_print
    print('[BG] start @ $timestamp');
  }

  /// Algunas versiones del plugin llaman a este método de forma periódica.
  /// Delegamos al mismo cuerpo de `onEvent`.
  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    await onEvent(timestamp, sendPort);
  }

  @override
  Future<void> onEvent(DateTime timestamp, SendPort? sendPort) async {
    // ignore: avoid_print
    print('[BG] event @ $timestamp');

    try {
      // Geolocator 11.x: estos parámetros están deprecados pero válidos todavía.
      // ignore: deprecated_member_use
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        // ignore: deprecated_member_use
        timeLimit: const Duration(seconds: 20),
      );

      // Buscar sesión activa
      final db = await AppDatabase.instance;
      final rows = await db.query(
        'work_sessions',
        where: 'end_at IS NULL',
        limit: 1,
      );

      if (rows.isNotEmpty) {
        final sessionId = rows.first['id'] as int;

        await _dao.insertLocationLog(
          sessionId: sessionId,
          lat: pos.latitude,
          lon: pos.longitude,
          accuracy: pos.accuracy,
          at: DateTime.now(),
        );

        // ignore: avoid_print
        print(
          '[BG] saved ${pos.latitude}, ${pos.longitude} (±${pos.accuracy}m)',
        );
      } else {
        // ignore: avoid_print
        print('[BG] no active session → skip');
      }
    } on TimeoutException {
      // ignore: avoid_print
      print('[BG] getCurrentPosition timeout');
    } catch (e) {
      // ignore: avoid_print
      print('[BG] error: $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    // ignore: avoid_print
    print('[BG] destroy @ $timestamp');
  }

  @override
  void onButtonPressed(String id) {
    // ignore: avoid_print
    print('[BG] notif button pressed: $id');
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }
}
