// lib/core/network/api_client.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'endpoints.dart';

class ApiClient {
  // 🔐 Singleton
  factory ApiClient() => I;

  ApiClient._internal();

  static final ApiClient I = ApiClient._internal();

  final http.Client _client = http.Client();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _tokenKey = 'auth_token';

  // ========== TOKENS ==========
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }

  Uri _buildUri(String path) {
    final base = ApiConfig.baseUrl;
    if (path.startsWith('http')) {
      return Uri.parse(path);
    }
    return Uri.parse('$base$path');
  }

  // ========== MÉTODOS ANTIGUOS QUE USAN headers ==========

  Future<http.Response> getAuth(
    String path, {
    Map<String, String>? headers,
  }) async {
    final token = await getToken();
    final uri = _buildUri(path);
    final mergedHeaders = <String, String>{
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      if (headers != null) ...headers,
    };

    final resp = await _client.get(uri, headers: mergedHeaders);
    _logResponse('GET_AUTH', uri, resp);
    return resp;
  }

  Future<http.Response> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path);
    final mergedHeaders = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (headers != null) ...headers,
    };

    final resp = await _client.post(
      uri,
      headers: mergedHeaders,
      body: body != null ? jsonEncode(body) : null,
    );
    _logResponse('POST_JSON', uri, resp);
    return resp;
  }

  // ========== NUEVOS SIMPLIFICADOS CON bearerToken + headers ==========

  Future<Map<String, dynamic>> get(
    String path, {
    String? bearerToken,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path);
    final mergedHeaders = <String, String>{
      'Accept': 'application/json',
      if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
      if (headers != null) ...headers,
    };

    final resp = await _client.get(uri, headers: mergedHeaders);
    _logResponse('GET', uri, resp);
    return decodeOrThrow(resp);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    String? bearerToken,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path);
    final mergedHeaders = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
      if (headers != null) ...headers,
    };

    final resp = await _client.post(
      uri,
      headers: mergedHeaders,
      body: body != null ? jsonEncode(body) : null,
    );
    _logResponse('POST', uri, resp);
    return decodeOrThrow(resp);
  }

  // 🔹 NUEVO: PUT JSON CON OPCIONAL bearerToken (para /tecnico/profile)
  Future<Map<String, dynamic>> put(
    String path, {
    String? bearerToken,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path);
    final mergedHeaders = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
      if (headers != null) ...headers,
    };

    final resp = await _client.put(
      uri,
      headers: mergedHeaders,
      body: body != null ? jsonEncode(body) : null,
    );
    _logResponse('PUT', uri, resp);
    return decodeOrThrow(resp);
  }

  /// ========== POST JSON CON AUTENTICACIÓN (estilo antiguo) ==========
  ///
  /// Firma compatible con lo que te marca el error en `sync_repository.dart`:
  /// ```dart
  /// final resp = await _apiClient.postJsonAuth('/sync', body: payload);
  /// ```
  Future<http.Response> postJsonAuth(
    String path, {
    Map<String, dynamic>? body,
    String? bearerToken,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path);
    final token = bearerToken ?? await getToken();
    final mergedHeaders = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      if (headers != null) ...headers,
    };

    final resp = await _client.post(
      uri,
      headers: mergedHeaders,
      body: body != null ? jsonEncode(body) : null,
    );
    _logResponse('POST_JSON_AUTH', uri, resp);
    return resp;
  }

  // ========== UTILIDAD PARA VER RESPUESTAS Y ERRORES ==========

  void _logResponse(String method, Uri uri, http.Response resp) {
    if (!kDebugMode) return;
    debugPrint(
      '[$method] ${uri.toString()} => ${resp.statusCode} ${resp.reasonPhrase}',
    );
    if (resp.body.isNotEmpty) {
      debugPrint(resp.body);
    }
  }

  Map<String, dynamic> decodeOrThrow(http.Response resp) {
    final decoded = resp.body.isNotEmpty
        ? jsonDecode(resp.body) as Map<String, dynamic>
        : <String, dynamic>{};

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final msg =
          decoded['message']?.toString() ??
          'Error HTTP ${resp.statusCode}: ${resp.reasonPhrase}';
      throw Exception(msg);
    }

    return decoded;
  }
}
