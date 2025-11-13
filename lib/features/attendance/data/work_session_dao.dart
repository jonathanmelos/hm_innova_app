import 'package:sqflite/sqflite.dart';
import '../../../core/db/app_database.dart';
import 'work_session_model.dart';

class WorkSessionDao {
  Future<Database> get _db async => AppDatabase.instance;

  // ----------------- SESIONES -----------------

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
      'synced': 0, // Columna agregada para control de sincronización
    });
  }

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
        'synced': 0, // Asegurar que se vuelva a sincronizar
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

  Future<void> cancelSession(int sessionId) async {
    final db = await _db;
    await db.delete('work_pauses', where: 'session_id = ?', whereArgs: [sessionId]);
    await db.delete('qr_scans', where: 'session_id = ?', whereArgs: [sessionId]);
    await db.delete('session_locations', where: 'session_id = ?', whereArgs: [sessionId]);
    await db.delete('work_sessions', where: 'id = ?', whereArgs: [sessionId]);
  }

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

  // ----------------- MEDIA -----------------

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

  // ----------------- UBICACIONES -----------------

  Future<void> insertLocationLog({
    required int sessionId,
    required double lat,
    required double lon,
    required double accuracy,
    required DateTime at,
  }) async {
    final db = await _db;
    await db.insert('session_locations', {
      'session_id': sessionId,
      'lat': lat,
      'lon': lon,
      'accuracy': accuracy,
      'at': at.millisecondsSinceEpoch,
      'synced': 0,
    });
  }

  Future<void> markSessionAsSynced(int id) async {
    final db = await _db;
    await db.update('work_sessions', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markLocationsAsSynced(int sessionId) async {
    final db = await _db;
    await db.update('session_locations', {'synced': 1}, where: 'session_id = ? AND synced = 0', whereArgs: [sessionId]);
  }

  Future<List<Map<String, Object?>>> getUnsyncedSessions() async {
    final db = await _db;
    return db.query('work_sessions', where: 'synced = 0 AND end_at IS NOT NULL', orderBy: 'id ASC');
  }

  Future<List<Map<String, Object?>>> getUnsyncedLocations() async {
    final db = await _db;
    return db.query('session_locations', where: 'synced = 0', orderBy: 'at ASC');
  }

  Future<List<Map<String, Object?>>> getLocationsBySession(int sessionId) async {
    final db = await _db;
    return db.query('session_locations', where: 'session_id = ?', whereArgs: [sessionId], orderBy: 'at DESC');
  }

  Future<int> deleteLocationsBySession(int sessionId) async {
    final db = await _db;
    return db.delete('session_locations', where: 'session_id = ?', whereArgs: [sessionId]);
  }

  // ----------------- QR -----------------

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
    return db.query('qr_scans', where: 'session_id = ?', whereArgs: [sessionId], orderBy: 'scanned_at DESC');
  }

  // ----------------- DEBUG -----------------

  Future<void> debugPrintAll() async {
    final db = await _db;
    final s = await db.query('work_sessions', orderBy: 'id DESC');
    print('--- work_sessions ---');
    for (final r in s) print(r);

    final p = await db.query('work_pauses', orderBy: 'id DESC');
    print('--- work_pauses ---');
    for (final r in p) print(r);

    final q = await db.query('qr_scans', orderBy: 'id DESC');
    print('--- qr_scans ---');
    for (final r in q) print(r);

    final l = await db.query('session_locations', orderBy: 'at DESC');
    print('--- session_locations ---');
    for (final r in l) print(r);
  }
}