import 'package:flutter/material.dart';
import 'sync_service.dart';

class SyncPage extends StatefulWidget {
  const SyncPage({super.key}); // <-- así
  @override
  State<SyncPage> createState() => _SyncPageState();
}


class _SyncPageState extends State<SyncPage> {
  String _status = 'Esperando acción...';
  bool _loading = false;

  Future<void> _sync() async {
    setState(() {
      _loading = true;
      _status = 'Sincronizando...';
    });

    try {
      await SyncService.syncIfConnected();
      setState(() {
        _status = '✅ Sincronización completa.';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error al sincronizar.';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sincronizar manualmente')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _loading ? null : _sync,
              icon: const Icon(Icons.sync),
              label: const Text('Sincronizar ahora'),
            ),
            const SizedBox(height: 20),
            Text(_status),
          ],
        ),
      ),
    );
  }
}
