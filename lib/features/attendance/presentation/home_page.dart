import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// ⬇️ NUEVO: perfil del técnico
import 'package:hm_innova_app/features/auth/presentation/technician_profile_page.dart';

import 'history_page.dart';
import 'qr_scan_page.dart';
import '../state/attendance_controller.dart';
import '../state/attendance_state.dart';
import '../widgets/timer_display.dart';

// ⬇️ NUEVO: compact widget de sincronización
import '../widgets/sync_inline.dart';
// ⬇️ NUEVO: para disparar sync desde el AppBar
import '../sync_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late final AttendanceController _controller;
  bool _loading = true;

  late Timer _dateTicker;
  DateTime _now = DateTime.now();

  bool _flyToCorner = false;
  static const Duration _flyDuration = Duration(milliseconds: 500);

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    _controller = AttendanceController()..addListener(_onState);
    _bootstrap();
    _dateTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  Future<void> _bootstrap() async {
    try {
      await _controller.init().timeout(const Duration(seconds: 5));
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inicio lento. Entrando sin restaurar sesión.'),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo inicializar completamente: $e'),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onState() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onState);
    _controller.dispose();
    _dateTicker.cancel();
    super.dispose();
  }

  String _formatLongDate(DateTime d) {
    const wd = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    const mo = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${wd[d.weekday - 1]}, ${d.day} de ${mo[d.month - 1]} de ${d.year} – $hh:$mm';
  }

  Future<void> _acceptAndArchive() async {
    setState(() => _flyToCorner = true);
    await Future.delayed(_flyDuration + const Duration(milliseconds: 150));
    await _controller.resetToIdle();
    if (!mounted) return;
    setState(() => _flyToCorner = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Jornada archivada en Historial'),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
      ),
    );
  }

  // ========= Helpers permisos/cámara/archivos =========

  Future<void> _ensureCameraPermissionOrThrow() async {
    if (!_isMobile) return;
    var status = await Permission.camera.status;
    if (status.isDenied || status.isRestricted) {
      status = await Permission.camera.request();
    }
    if (status.isPermanentlyDenied) {
      throw 'Permiso de cámara denegado permanentemente. Actívalo en Ajustes.';
    }
    if (!status.isGranted) {
      throw 'Se requiere permiso de cámara para continuar.';
    }
  }

  Future<void> _awaitUiTick() async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<String?> _saveXFile(
    XFile file,
    String subfolder,
    String prefix,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, subfolder));
    if (!await folder.exists()) await folder.create(recursive: true);

    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = p.extension(file.path).isEmpty
        ? '.jpg'
        : p.extension(file.path);
    final dest = p.join(folder.path, '$prefix-$ts$ext');
    await File(file.path).copy(dest);
    return dest;
  }

  // ⚠️ Versión que evita cuelgues en Android (no fuerza cámara frontal/trasera)
  Future<XFile?> _safePickImage({required bool front}) async {
    final picker = ImagePicker();

    if (Platform.isIOS) {
      return picker
          .pickImage(
            source: ImageSource.camera,
            preferredCameraDevice: front
                ? CameraDevice.front
                : CameraDevice.rear,
            imageQuality: 85,
          )
          .timeout(const Duration(seconds: 25));
    }

    // Android: no forzar dispositivo de cámara
    return picker
        .pickImage(source: ImageSource.camera, imageQuality: 85)
        .timeout(const Duration(seconds: 25));
  }

  Future<void> _startWithCamerasOrFallback() async {
    // Escritorio: inicia sin media
    if (!(_isMobile)) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Cámara no disponible en escritorio'),
          content: const Text(
            'Se iniciará la jornada sin fotos (luego integramos cámara de escritorio).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
      await _controller.start();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jornada iniciada'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
        ),
      );
      return;
    }

    // Móvil
    try {
      await _ensureCameraPermissionOrThrow();

      // 1) Selfie
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Selfie de inicio'),
          content: const Text(
            'Tómate un selfie para registrar tu inicio de jornada.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      await _awaitUiTick();
      final selfie = await _safePickImage(front: true);
      if (selfie == null) return;
      final selfiePath = await _saveXFile(selfie, 'selfies', 'start_selfie');

      // 2) Contexto
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Foto del contexto'),
          content: const Text('Toma una foto de tu lugar de trabajo.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      await _awaitUiTick();
      final site = await _safePickImage(front: false);
      if (site == null) return;
      final sitePath = await _saveXFile(site, 'sites', 'start_site');

      await _controller.startWithMedia(
        selfieStart: selfiePath,
        photoStart: sitePath,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inicio registrado con fotos'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
        ),
      );
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La cámara tardó demasiado. Intenta de nuevo.'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo usar la cámara: $e'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
      await _controller.start(); // fallback
    }
  }

  // ========= FIN helpers =========

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final state = _controller.state;

    const objetivo =
        'Flujo: Iniciar → Pausar → (Continuar | Finalizar). '
        'El cronómetro excluye pausas. "Cancelar" reinicia si el registro fue incorrecto.';

    final header = switch (state.status) {
      SessionStatus.idle => 'Listo para iniciar jornada',
      SessionStatus.running => 'Jornada activa',
      SessionStatus.paused => 'Jornada en pausa',
      SessionStatus.stopped => 'Jornada finalizada',
    };

    Future<void> _syncFromAppBar() async {
      try {
        await SyncService.syncIfConnected();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sincronización completada.')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al sincronizar: $e')));
      }
    }

    Widget buildActions() {
      if (state.status == SessionStatus.idle) {
        return ConstrainedBox(
          constraints: const BoxConstraints.tightFor(height: 56),
          child: ElevatedButton(
            onPressed: _startWithCamerasOrFallback,
            style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
            child: const Text('Iniciar jornada'),
          ),
        );
      } else if (state.status == SessionStatus.running) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 56,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _controller.pause,
                style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
                child: const Text('Pausar'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Escanear QR de obra'),
                onPressed: () async {
                  if (!mounted) return;
                  await Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const QrScanPage()));
                },
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _controller.resetToIdle,
              child: const Text('Cancelar'),
            ),
          ],
        );
      } else if (state.status == SessionStatus.paused) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _controller.resume,
                    child: const Text('Continuar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _controller.stop,
                    child: const Text('Finalizar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Escanear QR de obra'),
                onPressed: () async {
                  if (!mounted) return;
                  await Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const QrScanPage()));
                },
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _controller.resetToIdle,
              child: const Text('Cancelar'),
            ),
          ],
        );
      }
      return ConstrainedBox(
        constraints: const BoxConstraints.tightFor(height: 56),
        child: FilledButton(
          onPressed: _acceptAndArchive,
          child: const Text('Aceptar'),
        ),
      );
    }

    Widget buildSummaryCard() {
      final card = Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatLongDate(_now),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 10),
              TimerDisplay(elapsed: state.elapsed),
              const SizedBox(height: 8),
              Text(switch (state.status) {
                SessionStatus.running => 'Contando…',
                SessionStatus.paused => 'Pausado',
                SessionStatus.idle => '00:00:00',
                SessionStatus.stopped => 'Tiempo total',
              }, style: Theme.of(context).textTheme.bodyMedium),
              if (state.startAt != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Inicio: ${_formatLongDate(state.startAt!)}'
                  '${state.endAt != null ? '\nFin:    ${_formatLongDate(state.endAt!)}' : ''}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      );

      if (state.status == SessionStatus.stopped) {
        return AnimatedAlign(
          duration: _flyDuration,
          curve: Curves.easeInOut,
          alignment: _flyToCorner
              ? const Alignment(-0.98, -0.92)
              : Alignment.center,
          child: AnimatedScale(
            duration: _flyDuration,
            curve: Curves.easeInOut,
            scale: _flyToCorner ? 0.35 : 1.0,
            child: card,
          ),
        );
      }
      return Align(alignment: Alignment.center, child: card);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('HM INNOVA • Asistencia'),
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Historial (último mes)',
          icon: const Icon(Icons.menu_book_outlined),
          onPressed: () async {
            if (!mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryPage()),
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Perfil del técnico',
            icon: const Icon(Icons.person_outline),
            onPressed: () async {
              if (!mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TechnicianProfilePage(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Sincronizar ahora',
            icon: const Icon(Icons.sync),
            onPressed: _syncFromAppBar,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              GestureDetector(
                onLongPress: () => _controller.debugPrintDb(),
                child: Text(
                  objetivo,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                header,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),

              // ⬇️ NUEVO: widget compacto de sincronización
              const SizedBox(height: 8),
              const SyncInline(mini: true),

              const Spacer(),
              SizedBox(height: 320, child: buildSummaryCard()),
              const Spacer(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: buildActions(),
      ),
    );
  }
}
