import 'package:flutter/material.dart';
import '../sync_service.dart'; // <- ruta correcta desde widgets/

/// Control compacto para sincronización manual.
/// - Muestra estado, última sincronización y botón.
/// - No bloquea tu UI existente.
class SyncInline extends StatefulWidget {
  final bool mini; // si true, versión compacta (ideal para barras/cards)
  const SyncInline({super.key, this.mini = false});

  @override
  State<SyncInline> createState() => _SyncInlineState();
}

class _SyncInlineState extends State<SyncInline> {
  bool _syncing = false;
  DateTime? _lastSync;
  String? _lastMsg;

  Future<void> _doSync() async {
    setState(() {
      _syncing = true;
      _lastMsg = null;
    });
    try {
      await SyncService.syncIfConnected();
      setState(() {
        _lastSync = DateTime.now();
        _lastMsg = 'Sincronización completada';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sincronización completada.')),
        );
      }
    } catch (e) {
      setState(() => _lastMsg = 'Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al sincronizar: $e')));
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_syncing ? Icons.sync : Icons.cloud_sync_outlined),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _syncing ? 'Sincronizando…' : 'Listo para sincronizar',
                style: textStyle,
              ),
              if (_lastSync != null)
                Text(
                  'Última: ${_lastSync!.hour.toString().padLeft(2, '0')}:'
                  '${_lastSync!.minute.toString().padLeft(2, '0')}',
                  style: textStyle,
                ),
              if (_lastMsg != null)
                Text(
                  _lastMsg!,
                  style: textStyle,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _syncing ? null : _doSync,
          icon: const Icon(Icons.sync),
          label: Text(_syncing ? 'Sincronizando…' : 'Sincronizar'),
        ),
      ],
    );

    // mini = fila compacta; si no, lo envolvemos en Card
    if (widget.mini) return content;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(padding: const EdgeInsets.all(12), child: content),
    );
  }
}
