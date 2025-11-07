import 'package:sqflite/sqflite.dart';
import '../../../core/db/app_database.dart';
import 'work_session_model.dart';

class WorkSessionDao {
  Future<Database> get _db async => AppDatabase.instance;

  // ----------------- SESIONES -----------------

  /// Crea una sesión en estado "running".
  /// Permite guardar inmediatamente la selfie y/o foto de contexto inicial.
  Future<int> insertRunning(
    DateTime start, {
    String? selfieStart,
    String? photoStart,
  }) async {
    final db = await _db;
    return db.insert('work_sessions', {
      'start_at': start.millisecondsSinceEpoch,
      'end_at': null,
      'total_seconds': 0,
      'status': 'running',
      'selfie_start': selfieStart,
      'selfie_end': null,
      'photo_start': photoStart,
      'photo_end': null,
    });
  }

  /// Finaliza una sesión y opcionalmente registra la selfie/foto final.
  Future<void> finishSession({
    required int id,
    required DateTime end,
    required int totalSeconds,
    String? selfieEnd,
    String? photoEnd,
  }) async {
    final db = await _db;
    await db.update(
      'work_sessions',
      {
        'end_at': end.millisecondsSinceEpoch,
        'total_seconds': totalSeconds,
        'status': 'stopped',
        if (selfieEnd != null) 'selfie_end': selfieEnd,
        if (photoEnd != null) 'photo_end': photoEnd,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<WorkSession?> getActive() async {
    final db = await _db;
    final rows = await db.query(
      'work_sessions',
      where: 'end_at IS NULL',
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return WorkSession.fromMap(rows.first);
  }

  Future<WorkSession?> getLast() async {
    final db = await _db;
    final rows = await db.query('work_sessions', orderBy: 'id DESC', limit: 1);
    if (rows.isEmpty) return null;
    return WorkSession.fromMap(rows.first);
  }

  /// Elimina una sesión y sus pausas/QR asociados.
  Future<void> cancelSession(int sessionId) async {
    final db = await _db;
    // Con FK + ON DELETE CASCADE no sería estrictamente necesario,
    // pero lo hacemos explícito por robustez.
    await db
        .delete('work_pauses', where: 'session_id = ?', whereArgs: [sessionId]);
    await db
        .delete('qr_scans', where: 'session_id = ?', whereArgs: [sessionId]);
    await db.delete('work_sessions', where: 'id = ?', whereArgs: [sessionId]);
  }

  /// Si existe una sesión activa (end_at NULL), la elimina.
  Future<void> cancelActiveIfAny() async {
    final db = await _db;
    final rows = await db.query(
      'work_sessions',
      where: 'end_at IS NULL',
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final id = rows.first['id'] as int;
      await cancelSession(id);
    }
  }

  // ----------------- PAUSAS -----------------
  Future<int> startPause(int sessionId, DateTime start) async {
    final db = await _db;
    return db.insert('work_pauses', {
      'session_id': sessionId,
      'start_at': start.millisecondsSinceEpoch,
      'end_at': null,
    });
  }

  Future<void> endPause(int pauseId, DateTime end) async {
    final db = await _db;
    await db.update(
      'work_pauses',
      {'end_at': end.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [pauseId],
    );
  }

  Future<Map<String, Object?>?> getActivePause(int sessionId) async {
    final db = await _db;
    final rows = await db.query(
      'work_pauses',
      where: 'session_id = ? AND end_at IS NULL',
      whereArgs: [sessionId],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<int> getTotalPausedSeconds(int sessionId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT SUM((COALESCE(end_at, strftime('%s','now')*1000) - start_at)/1000) AS total
      FROM work_pauses
      WHERE session_id = ?
    ''', [sessionId]);
    final total = rows.first['total'] as num?;
    return (total ?? 0).toInt();
  }

  // ----------------- MEDIA (FOTOS / SELFIES) -----------------
  Future<void> setSelfieStart(int sessionId, String filePath) async {
    final db = await _db;
    await db.update(
      'work_sessions',
      {'selfie_start': filePath},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> setSelfieEnd(int sessionId, String filePath) async {
    final db = await _db;
    await db.update(
      'work_sessions',
      {'selfie_end': filePath},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> setPhotoStart(int sessionId, String filePath) async {
    final db = await _db;
    await db.update(
      'work_sessions',
      {'photo_start': filePath},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> setPhotoEnd(int sessionId, String filePath) async {
    final db = await _db;
    await db.update(
      'work_sessions',
      {'photo_end': filePath},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  // ----------------- QR SCANS -----------------
  Future<int> insertQrScan({
    required int sessionId,
    String? projectCode,
    String? area,
    String? description,
    DateTime? scannedAt,
  }) async {
    final db = await _db;
    return db.insert('qr_scans', {
      'session_id': sessionId,
      'project_code': projectCode,
      'area': area,
      'description': description,
      'scanned_at': (scannedAt ?? DateTime.now()).millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, Object?>>> getQrScansBySession(int sessionId) async {
    final db = await _db;
    return db.query(
      'qr_scans',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'scanned_at DESC',
    );
  }

  // ----------------- CONSULTAS / DEBUG -----------------
  Future<void> debugPrintAll() async {
    final db = await _db;

    final s = await db.query('work_sessions', orderBy: 'id DESC');
    // ignore: avoid_print
    print('--- work_sessions ---');
    // ignore: avoid_print
    for (final r in s) {
      print(r);
    }

    final p = await db.query('work_pauses', orderBy: 'id DESC');
    // ignore: avoid_print
    print('--- work_pauses ---');
    // ignore: avoid_print
    for (final r in p) {
      print(r);
    }

    final q = await db.query('qr_scans', orderBy: 'id DESC');
    // ignore: avoid_print
    print('--- qr_scans ---');
    // ignore: avoid_print
    for (final r in q) {
      print(r);
    }
  }

  Future<List<WorkSession>> getLastN(int days) async {
    final db = await _db;
    if (days >= 9999) {
      final rows = await db.query('work_sessions', orderBy: 'start_at DESC');
      return rows.map(WorkSession.fromMap).toList();
    }
    final cutoff =
        DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final rows = await db.query(
      'work_sessions',
      where: 'start_at > ?',
      whereArgs: [cutoff],
      orderBy: 'start_at DESC',
    );
    return rows.map(WorkSession.fromMap).toList();
  }
}
