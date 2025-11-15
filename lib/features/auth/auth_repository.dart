// lib/features/auth/auth_repository.dart

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';

class AuthRepository {
  final ApiClient _client;

  AuthRepository({ApiClient? client}) : _client = client ?? ApiClient.I;

  /// Solicita OTP para un correo
  Future<void> requestOtp(String email) async {
    final http.Response resp = await _client.postJson(
      ApiEndpoints.otpRequest,
      body: {'email': email},
    );

    _client.decodeOrThrow(resp);
  }

  /// Verifica el OTP, guarda token y devuelve el payload completo (user + tecnico)
  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String code,
  }) async {
    final http.Response resp = await _client.postJson(
      ApiEndpoints.otpVerify,
      body: {'email': email, 'code': code},
    );

    final data = _client.decodeOrThrow(resp);

    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      throw Exception('La API no devolvió un token válido');
    }

    // Guardamos el token en storage seguro
    await _client.saveToken(token);

    return data;
  }

  /// Llama a /api/me usando el token actual para validar sesión
  Future<Map<String, dynamic>?> fetchMe() async {
    final token = await _client.getToken();
    if (token == null) return null;

    final resp = await _client.getAuth(ApiEndpoints.me);

    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }

    // si falla, limpiamos token
    await _client.clearToken();
    return null;
  }

  Future<void> logout() async {
    await _client.clearToken();
  }
}
