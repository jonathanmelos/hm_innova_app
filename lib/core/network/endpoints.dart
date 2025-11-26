// lib/core/network/endpoints.dart

class ApiConfig {
  /// ================== MODOS DE CONEXIÓN ==================
  ///
  /// EMULADOR ANDROID (corriendo Laravel en tu PC)
  /// Descomenta esta línea SOLO si usas emulador:
  // static const String baseUrl = 'http://10.0.2.2:8000';
  ///
  /// DISPOSITIVO FÍSICO contra LARAVEL LOCAL (misma red WiFi)
  /// Descomenta esta línea cuando pruebas contra XAMPP/Artisan:
  static const String baseUrl = 'http://192.168.0.100:8000';

  ///
  /// PRODUCCIÓN (SERVIDOR EN INTERNET)
  /// Deja esta línea activa cuando trabajes contra el servidor real:
  /// static const String baseUrl = 'https://soporte.hminnova.com';

  ///
  /// =======================================================
}

class ApiEndpoints {
  // ---------- AUTH ----------
  static const String otpRequest = '/api/auth/otp-request';
  static const String otpVerify = '/api/auth/verify';
  static const String me = '/api/me';

  // ---------- PERFIL DEL TÉCNICO ----------
  static const String tecnicoProfile = '/api/tecnico/profile';

  // ---------- SINCRONIZACIÓN ----------
  static const String workSessionsSync = '/api/work-sessions/sync';
  static const String workSessions = '/api/work-sessions';

  static const String workSessionLocationsSync =
      '/api/work-session-locations/sync';

  static const String workSessionPausesSync = '/api/work-session-pauses/sync';

  static const String workSessionScansSync = '/api/work-session-scans/sync';
}
