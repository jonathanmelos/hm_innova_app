import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../core/notifications/notification_service.dart';
import '../data/work_session_dao.dart';
import 'attendance_state.dart';

class AttendanceController extends ChangeNotifier {
  AttendanceState _state = AttendanceState.initial();
  AttendanceState get state => _state;

  final Stopwatch _stopwatch = Stopwatch(); // para RUNNING
  Timer? _ticker;

  // ⏱️ Timer de autocierre (17:30 por tu política actual)
  Timer? _autoStopTimer;

  final WorkSessionDao _dao = WorkSessionDao();
  final NotificationService _notis = NotificationService.instance;

  int? _sessionId;
  int? _activePauseId;

  int _cachedPausedSeconds = 0; // pausas acumuladas cerradas

  int? get currentSessionId => _sessionId;

  void _emit(AttendanceState s) {
    _state = s;
    notifyListeners();
  }

  // ================== Autocierre 17:30 ==================
  DateTime _cutoffFor(DateTime startAt) =>
      DateTime(startAt.year, startAt.month, startAt.day, 17, 30, 0);

  Future<void> _scheduleAutoStop(DateTime startAt) async {
    _autoStopTimer?.cancel();
    final cutoff = _cutoffFor(startAt);
    final now = DateTime.now();

    // Si ya pasó la hora de corte, no cerramos (cuenta como horas extra).
    if (now.isAfter(cutoff)) return;

    final dur = cutoff.difference(now);
    _autoStopTimer = Timer(dur, () => _autoStopAt(cutoff));
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

    await _dao.finishSession(
      id: _sessionId!,
      end: cutoff,
      totalSeconds: total,
    );

    // 🔔 Notificaciones: cerrar “jornada activa” y reprogramar las de la mañana
    try {
      await _notis.cancelOngoingActive();
      await _notis.cancelWorkdayPlan();
      await _notis.scheduleMorningPlan(); // 07:30 y 07:55 diarias
    } catch (_) {}

    _emit(_state.copyWith(
      status: SessionStatus.stopped,
      endAt: cutoff,
      elapsed: Duration(seconds: total),
    ));

    _sessionId = null;
    _autoStopTimer?.cancel();
  }
  // ======================================================

  // ----- Init / restore -----
  Future<void> init() async {
    final active = await _dao.getActive();
    if (active != null) {
      _sessionId = active.id;

      final pause = await _dao.getActivePause(_sessionId!);
      final pausedTotal = await _dao.getTotalPausedSeconds(_sessionId!);
      _cachedPausedSeconds = pausedTotal;

      final startAt = active.startAt;

      // Programa autocierre solo si no pasó la hora
      await _scheduleAutoStop(startAt);

      // 🔔 Notificaciones al restaurar: mostrar persistente y plan del día (si aplica)
      try {
        await _notis.showOngoingActive();
        await _notis.cancelMorningPlan(); // ya estamos en jornada
        await _notis
            .scheduleWorkdayPlan(); // 13:00, 14:00, 16:45, 17:00, 17:15, 17:25
      } catch (_) {}

      if (pause != null) {
        _activePauseId = pause['id'] as int;
        final elapsed =
            DateTime.now().difference(startAt).inSeconds - pausedTotal;
        _emit(_state.copyWith(
          status: SessionStatus.paused,
          startAt: startAt,
          elapsed: Duration(seconds: elapsed < 0 ? 0 : elapsed),
          endAt: null,
        ));
        return;
      } else {
        _startTicker(startAt);
        return;
      }
    }

    _emit(AttendanceState.initial());
  }

  void _startTicker(DateTime startAt) {
    _stopwatch
      ..reset()
      ..start();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
      final paused = _cachedPausedSeconds + await _currentOpenPauseSeconds();
      final secs = DateTime.now().difference(startAt).inSeconds - paused;
      _emit(_state.copyWith(
        status: SessionStatus.running,
        startAt: startAt,
        elapsed: Duration(seconds: secs < 0 ? 0 : secs),
        endAt: null,
      ));
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
  }

  /// Inicia la jornada con media opcional ya capturada.
  Future<void> startWithMedia({
    String? selfieStart,
    String? photoStart,
  }) async {
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
  }

  Future<void> pause() async {
    if (_sessionId == null || _state.status != SessionStatus.running) return;
    final now = DateTime.now();
    _activePauseId = await _dao.startPause(_sessionId!, now);
    _ticker?.cancel();
    final elapsed = _state.elapsed;
    _emit(_state.copyWith(status: SessionStatus.paused, elapsed: elapsed));
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
  }

  /// Finaliza la jornada (sin fotos finales).
  Future<void> stop() async {
    if (_sessionId == null) return;
    _ticker?.cancel();
    _autoStopTimer?.cancel();

    if (_activePauseId != null) {
      await _dao.endPause(_activePauseId!, DateTime.now());
      _cachedPausedSeconds = await _dao.getTotalPausedSeconds(_sessionId!);
      _activePauseId = null;
    }

    final startAt = _state.startAt!;
    final paused = _cachedPausedSeconds;
    final total = DateTime.now().difference(startAt).inSeconds - paused;
    await _dao.finishSession(
      id: _sessionId!,
      end: DateTime.now(),
      totalSeconds: total < 0 ? 0 : total,
    );

    // 🔔 Notificaciones tras cierre
    try {
      await _notis.cancelOngoingActive();
      await _notis.cancelWorkdayPlan();
      await _notis.scheduleMorningPlan();
    } catch (_) {}

    _emit(_state.copyWith(
      status: SessionStatus.stopped,
      endAt: DateTime.now(),
      elapsed: Duration(seconds: total < 0 ? 0 : total),
    ));

    _sessionId = null;
  }

  /// Finaliza la jornada registrando selfie y/o foto finales.
  Future<void> stopWithMedia({
    String? selfieEnd,
    String? photoEnd,
  }) async {
    if (_sessionId == null) return;
    _ticker?.cancel();
    _autoStopTimer?.cancel();

    if (_activePauseId != null) {
      await _dao.endPause(_activePauseId!, DateTime.now());
      _cachedPausedSeconds = await _dao.getTotalPausedSeconds(_sessionId!);
      _activePauseId = null;
    }

    final startAt = _state.startAt!;
    final paused = _cachedPausedSeconds;
    final total = DateTime.now().difference(startAt).inSeconds - paused;

    await _dao.finishSession(
      id: _sessionId!,
      end: DateTime.now(),
      totalSeconds: total < 0 ? 0 : total,
      selfieEnd: selfieEnd,
      photoEnd: photoEnd,
    );

    // 🔔 Notificaciones tras cierre
    try {
      await _notis.cancelOngoingActive();
      await _notis.cancelWorkdayPlan();
      await _notis.scheduleMorningPlan();
    } catch (_) {}

    _emit(_state.copyWith(
      status: SessionStatus.stopped,
      endAt: DateTime.now(),
      elapsed: Duration(seconds: total < 0 ? 0 : total),
    ));

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
    super.dispose();
  }
}
