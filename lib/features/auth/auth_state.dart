// lib/features/auth/auth_state.dart

enum AuthStep {
  enterEmail,
  enterCode,
  authenticated,
}

class AuthState {
  final AuthStep step;
  final bool isLoading;
  final String? email;
  final String? errorMessage;

  const AuthState({
    this.step = AuthStep.enterEmail,
    this.isLoading = false,
    this.email,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStep? step,
    bool? isLoading,
    String? email,
    String? errorMessage,
  }) {
    return AuthState(
      step: step ?? this.step,
      isLoading: isLoading ?? this.isLoading,
      email: email ?? this.email,
      errorMessage: errorMessage,
    );
  }
}
