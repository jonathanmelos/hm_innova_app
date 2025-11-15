import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
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

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await _service.fetchProfile();
      _profile = profile;

      _cedulaCtrl.text = profile.cedula ?? '';
      _nombresCtrl.text = profile.nombres ?? '';
      _apellidosCtrl.text = profile.apellidos ?? '';
      _telefonoCtrl.text = profile.telefono ?? '';
      _correoCtrl.text = profile.correo ?? '';
      _direccionCtrl.text = profile.direccion ?? '';
      _tipoSangreCtrl.text = profile.tipoSangre ?? '';
      _contactoEmergenciaCtrl.text = profile.contactoEmergencia ?? '';

      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Error al cargar perfil: $e';
        });
      }
    }
  }

  Future<void> _save() async {
    if (_profile == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = TechnicianProfile(
        id: _profile!.id,
        userId: _profile!.userId,
        cedula: _cedulaCtrl.text.trim(),
        nombres: _nombresCtrl.text.trim(),
        apellidos: _apellidosCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim(),
        correo: _correoCtrl.text.trim(),
        direccion: _direccionCtrl.text.trim(),
        tipoSangre: _tipoSangreCtrl.text.trim(),
        contactoEmergencia: _contactoEmergenciaCtrl.text.trim(),
        fotoPerfil: _profile!.fotoPerfil,
        perfilCompleto: true,
        estado: _profile!.estado,
      );

      final saved = await _service.updateProfile(updated);
      _profile = saved;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado correctamente')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Error al guardar: $e');
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
        appBar: AppBar(title: const Text('Perfil del técnico')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil del técnico')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
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
              readOnly: true,
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
          ],
        ),
      ),
    );
  }
}
