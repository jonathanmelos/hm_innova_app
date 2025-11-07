import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/work_session_dao.dart';
import 'attendance_state.dart';

class AttendanceController extends ChangeNotifier {
  AttendanceState _state = AttendanceState.initial();
  AttendanceState get state => _state;

  final Stopwatch _stopwatch = Stopwatch(); // sólo para RUNNING
  Timer? _ticker;

  final WorkSessionDao _dao = WorkSessionDao();
  int? _sessionId;
  int? _activePauseId;

  int _cachedPausedSeconds = 0; // pausas acumuladas cerradas

  /// Exponer el id de sesión actual (o null si no hay)
  int? get currentSessionId => _sessionId;

  void _emit(AttendanceState s) {
    _state = s;
    notifyListeners();
  }

  // ----- Init / restore -----
  Future<void> init() async {
    // Restaura solo si hay sesión ACTIVA (running o paused).
    final active = await _dao.getActive();
    if (active != null) {
      _sessionId = active.id;

      // ¿pausa activa?
      final pause = await _dao.getActivePause(_sessionId!);
      final pausedTotal = await _dao.getTotalPausedSeconds(_sessionId!);
      _cachedPausedSeconds = pausedTotal;

      final startAt = active.startAt;
      if (pause != null) {
        // En pausa: no avanza el cronómetro
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
        // En running
        _startTicker(startAt);
        return;
      }
    }

    // Si NO hay sesión activa: arrancar en Idle (pantalla en 0).
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

  /// Inicia la jornada SIN fotos (flujo actual).
  Future<void> start() async {
    // Evita duplicados "running" colgados en DB
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
  }

  /// 🆕 Inicia la jornada pasando opcionalmente la selfie y/o foto de contexto.
  /// Úsalo cuando ya capturaste las imágenes antes de crear la sesión.
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
      // actualiza pausas acumuladas
      _cachedPausedSeconds = await _dao.getTotalPausedSeconds(_sessionId!);
      _activePauseId = null;
    }
    _startTicker(_state.startAt!);
  }

  /// Finaliza la jornada (sin registrar fotos finales).
  Future<void> stop() async {
    if (_sessionId == null) return;
    _ticker?.cancel();

    // Si está pausado, cerramos la pausa activa primero
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

    _emit(_state.copyWith(
      status: SessionStatus.stopped,
      endAt: DateTime.now(),
      elapsed: Duration(seconds: total < 0 ? 0 : total),
    ));

    _sessionId = null;
  }

  /// 🆕 Finaliza la jornada registrando selfie y/o foto de contexto finales.
  Future<void> stopWithMedia({
    String? selfieEnd,
    String? photoEnd,
  }) async {
    if (_sessionId == null) return;
    _ticker?.cancel();

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

    _emit(_state.copyWith(
      status: SessionStatus.stopped,
      endAt: DateTime.now(),
      elapsed: Duration(seconds: total < 0 ? 0 : total),
    ));

    _sessionId = null;
  }

  Future<void> resetToIdle() async {
    _ticker?.cancel();

    // Si hay una sesión activa en memoria, elimínala de la DB (y sus pausas/QR).
    if (_sessionId != null) {
      await _dao.cancelSession(_sessionId!);
    } else {
      // Por si hubiera quedado alguna "running" sin cache local.
      await _dao.cancelActiveIfAny();
    }

    _sessionId = null;
    _activePauseId = null;
    _cachedPausedSeconds = 0;
    _emit(AttendanceState.initial());
  }

  // ----- Media (selfies / fotos de obra) -----
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
    super.dispose();
  }
}
