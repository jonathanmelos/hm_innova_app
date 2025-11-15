// lib/features/auth/auth_service.dart

import 'auth_repository.dart';

class AuthService {
  AuthService._internal();

  static final AuthService I = AuthService._internal();

  final AuthRepository _repo = AuthRepository();

  Future<void> requestOtp(String email) => _repo.requestOtp(email);

  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String code,
  }) =>
      _repo.verifyOtp(email: email, code: code);

  Future<Map<String, dynamic>?> fetchMe() => _repo.fetchMe();

  Future<void> logout() => _repo.logout();
}
