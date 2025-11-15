// lib/core/network/endpoints.dart

class ApiConfig {
  /// ⚠️ IMPORTANTE SOBRE LA URL BASE:
  ///
  /// ➤ Emulador Android:
  ///    http://10.0.2.2:8000
  ///
  /// ➤ Dispositivo físico (TU CASO AHORA – pruebas locales):
  ///    Usa la IP de tu PC en la red:
  ///    http://192.168.0.112:8000
  ///
  /// ➤ Para PRODUCCIÓN (cuando esté en tu servidor web real):
  ///    Ejemplo:
  ///    https://api.hminnova.com
  ///
  /// *** DURANTE PRUEBAS EN TU TELÉFONO ***
  /// Deja esto así ↓↓↓
  static const String baseUrl = 'http://192.168.0.112:8000';
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
}
