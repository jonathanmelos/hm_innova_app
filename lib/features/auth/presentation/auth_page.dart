// lib/features/auth/presentation/auth_page.dart

import 'package:flutter/material.dart';

import '../auth_controller.dart';
import '../auth_state.dart';
import '../../attendance/presentation/app.dart'; // HmInnovaApp
import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../auth_service.dart';

/// 🔒 Puerta de entrada:
/// - Revisa si ya hay sesión válida (/api/me)
/// - Si hay, muestra HmInnovaApp
/// - Si no, muestra la pantalla de login OTP
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<bool> _future;

  @override
  void initState() {
    super.initState();
    _future = _checkSession();
  }

  Future<bool> _checkSession() async {
    try {
      // Opcional: aquí puedes ajustar baseUrl si pruebas en físico
      debugPrint('API baseUrl: ${ApiConfig.baseUrl}');
      final me = await AuthService.I.fetchMe();
      return me != null;
    } catch (e) {
      debugPrint('Error en /api/me: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isLoggedIn = snapshot.data ?? false;

        if (isLoggedIn) {
          // Ya hay token válido → directo al módulo de asistencia
          return const HmInnovaApp();
        }

        // No hay sesión → flujo OTP
        return const AuthPage();
      },
    );
  }
}

/// 🧑‍🔧 Pantalla de login OTP para técnicos.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late final AuthController _controller;
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = AuthController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.state;

        // Si ya está autenticado, muestra directamente el módulo de asistencia
        if (state.step == AuthStep.authenticated) {
          return const HmInnovaApp();
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Ingreso técnicos HM INNOVA')),
          body: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildContent(state),
              ),
              if (state.isLoading)
                Container(
                  color: Colors.black.withOpacity(0.2),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(AuthState state) {
    switch (state.step) {
      case AuthStep.enterEmail:
        return _buildEmailStep(state);
      case AuthStep.enterCode:
        return _buildCodeStep(state);
      case AuthStep.authenticated:
        // No se usa porque se intercepta antes, pero el switch lo exige.
        return const SizedBox.shrink();
    }
  }

  Widget _buildEmailStep(AuthState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ingresa tu correo institucional',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('Te enviaremos un código de acceso para ingresar a la app.'),
        const SizedBox(height: 16),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Correo electrónico',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        if (state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              state.errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: state.isLoading ? null : _onRequestOtp,
            child: const Text('Enviar código'),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeStep(AuthState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hemos enviado un código a:\n${state.email}',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Código de acceso',
            hintText: 'Ej: 123456',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        if (state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              state.errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: state.isLoading ? null : _onVerifyOtp,
                child: const Text('Ingresar'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: state.isLoading
              ? null
              : () {
                  // Volver a escribir el correo
                  setState(() {
                    _codeController.clear();
                  });
                  _controller.requestOtp(
                    _controller.state.email ?? '',
                  ); // o reset
                },
          child: const Text('Reenviar código'),
        ),
      ],
    );
  }

  Future<void> _onRequestOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingresa un correo válido')));
      return;
    }

    await _controller.requestOtp(email);
  }

  Future<void> _onVerifyOtp() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el código de acceso')),
      );
      return;
    }

    await _controller.verifyOtp(code);
  }
}
