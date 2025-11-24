import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../core/notifications/notification_service.dart';
import '../data/work_session_dao.dart';
import 'attendance_state.dart';

// 🔽 NUEVO: imports para ubicación y servicio en segundo plano
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import '../bg_location_task.dart'; // handler del servicio BG
import '../location_logger.dart'; // logger de ubicación en foreground

class AttendanceController extends ChangeNotifier {
  AttendanceState _state = AttendanceState.initial();
  AttendanceState get state => _state;

  Timer? _ticker;
  Timer? _autoStopTimer;

  final WorkSessionDao _dao = WorkSessionDao();
  final NotificationService _notis = NotificationService.instance;

  // 🔽 NUEVO: logger de ubicación (app abierta)
  late final LocationLogger _loc = LocationLogger(_dao);

  int? _sessionId;
  int? _activePauseId;

  int _cachedPausedSeconds = 0; // pausas acumuladas cerradas

  int? get currentSessionId => _sessionId;

  // 🔹 TODO: reemplazar por ID real del técnico (cuando Auth esté listo)
  int _currentUserId = 1;

  void _emit(AttendanceState s) {
    _state = s;
    notifyListeners();
  }

  // ================== Política de cortes ==================
  DateTime _fivePmOf(DateTime d) => DateTime(d.year, d.month, d.day, 17, 0, 0);
  DateTime _fiveThirtyOf(DateTime d) =>
      DateTime(d.year, d.month, d.day, 17, 30, 0);

  bool _isEveningStart(DateTime startAt) =>
      startAt.isAfter(_fivePmOf(startAt)) ||
      startAt.isAtSameMomentAs(_fivePmOf(startAt));

  /// Regla:
  /// - Si empieza < 17:00 → corte a 17:30 del mismo día
  /// - Si empieza >= 17:00 → corte a startAt + 8 horas (sin corte a 17:30)
  DateTime _policyCutoff(DateTime startAt) {
    if (_isEveningStart(startAt)) {
      return startAt.add(const Duration(hours: 8));
    }
    return _fiveThirtyOf(startAt);
  }
  // ========================================================

  Future<void> _scheduleAutoStop(DateTime startAt) async {
    _autoStopTimer?.cancel();

    final cutoff = _policyCutoff(startAt);
    final now = DateTime.now();

    // Si ya pasó el corte aplicable, cerrar retroactivamente
    if (now.isAfter(cutoff) || now.isAtSameMomentAs(cutoff)) {
      await _autoStopAt(cutoff);
      return;
    }

    final dur = cutoff.difference(now);
    _autoStopTimer = Timer(dur, () => _autoStopAt(cutoff));
  }

  /// 🔹 NUEVO: registra una ubicación puntual asociada al evento
  Future<void> _logLocationEvent(String eventType) async {
    if (_sessionId == null) return;

    try {
      // Si ya tienes permisos, Geolocator no pedirá nada extra
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await _dao.insertLocationLog(
        sessionId: _sessionId!,
        userId: _currentUserId,
        lat: position.latitude,
        lon: position.longitude,
        accuracy: position.accuracy,
        at: DateTime.now(),
        eventType: eventType,
      );
    } catch (_) {
      // No queremos romper el flujo si la ubicación falla
    }
  }

  Future<void> _autoStopAt(DateTime cutoff) async {
    if (_sessionId == null) return;

    // Cierra pausa abierta si existiera
    if (_activePauseId != null) {
      await _dao.endPause(_activePauseId!, cutoff);
      _cachedPausedSeconds = await _dao.getTotalPausedSeconds(_sessionId!);
      _activePauseId = null;
    }

    _ticker?.cancel();

    final startAt = _state.startAt!;
    final paused = _cachedPausedSeconds;
    int total = cutoff.difference(startAt).inSeconds - paused;
    if (total < 0) total = 0;

    await _dao.finishSession(id: _sessionId!, end: cutoff, totalSeconds: total);

    // 🔹 Registrar ubicación de auto-cierre
    await _logLocationEvent('auto_stop');

    // 🔔 Notificaciones: cerrar “jornada activa” y reprogramar las de la mañana
    try {
      await _notis.cancelOngoingActive();
      await _notis.cancelWorkdayPlan();
      await _notis.scheduleMorningPlan(); // 07:30 y 07:55 diarias
    } catch (_) {}

    // 🛰️ detener servicios de ubicación
    try {
      _loc.stop();
      await FlutterForegroundTask.stopService();
    } catch (_) {}

    _emit(
      _state.copyWith(
        status: SessionStatus.stopped,
        endAt: cutoff,
        elapsed: Duration(seconds: total),
      ),
    );

    _sessionId = null;
    _autoStopTimer?.cancel();
  }

