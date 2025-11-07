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
  final WorkSessionDao _dao = WorkSessionDao();
  List<WorkSession> _sessions = [];
  int _filterDays = 30; // 7 / 30 / 9999
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final now = DateTime.now();
    final all = await _dao.getLastN(_filterDays);
    setState(() {
      _sessions = all.where((s) {
        if (s.startAt.isAfter(now.subtract(Duration(days: _filterDays)))) {
          return true;
        }
        return false;
      }).toList();
      _loading = false;
    });
  }

  String _fmt(DateTime d) =>
      DateFormat('EEE d MMM yyyy, HH:mm', 'es').format(d);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de jornadas'),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) {
              setState(() {
                _filterDays = v;
                _loading = true;
              });
              _loadSessions();
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
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sessions.length,
                  itemBuilder: (context, i) {
                    final s = _sessions[i];
                    final dur = Duration(seconds: s.totalSeconds);
                    final h = dur.inHours.toString().padLeft(2, '0');
                    final m =
                        dur.inMinutes.remainder(60).toString().padLeft(2, '0');
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        title: Text(
                            '${_fmt(s.startAt)} → ${s.endAt != null ? DateFormat('HH:mm').format(s.endAt!) : '—'}'),
                        subtitle:
                            Text('Duración: $h h $m min • Estado: ${s.status}'),
                        leading: const Icon(Icons.work_history_outlined),
                      ),
                    );
                  },
                ),
    );
  }
}
