// lib/features/attendance/bg_location_task.dart
import 'dart:async';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/work_session_dao.dart';
import '../../core/db/app_database.dart';
import 'sync_service.dart';

/// Tarea en segundo plano: guarda ubicación periódicamente y,
/// cada 30 minutos (si hay internet), intenta sincronizar con el servidor.
class BgLocationTask extends TaskHandler {
  late WorkSessionDao _dao;

  // Clave de preferencias para el último sync ejecutado
  static const _kLastSyncMs = 'last_sync_ms';
  // Ventana mínima entre sincronizaciones
  static const _syncInterval = Duration(minutes: 30);

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    _dao = WorkSessionDao();
    // ignore: avoid_print
    print('[BG] start @ $timestamp');
  }

  @override
  Future<void> onEvent(DateTime timestamp, SendPort? sendPort) async {
    // ignore: avoid_print
    print('[BG] event @ $timestamp');

    // 1) Registrar ubicación si hay sesión activa
    try {
      // Verifica servicio y permisos antes de pedir la ubicación
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // ignore: avoid_print
        print('[BG] location service disabled → skip');
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        // ignore: avoid_print
        print('[BG] location permission denied → skip');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 20),
      );

      // ¿Hay sesión activa?
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
        print('[BG] no active session → skip location');
      }
    } on TimeoutException {
      // ignore: avoid_print
      print('[BG] getCurrentPosition timeout');
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('[BG] platform error: $e');
    } catch (e) {
      // ignore: avoid_print
      print('[BG] error: $e');
    }

    // 2) Intentar sincronización cada 30 min si hay internet
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final last = prefs.getInt(_kLastSyncMs) ?? 0;

      if (now - last >= _syncInterval.inMilliseconds) {
        // ignore: avoid_print
        print('[SYNC] Intentando sincronizar…');
        await SyncService.syncIfConnected(); // hace el check de conectividad adentro
        await prefs.setInt(_kLastSyncMs, now);
      }
    } catch (e) {
      // ignore: avoid_print
      print('[SYNC] error al intentar sincronizar en BG: $e');
    }
  }

  // Algunos dispositivos llaman onRepeatEvent en lugar de onEvent
  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    await onEvent(timestamp, sendPort);
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    // ignore: avoid_print
    print('[BG] destroy @ $timestamp');
  }

  @override
  void onButtonPressed(String id) {
    // Puedes mapear acciones si agregas más botones a la notificación
    // ignore: avoid_print
    print('[BG] notif button pressed: $id');
  }

  @override
  void onNotificationPressed() {
    // Abre la app al tocar la notificación
    FlutterForegroundTask.launchApp();
  }
}
