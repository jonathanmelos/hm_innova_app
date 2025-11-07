// lib/features/attendance/presentation/qr_scan_page.dart
import 'dart:async';
import 'dart:convert' as dartConvert;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../state/attendance_controller.dart';

/// Pantalla de escaneo QR para registrar proyecto/área.
/// Requiere tener en pubspec:
///   mobile_scanner: ^6.0.2
class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key, required this.controller});

  final AttendanceController controller;

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final MobileScannerController _scanner = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
    detectionSpeed: DetectionSpeed.normal,
  );

  bool _consumed = false; // evita múltiples lecturas del mismo frame
  String? _lastRaw;

  Future<void> _handleDetection(BarcodeCapture cap) async {
    if (_consumed) return;

    final codes = cap.barcodes;
    if (codes.isEmpty) return;

    final raw = codes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    // Evita dobles disparos del mismo valor
    if (_lastRaw == raw) return;
    _lastRaw = raw;
    _consumed = true;

    try {
      // Puedes definir tu propio formato de QR. Ejemplos aceptados:
      // - "project=AVANTINO;area=Bloque B;desc=Instalación luminarias"
      // - JSON: {"project":"AVANTINO","area":"Bloque B","desc":"Instalación luminarias"}
      String? project;
      String? area;
      String? desc;

      if (raw.trim().startsWith('{')) {
        // intento parseo JSON simple
        final map = _tryParseJson(raw);
        project = map['project']?.toString();
        area = map['area']?.toString();
        desc = map['desc']?.toString();
      } else {
        // parseo tipo key=value;key=value
        final parts = raw.split(RegExp(r'[;,\n]'));
        for (final p in parts) {
          final kv = p.split('=');
          if (kv.length == 2) {
            final k = kv[0].trim().toLowerCase();
            final v = kv[1].trim();
            if (k == 'project' || k == 'proyecto') project = v;
            if (k == 'area') area = v;
            if (k == 'desc' || k == 'descripcion') desc = v;
          }
        }
      }

      // Guarda el evento de escaneo en la DB
      await widget.controller.logQrScan(
        projectCode: project,
        area: area,
        description: desc ?? _lastRaw, // respaldo: guarda el raw si no hay desc
        when: DateTime.now(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR registrado'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
        ),
      );

      // Cierra la pantalla después de un pequeño delay para que se vea el SnackBar
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al registrar QR: $e'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
      // Permite reintentar si falló
      _consumed = false;
    }
  }

  Map<String, dynamic> _tryParseJson(String raw) {
    try {
      // ignore: avoid_dynamic_calls
      return (dartConvert.jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear QR de obra'),
        actions: [
          IconButton(
            tooltip: 'Cambiar cámara',
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _scanner.switchCamera(),
          ),
          IconButton(
            tooltip: 'Linterna',
            icon: const Icon(Icons.flash_on),
            onPressed: () => _scanner.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scanner,
            onDetect: _handleDetection,
          ),
          // Marco simple
          IgnorePointer(
            child: Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Pequeña import de json sin añadir en la cabecera principal
// para mantener el archivo autocontenido.
