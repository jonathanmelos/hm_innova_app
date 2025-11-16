// lib/features/auth/data/technician_profile_service.dart

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../domain/technician_profile.dart';

class TechnicianProfileService {
  TechnicianProfileService(this._apiClient);

  final ApiClient _apiClient;

  static const _cachedProfileKey = 'cached_technician_profile';

  /// 🔹 Obtiene el perfil del técnico usando el token guardado en el dispositivo.
  /// - Si no hay token → lanza "No hay token de sesión..."
  /// - Si hay token pero no hay internet → lanzará error de red (que tu página
  ///   ya maneja mostrando el perfil cacheado si existe).
  Future<TechnicianProfile> fetchProfile() async {
    // 👉 Usamos el token guardado en FlutterSecureStorage
    final token = await _apiClient.getToken();
    if (token == null) {
      throw Exception('No hay token de sesión. Vuelve a iniciar sesión.');
    }

    final json = await _apiClient.get(
      ApiEndpoints.tecnicoProfile,
      bearerToken: token,
    );

    final tecnicoJson = json['tecnico'] ?? json;
    final profile = TechnicianProfile.fromJson(
      Map<String, dynamic>.from(tecnicoJson as Map),
    );

    await _cacheProfile(profile);
    return profile;
  }

  /// 🔹 Actualiza el perfil del técnico.
  /// Usa el mismo token almacenado localmente.
  Future<TechnicianProfile> updateProfile(TechnicianProfile profile) async {
    final token = await _apiClient.getToken();
    if (token == null) {
      throw Exception('No hay token de sesión. Vuelve a iniciar sesión.');
    }

    final body = profile.toJson();

    final json = await _apiClient.post(
      ApiEndpoints.tecnicoProfile,
      bearerToken: token,
      body: body,
    );

    final tecnicoJson = json['tecnico'] ?? json;
    final updated = TechnicianProfile.fromJson(
      Map<String, dynamic>.from(tecnicoJson as Map),
    );

    await _cacheProfile(updated);
    return updated;
  }

  /// 🔹 Cache interno (lo estás manejando mejor en `TechnicianProfilePage`,
  /// pero dejo esto por compatibilidad mínima).
  Future<void> _cacheProfile(TechnicianProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedProfileKey, profile.nombres ?? '');
  }
}
