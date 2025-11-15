// lib/features/auth/data/technician_profile_service.dart

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../domain/technician_profile.dart';
import '../../auth/auth_service.dart'; // corrección de path

class TechnicianProfileService {
  TechnicianProfileService(this._apiClient);

  final ApiClient _apiClient;

  static const _cachedProfileKey = 'cached_technician_profile';

  Future<TechnicianProfile> fetchProfile() async {
    final tokenMap = await AuthService.I.fetchMe();
    final token = tokenMap?['token'];
    if (token == null) {
      throw Exception('No hay token de sesión. Vuelve a iniciar sesión.');
    }

    final json = await _apiClient.get(
      ApiEndpoints.tecnicoProfile,
      headers: {'Authorization': 'Bearer $token'},
    );

    final tecnicoJson = json['tecnico'] ?? json;
    final profile = TechnicianProfile.fromJson(
      Map<String, dynamic>.from(tecnicoJson as Map),
    );

    await _cacheProfile(profile);
    return profile;
  }

  Future<TechnicianProfile> updateProfile(TechnicianProfile profile) async {
    final tokenMap = await AuthService.I.fetchMe();
    final token = tokenMap?['token'];
    if (token == null) {
      throw Exception('No hay token de sesión. Vuelve a iniciar sesión.');
    }

    final body = profile.toJson();

    final json = await _apiClient.post(
      ApiEndpoints.tecnicoProfile,
      body: body,
      headers: {'Authorization': 'Bearer $token'},
    );

    final tecnicoJson = json['tecnico'] ?? json;
    final updated = TechnicianProfile.fromJson(
      Map<String, dynamic>.from(tecnicoJson as Map),
    );

    await _cacheProfile(updated);
    return updated;
  }

  Future<void> _cacheProfile(TechnicianProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedProfileKey, profile.nombres ?? '');
  }
}