  // ----- Init / restore -----
  Future<void> init() async {
    final active = await _dao.getActive();
    if (active != null) {
      _sessionId = active.id;

      final startAt = active.startAt;
      final cutoff = _policyCutoff(startAt);
      final now = DateTime.now();

      // Si al restaurar ya pasó el corte aplicable, cerrar retroactivamente
      if (now.isAfter(cutoff) || now.isAtSameMomentAs(cutoff)) {
        await _autoStopAt(cutoff);
        return;
      }

      final pause = await _dao.getActivePause(_sessionId!);
      final pausedTotal = await _dao.getTotalPausedSeconds(_sessionId!);
      _cachedPausedSeconds = pausedTotal;

      // Programa autocierre según política
      await _scheduleAutoStop(startAt);

      // 🔔 Notificaciones al restaurar: mostrar persistente y plan del día (si aplica)
      try {
        await _notis.showOngoingActive();
        await _notis.cancelMorningPlan(); // ya estamos en jornada
        await _notis
            .scheduleWorkdayPlan(); // 13:00, 14:00, 16:45, 17:00, 17:15, 17:25
      } catch (_) {}

      // 🛰️ reanudar registro de ubicación (FG y BG)
      try {
        if (_sessionId != null && await _loc.ensurePermissions()) {
          _loc.startForegroundLoop(_sessionId!);
        }
        await FlutterForegroundTask.startService(
          notificationTitle: 'Jornada activa',
          notificationText: 'Registrando ubicación cada hora',
          callback: attendanceStartCallback,
        );
      } catch (_) {}

      if (pause != null) {
        _activePauseId = pause['id'] as int;
        final elapsed = now.difference(startAt).inSeconds - pausedTotal;
        _emit(
          _state.copyWith(
            status: SessionStatus.paused,
            startAt: startAt,
            elapsed: Duration(seconds: elapsed < 0 ? 0 : elapsed),
            endAt: null,
          ),
        );
        return;
      } else {
        _startTicker(startAt);
        return;
      }
    }

    _emit(AttendanceState.initial());
  }

