import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../auth/presentation/auth_page.dart'; // AuthGate
import '../../auth/auth_service.dart';
import '../data/technician_profile_service.dart';
import '../domain/technician_profile.dart';

class TechnicianProfilePage extends StatefulWidget {
  const TechnicianProfilePage({super.key});

  @override
  State<TechnicianProfilePage> createState() => _TechnicianProfilePageState();
}

class _TechnicianProfilePageState extends State<TechnicianProfilePage> {
  final _apiClient = ApiClient();
  late final TechnicianProfileService _service = TechnicianProfileService(
    _apiClient,
  );

  final _cedulaCtrl = TextEditingController();
  final _nombresCtrl = TextEditingController();
  final _apellidosCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _tipoSangreCtrl = TextEditingController();
  final _contactoEmergenciaCtrl = TextEditingController();

  TechnicianProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  static const _cacheKey = 'technician_profile_cache';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ---------------- LOGOUT MANUAL ----------------

  Future<void> _doLogout() async {
    try {
      await AuthService.I.logout();
    } catch (_) {
      // Si falla por red, igual cerramos sesión local
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('has_session');
    await prefs.remove('session_email');
    await prefs.remove(_cacheKey);

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          '¿Seguro que deseas cerrar sesión en este dispositivo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _doLogout();
            },
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }

  // ---------------- CACHE LOCAL PERFIL ----------------

  Future<void> _cacheProfile(TechnicianProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final map = profile.toJson()
      ..addAll({
        'id': profile.id,
        'user_id': profile.userId,
        'perfil_completo': profile.perfilCompleto,
        'estado': profile.estado,
        'foto_perfil': profile.fotoPerfil,
      });

    await prefs.setString(_cacheKey, jsonEncode(map));
  }

  Future<TechnicianProfile?> _getCachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return TechnicianProfile.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  void _applyProfileToForm(TechnicianProfile profile) {
    _profile = profile;
    _cedulaCtrl.text = profile.cedula ?? '';
    _nombresCtrl.text = profile.nombres ?? '';
    _apellidosCtrl.text = profile.apellidos ?? '';
    _telefonoCtrl.text = profile.telefono ?? '';
    _correoCtrl.text = profile.correo ?? '';
    _direccionCtrl.text = profile.direccion ?? '';
    _tipoSangreCtrl.text = profile.tipoSangre ?? '';
    _contactoEmergenciaCtrl.text = profile.contactoEmergencia ?? '';
  }

  // ---------------- CARGA DE PERFIL (ONLINE + OFFLINE) ----------------

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) Intentar pedir al servidor
      final profile = await _service.fetchProfile();
      _applyProfileToForm(profile);
      await _cacheProfile(profile);
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      // 2) Cualquier error (sin token, offline, server caído): usar caché si existe
      final cached = await _getCachedProfile();

      if (cached != null) {
        _applyProfileToForm(cached);

        // Completar correo desde sesión si estuviera vacío
        if ((_correoCtrl.text.isEmpty || _correoCtrl.text.trim().isEmpty)) {
          final prefs = await SharedPreferences.getInstance();
          final email = prefs.getString('session_email');
          if (email != null) {
            _correoCtrl.text = email;
          }
        }

        if (mounted) {
          setState(() {
            _loading = false;
            // Mensaje neutro (solo info). Si no quieres mensaje, pon _error = null;
            _error =
                'Mostrando datos guardados en este dispositivo. Los cambios se sincronizarán cuando haya conexión.';
          });
        }
      } else {
        // 3) No hay caché todavía
        final prefs = await SharedPreferences.getInstance();
        final email = prefs.getString('session_email');
        if (email != null && _correoCtrl.text.trim().isEmpty) {
          _correoCtrl.text = email;
        }

        if (mounted) {
          setState(() {
            _loading = false;
            _error =
                'No se pudo cargar el perfil en este momento. Intenta más tarde.';
          });
        }
      }
    }
  }

  // ---------------- GUARDAR CAMBIOS ----------------

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    // ✅ Base mínima por si _profile es null (primer uso / solo sesión local)
    final base =
        _profile ??
        TechnicianProfile(
          id: 0,
          userId: 0,
          cedula: null,
          nombres: null,
          apellidos: null,
          telefono: null,
          correo: _correoCtrl.text.trim().isNotEmpty
              ? _correoCtrl.text.trim()
              : null,
          direccion: null,
          tipoSangre: null,
          contactoEmergencia: null,
          fotoPerfil: null,
          perfilCompleto: false,
          estado: 'activo',
        );

    final updated = TechnicianProfile(
      id: base.id,
      userId: base.userId,
      cedula: _cedulaCtrl.text.trim(),
      nombres: _nombresCtrl.text.trim(),
      apellidos: _apellidosCtrl.text.trim(),
      telefono: _telefonoCtrl.text.trim(),
      correo: _correoCtrl.text.trim(),
      direccion: _direccionCtrl.text.trim(),
      tipoSangre: _tipoSangreCtrl.text.trim(),
      contactoEmergencia: _contactoEmergenciaCtrl.text.trim(),
      fotoPerfil: base.fotoPerfil,
      perfilCompleto: true,
      estado: base.estado,
    );

    try {
      // Intento online
      final saved = await _service.updateProfile(updated);
      _applyProfileToForm(saved);
      await _cacheProfile(saved);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado correctamente')),
      );
    } catch (e) {
      // Sin internet / error API → guardamos localmente igual
      await _cacheProfile(updated);
      _applyProfileToForm(updated);

      if (mounted) {
        setState(() {
          _error =
              'No se pudo enviar los datos al servidor, pero se guardaron en este dispositivo.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cambios guardados localmente. Se sincronizarán cuando tengas conexión.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _cedulaCtrl.dispose();
    _nombresCtrl.dispose();
    _apellidosCtrl.dispose();
    _telefonoCtrl.dispose();
    _correoCtrl.dispose();
    _direccionCtrl.dispose();
    _tipoSangreCtrl.dispose();
    _contactoEmergenciaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Perfil del técnico'),
          actions: [
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout),
              onPressed: () => _confirmLogout(context),
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil del técnico'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.orange),
                ),
              ),

            TextField(
              controller: _nombresCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombres',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _apellidosCtrl,
              decoration: const InputDecoration(
                labelText: 'Apellidos',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _cedulaCtrl,
              decoration: const InputDecoration(
                labelText: 'Cédula',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _telefonoCtrl,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _correoCtrl,
              decoration: const InputDecoration(
                labelText: 'Correo',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _direccionCtrl,
              decoration: const InputDecoration(
                labelText: 'Dirección domiciliaria',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _tipoSangreCtrl,
              decoration: const InputDecoration(
                labelText: 'Tipo de sangre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _contactoEmergenciaCtrl,
              decoration: const InputDecoration(
                labelText: 'Contacto de emergencia',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _profile?.perfilCompleto == true
                    ? 'Estado del perfil: COMPLETO'
                    : 'Estado del perfil: INCOMPLETO',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _profile?.perfilCompleto == true
                      ? Colors.green
                      : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Guardar cambios'),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text("Cerrar sesión"),
                onPressed: () => _confirmLogout(context),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
