// lib/features/auth/auth_controller.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'auth_state.dart';

class AuthController extends ChangeNotifier {
  final AuthService _service;

  AuthState _state = const AuthState();
  AuthState get state => _state;

  AuthController({AuthService? service}) : _service = service ?? AuthService.I;

  // Solo organizamos las claves en constantes (no cambia la lógica)
  static const _kHasSession = 'has_session';
  static const _kSessionEmail = 'session_email';

  void _setState(AuthState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> requestOtp(String email) async {
    _setState(state.copyWith(isLoading: true, errorMessage: null));

    try {
      await _service.requestOtp(email);

      _setState(
        state.copyWith(
          isLoading: false,
          step: AuthStep.enterCode,
          email: email,
        ),
      );
    } catch (e) {
      _setState(
        state.copyWith(
          isLoading: false,
          errorMessage: 'No se pudo enviar el código. Intenta de nuevo.',
        ),
      );
    }
  }

  Future<void> verifyOtp(String code) async {
    if (state.email == null) {
      _setState(
        state.copyWith(
          errorMessage: 'No hay correo asociado. Vuelve a solicitar el código.',
        ),
      );
      return;
    }

    _setState(state.copyWith(isLoading: true, errorMessage: null));

    try {
      // Backend: valida código y genera token
      await _service.verifyOtp(email: state.email!, code: code);

      // Guardamos sesión local para modo offline-first
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kHasSession, true);
      await prefs.setString(_kSessionEmail, state.email!);

      // Marcamos estado autenticado
      _setState(state.copyWith(isLoading: false, step: AuthStep.authenticated));
    } catch (e) {
      _setState(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Código incorrecto o expirado. Intenta nuevamente.',
        ),
      );
    }
  }
}