  void _startTicker(DateTime startAt) {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
      final now = DateTime.now();
      final cutoff = _policyCutoff(startAt);

      // Si alcanzamos el corte aplicable, cerrar de inmediato
      if (now.isAfter(cutoff) || now.isAtSameMomentAs(cutoff)) {
        await _autoStopAt(cutoff);
        return;
      }

      final paused = _cachedPausedSeconds + await _currentOpenPauseSeconds();
      final secs = now.difference(startAt).inSeconds - paused;

      _emit(
        _state.copyWith(
          status: SessionStatus.running,
          startAt: startAt,
          elapsed: Duration(seconds: secs < 0 ? 0 : secs),
          endAt: null,
        ),
      );
    });

    _emit(_state.copyWith(status: SessionStatus.running, startAt: startAt));
  }

  Future<int> _currentOpenPauseSeconds() async {
    if (_sessionId == null) return 0;
    final ap = await _dao.getActivePause(_sessionId!);
    if (ap == null) return 0;

    final start = DateTime.fromMillisecondsSinceEpoch(ap['start_at'] as int);
    return DateTime.now().difference(start).inSeconds;
  }

  // ====== Actions ======

  /// Inicia la jornada SIN fotos.
  Future<void> start() async {
    await _dao.cancelActiveIfAny();

    if (_state.status == SessionStatus.running ||
        _state.status == SessionStatus.paused) {
      return;
    }

    final now = DateTime.now();
    _sessionId = await _dao.insertRunning(now);
    _activePauseId = null;
    _cachedPausedSeconds = 0;
    _startTicker(now);

    // ⏲️ Autocierre y 🔔 notificaciones
    await _scheduleAutoStop(now);
    try {
      await _notis.showOngoingActive();
      await _notis.cancelMorningPlan();
      await _notis.scheduleWorkdayPlan();
    } catch (_) {}

    // 🔹 Ubicación de inicio
    await _logLocationEvent('start');

    // 🛰️ ubicación FG + BG
    try {
      if (_sessionId != null && await _loc.ensurePermissions()) {
        _loc.startForegroundLoop(_sessionId!); // app abierta
      }
      await FlutterForegroundTask.startService(
        notificationTitle: 'Jornada activa',
        notificationText: 'Registrando ubicación cada hora',
        callback: attendanceStartCallback, // servicio en segundo plano
      );
    } catch (_) {}
  }

  /// Inicia la jornada con media opcional ya capturada.
  Future<void> startWithMedia({String? selfieStart, String? photoStart}) async {
    await _dao.cancelActiveIfAny();

    if (_state.status == SessionStatus.running ||
        _state.status == SessionStatus.paused) {
      return;
    }

    final now = DateTime.now();
    _sessionId = await _dao.insertRunning(
      now,
      selfieStart: selfieStart,
      photoStart: photoStart,
    );
    _activePauseId = null;
    _cachedPausedSeconds = 0;
    _startTicker(now);

    // ⏲️ Autocierre y 🔔 notificaciones
    await _scheduleAutoStop(now);
    try {
      await _notis.showOngoingActive();
      await _notis.cancelMorningPlan();
      await _notis.scheduleWorkdayPlan();
    } catch (_) {}

    // 🔹 Ubicación de inicio
    await _logLocationEvent('start');

    // 🛰️ ubicación FG + BG
    try {
      if (_sessionId != null && await _loc.ensurePermissions()) {
        _loc.startForegroundLoop(_sessionId!);
      }
      await FlutterForegroundTask.startService(
        notificationTitle: 'Jornada activa',
        notificationText: 'Registrando ubicación cada hora',
        callback: attendanceStartCallback,
      );
    } catch (_) {}
  }

  Future<void> pause() async {
    if (_sessionId == null || _state.status != SessionStatus.running) return;
    final now = DateTime.now();
    _activePauseId = await _dao.startPause(_sessionId!, now);
    _ticker?.cancel();
    final elapsed = _state.elapsed;
    _emit(_state.copyWith(status: SessionStatus.paused, elapsed: elapsed));

    // 🔹 Ubicación al pausar
    await _logLocationEvent('pause');

    // 🛰️ detener ubicación mientras está en pausa
    try {
      _loc.stop();
      await FlutterForegroundTask.stopService();
    } catch (_) {}
  }

  Future<void> resume() async {
    if (_sessionId == null || _state.status != SessionStatus.paused) return;
    final now = DateTime.now();
    if (_activePauseId != null) {
      await _dao.endPause(_activePauseId!, now);
      _cachedPausedSeconds = await _dao.getTotalPausedSeconds(_sessionId!);
      _activePauseId = null;
    }
    _startTicker(_state.startAt!);

    // 🔹 Ubicación al reanudar
    await _logLocationEvent('resume');

    // 🛰️ reanudar ubicación FG + BG
    try {
      if (_sessionId != null && await _loc.ensurePermissions()) {
        _loc.startForegroundLoop(_sessionId!);
      }
      await FlutterForegroundTask.startService(
        notificationTitle: 'Jornada activa',
        notificationText: 'Registrando ubicación cada hora',
        callback: attendanceStartCallback,
      );
    } catch (_) {}
  }

  /// Finaliza la jornada (sin fotos finales).
  Future<void> stop() async {
    if (_sessionId == null) return;
    _ticker?.cancel();
    _autoStopTimer?.cancel();

    final now = DateTime.now();

    if (_activePauseId != null) {
      await _dao.endPause(_activePauseId!, now);
      _cachedPausedSeconds = await _dao.getTotalPausedSeconds(_sessionId!);
      _activePauseId = null;
    }

    final startAt = _state.startAt!;
    final paused = _cachedPausedSeconds;
    final total = now.difference(startAt).inSeconds - paused;

    await _dao.finishSession(
      id: _sessionId!,
      end: now,
      totalSeconds: total < 0 ? 0 : total,
    );

    // 🔹 Ubicación de cierre
    await _logLocationEvent('stop');

    // 🔔 Notificaciones tras cierre
    try {
      await _notis.cancelOngoingActive();
      await _notis.cancelWorkdayPlan();
      await _notis.scheduleMorningPlan();
    } catch (_) {}

    // 🛰️ detener ubicación
    try {
      _loc.stop();
      await FlutterForegroundTask.stopService();
    } catch (_) {}

    _emit(
      _state.copyWith(
        status: SessionStatus.stopped,
        endAt: now,
        elapsed: Duration(seconds: total < 0 ? 0 : total),
      ),
    );

    _sessionId = null;
  }

  /// Finaliza la jornada registrando selfie y/o foto finales.
  Future<void> stopWithMedia({String? selfieEnd, String? photoEnd}) async {
    if (_sessionId == null) return;
    _ticker?.cancel();
    _autoStopTimer?.cancel();

    final now = DateTime.now();

    if (_activePauseId != null) {
      await _dao.endPause(_activePauseId!, now);
      _cachedPausedSeconds = await _dao.getTotalPausedSeconds(_sessionId!);
      _activePauseId = null;
    }

    final startAt = _state.startAt!;
    final paused = _cachedPausedSeconds;
    final total = now.difference(startAt).inSeconds - paused;

    await _dao.finishSession(
      id: _sessionId!,
      end: now,
      totalSeconds: total < 0 ? 0 : total,
      selfieEnd: selfieEnd,
      photoEnd: photoEnd,
    );

    // 🔹 Ubicación de cierre
    await _logLocationEvent('stop');

    // 🔔 Notificaciones tras cierre
    try {
      await _notis.cancelOngoingActive();
      await _notis.cancelWorkdayPlan();
      await _notis.scheduleMorningPlan();
    } catch (_) {}

    // 🛰️ detener ubicación
    try {
      _loc.stop();
      await FlutterForegroundTask.stopService();
    } catch (_) {}

    _emit(
      _state.copyWith(
        status: SessionStatus.stopped,
        endAt: now,
        elapsed: Duration(seconds: total < 0 ? 0 : total),
      ),
    );

    _sessionId = null;
  }

  Future<void> resetToIdle() async {
    _ticker?.cancel();
    _autoStopTimer?.cancel();

    if (_sessionId != null) {
      await _dao.cancelSession(_sessionId!);
    } else {
      await _dao.cancelActiveIfAny();
    }

    // 🔔 Limpiar notificaciones de jornada y dejar las de la mañana activas
    try {
      await _notis.cancelOngoingActive();
      await _notis.cancelWorkdayPlan();
      await _notis.scheduleMorningPlan();
    } catch (_) {}

    // 🛰️ detener ubicación
    try {
      _loc.stop();
      await FlutterForegroundTask.stopService();
    } catch (_) {}

    _sessionId = null;
    _activePauseId = null;
    _cachedPausedSeconds = 0;
    _emit(AttendanceState.initial());
  }

  // ----- Media -----
  Future<void> setSelfieStart(String filePath) async {
    if (_sessionId == null) return;
    await _dao.setSelfieStart(_sessionId!, filePath);
  }

  Future<void> setSelfieEnd(String filePath) async {
    if (_sessionId == null) return;
    await _dao.setSelfieEnd(_sessionId!, filePath);
  }

  Future<void> setPhotoStart(String filePath) async {
    if (_sessionId == null) return;
    await _dao.setPhotoStart(_sessionId!, filePath);
  }

  Future<void> setPhotoEnd(String filePath) async {
    if (_sessionId == null) return;
    await _dao.setPhotoEnd(_sessionId!, filePath);
  }

  // ----- QR -----
  Future<void> logQrScan({
    String? projectCode,
    String? area,
    String? description,
    DateTime? when,
  }) async {
    if (_sessionId == null) return;
    await _dao.insertQrScan(
      sessionId: _sessionId!,
      projectCode: projectCode,
      area: area,
      description: description,
      scannedAt: when,
    );
  }

  // ----- Debug -----
  Future<void> debugPrintDb() => _dao.debugPrintAll();

  @override
  void dispose() {
    _ticker?.cancel();
    _autoStopTimer?.cancel();

    // 🛰️ asegurar stop de ubicación al destruir controlador
    try {
      _loc.stop();
      FlutterForegroundTask.stopService();
    } catch (_) {}

    super.dispose();
  }
}

// 🔽 callback de entrada para el Foreground Service (en este archivo)
@pragma('vm:entry-point')
void attendanceStartCallback() {
  FlutterForegroundTask.setTaskHandler(BgLocationTask());
}
