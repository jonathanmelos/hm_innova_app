import 'dart:convert' as dart_convert;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/work_session_dao.dart'; // ✅ desde /presentation/ a /data es un solo nivel

/// Pantalla para escanear un QR y registrar el resultado en la sesión activa.
/// Acepta:
///  - Texto plano → se guarda como `description`
///  - JSON con llaves {"project_code","area","description"}
class QrScanPage extends StatefulWidget {
  /// Opcional: si le pasas un controller desde fuera (por ejemplo, para reutilizarlo
  /// o probar), el widget lo usará. Si no, crea uno interno.
  final MobileScannerController? controller;

  const QrScanPage({super.key, this.controller});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final WorkSessionDao _dao = WorkSessionDao();

  late final MobileScannerController _controller =
      widget.controller ?? MobileScannerController();

  bool _handled = false;

  @override
  void dispose() {
    // Solo lo cerramos si lo creamos nosotros
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_handled) return;
    final code = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;
    if (code == null || code.isEmpty) return;

    _handled = true;

    try {
      final active = await _dao.getActive();
      if (active == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay una jornada activa.')),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      String? projectCode;
      String? area;
      String? description;

      // Intentar parsear como JSON
      try {
        final data = dart_convert.jsonDecode(code);
        if (data is Map) {
          projectCode = data['project_code']?.toString();
          area = data['area']?.toString();
          description = data['description']?.toString();
        } else {
          description = code;
        }
      } catch (_) {
        description = code; // No era JSON
      }

      await _dao.insertQrScan(
        sessionId: active.id!,
        projectCode: projectCode,
        area: area,
        description: description,
        scannedAt: DateTime.now(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'QR registrado: ${description ?? projectCode ?? 'OK'}',
            ),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al registrar QR: $e')));
        Navigator.of(context).pop(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear QR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: MobileScanner(controller: _controller, onDetect: _handleBarcode),
    );
  }
}
