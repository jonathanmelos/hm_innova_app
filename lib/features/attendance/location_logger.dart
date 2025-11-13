import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../attendance/data/work_session_dao.dart';

/// Servicio para registrar la ubicación cada cierto intervalo
/// mientras la app está activa (no en segundo plano).
class LocationLogger {
  final WorkSessionDao _dao;
  Timer? _timer;

  LocationLogger(this._dao);

  Future<bool> ensurePermissions({bool background = false}) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    if (background && permission != LocationPermission.always) {
      await Geolocator.openAppSettings();
      await Geolocator.openLocationSettings();
    }
    return true;
  }

  Future<void> logOnce(int sessionId) async {
    try {
      // ignore: deprecated_member_use
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        // ignore: deprecated_member_use
        timeLimit: const Duration(seconds: 15),
      );

      await _dao.insertLocationLog(
        sessionId: sessionId,
        lat: pos.latitude,
        lon: pos.longitude,
        accuracy: pos.accuracy,
        at: DateTime.now(),
      );

      // ignore: avoid_print
      print(
        '[GPS] ${DateTime.now()} -> ${pos.latitude}, ${pos.longitude} (±${pos.accuracy}m)',
      );
    } on TimeoutException {
      // ignore: avoid_print
      print('[GPS] Timeout obteniendo ubicación');
    } catch (e) {
      // ignore: avoid_print
      print('[GPS] Error al obtener ubicación: $e');
    }
  }

  void startForegroundLoop(int sessionId) {
    _timer?.cancel();
    unawaited(logOnce(sessionId)); // primera lectura inmediata
    _timer = Timer.periodic(const Duration(minutes: 60), (_) {
      unawaited(logOnce(sessionId));
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
