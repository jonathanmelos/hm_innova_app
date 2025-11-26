import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'sync_service.dart';

class ConnectivityWatcher {
  static StreamSubscription? _sub;
  static bool _initialized = false;

  static void start() {
    if (_initialized) return;
    _initialized = true;

    // En tu versión, onConnectivityChanged devuelve List<ConnectivityResult>
    _sub = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> resultList,
    ) async {
      // Si la lista NO contiene "none", entonces hay conexión
      final hasConnection = resultList.any((r) => r != ConnectivityResult.none);

      if (hasConnection) {
        try {
          await SyncService.syncIfConnected();
        } catch (e) {
          print(
            'ConnectivityWatcher: error al sincronizar automáticamente: $e',
          );
        }
      }
    });
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _initialized = false;
  }
}
