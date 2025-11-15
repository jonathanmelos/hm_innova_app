// lib/features/auth/auth_controller.dart

import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'auth_state.dart';

class AuthController extends ChangeNotifier {
  final AuthService _service;

  AuthState _state = const AuthState();
  AuthState get state => _state;

  AuthController({AuthService? service})
      : _service = service ?? AuthService.I;

  void _setState(AuthState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> requestOtp(String email) async {
    _setState(state.copyWith(
      isLoading: true,
      errorMessage: null,
    ));

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
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> verifyOtp(String code) async {
    if (state.email == null) {
      _setState(state.copyWith(
        errorMessage: 'No hay correo asociado. Vuelve a solicitar el código.',
      ));
      return;
    }

    _setState(state.copyWith(
      isLoading: true,
      errorMessage: null,
    ));

    try {
      await _service.verifyOtp(
        email: state.email!,
        code: code,
      );

      _setState(
        state.copyWith(
          isLoading: false,
          step: AuthStep.authenticated,
        ),
      );
    } catch (e) {
      _setState(
        state.copyWith(
          isLoading: false,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
