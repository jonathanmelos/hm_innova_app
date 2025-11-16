// lib/features/auth/auth_repository.dart

import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';

class AuthRepository {
  final ApiClient _client;

  AuthRepository({ApiClient? client}) : _client = client ?? ApiClient.I;

  /// Solicita OTP para un correo
  Future<void> requestOtp(String email) async {
    // Usamos el cliente nuevo que ya decodifica y lanza errores
    await _client.post(ApiEndpoints.otpRequest, body: {'email': email});
  }

  /// Verifica el OTP, guarda token y devuelve el payload completo (user + tecnico)
  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String code,
  }) async {
    // Igual que antes, pero usando _client.post (que ya hace decodeOrThrow)
    final data = await _client.post(
      ApiEndpoints.otpVerify,
      body: {'email': email, 'code': code},
    );

    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      throw Exception('La API no devolvió un token válido');
    }

    // Guardamos el token en storage seguro (FlutterSecureStorage)
    await _client.saveToken(token);

    return data;
  }

  /// Llama a /api/me usando el token actual para validar sesión.
  /// Importante: aquí NO borramos el token ni atrapamos errores,
  /// para que AuthGate pueda manejar el modo offline-first.
  Future<Map<String, dynamic>?> fetchMe() async {
    final token = await _client.getToken();
    if (token == null) return null;

    // Si el servidor responde con error o no hay red,
    // _client.get lanzará una excepción.
    // Esa excepción será capturada en AuthGate y se mantendrá la sesión local.
    final data = await _client.get(ApiEndpoints.me, bearerToken: token);

    return data;
  }

  Future<void> logout() async {
    await _client.clearToken();
  }
}
