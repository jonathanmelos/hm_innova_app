// lib/features/attendance/presentation/history_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/work_session_dao.dart';
import '../data/work_session_model.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _dao = WorkSessionDao();
  final _now = DateTime.now();

  List<WorkSession> _sessions = [];
  int _filterDays = 30; // 7 / 30 / 9999
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final all = await _dao.getLastN(_filterDays);

    // Filtra y ordena (más recientes primero)
    final cutoff = _now.subtract(Duration(days: _filterDays));
    _sessions = all.where((s) => s.startAt.isAfter(cutoff)).toList()
      ..sort((a, b) => b.startAt.compareTo(a.startAt));

    if (mounted) setState(() => _loading = false);
  }

  // Formato seguro en ES (requiere initializeDateFormatting('es') en main.dart)
  String _fmtFull(DateTime d) =>
      DateFormat('EEE d MMM yyyy, HH:mm', 'es').format(d);

  String _fmtHour(DateTime d) => DateFormat('HH:mm', 'es').format(d);

  String _fmtDuration(int seconds) {
    if (seconds <= 0) return '00 h 00 min';
    final dur = Duration(seconds: seconds);
    final h = dur.inHours.toString().padLeft(2, '0');
    final m = (dur.inMinutes % 60).toString().padLeft(2, '0');
    return '$h h $m min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de jornadas'),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.filter_list),
            initialValue: _filterDays,
            onSelected: (v) async {
              setState(() {
                _filterDays = v;
                _loading = true;
              });
              await _loadSessions();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 7, child: Text('Últimos 7 días')),
              PopupMenuItem(value: 30, child: Text('Últimos 30 días')),
              PopupMenuItem(value: 9999, child: Text('Todos')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
          ? const Center(child: Text('No hay jornadas registradas.'))
          : RefreshIndicator(
              onRefresh: _loadSessions,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: _sessions.length,
                itemBuilder: (context, i) {
                  final s = _sessions[i];
                  final endTxt = s.endAt != null ? _fmtHour(s.endAt!) : '—';
                  final status = s.status; // running | paused | stopped

                  IconData leadingIcon;
                  Color? leadingColor;
                  switch (status) {
                    case 'running':
                      leadingIcon = Icons.play_arrow_rounded;
                      leadingColor = Colors.green.shade600;
                      break;
                    case 'paused':
                      leadingIcon = Icons.pause_rounded;
                      leadingColor = Colors.orange.shade700;
                      break;
                    case 'stopped':
                      leadingIcon = Icons.stop_rounded;
                      leadingColor = Colors.blue.shade700;
                      break;
                    default:
                      leadingIcon = Icons.history_rounded;
                      leadingColor = Theme.of(context).colorScheme.primary;
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: leadingColor.withOpacity(.12),
                        foregroundColor: leadingColor,
                        child: Icon(leadingIcon),
                      ),
                      title: Text(
                        '${_fmtFull(s.startAt)} → $endTxt',
                        maxLines: 2,
                      ),
                      subtitle: Text(
                        'Duración: ${_fmtDuration(s.totalSeconds)} • Estado: $status',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // Aquí podrías abrir detalle de la jornada si lo implementas
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}
