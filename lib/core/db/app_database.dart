import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static Database? _instance;

  static Future<Database> get instance async {
    if (_instance != null) return _instance!;

    final docs = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docs.path, 'hm_innova_app.db');

    _instance = await openDatabase(
      dbPath,
      version: 5, // ⬆️ Subido por nueva migración synced/remote_id
      onConfigure: (db) async {
        try {
          await db.rawQuery('PRAGMA foreign_keys = ON');
        } catch (_) {}
        try {
          await db.rawQuery('PRAGMA journal_mode = WAL');
        } catch (_) {}
        try {
          await db.rawQuery('PRAGMA busy_timeout = 5000');
        } catch (_) {}
      },

      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE work_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            start_at INTEGER NOT NULL,
            end_at   INTEGER,
            total_seconds INTEGER NOT NULL DEFAULT 0,
            status  TEXT NOT NULL,
            selfie_start TEXT,
            selfie_end   TEXT,
            photo_start  TEXT,
            photo_end    TEXT,
            remote_id    INTEGER,
            synced       INTEGER NOT NULL DEFAULT 0
          );
        ''');

        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_active ON work_sessions(end_at);',
        );

        await db.execute('''
          CREATE TABLE work_pauses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            start_at INTEGER NOT NULL,
            end_at   INTEGER,
            FOREIGN KEY(session_id) REFERENCES work_sessions(id) ON DELETE CASCADE
          );
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_pause_active ON work_pauses(session_id, end_at);',
        );

        await db.execute('''
          CREATE TABLE qr_scans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            project_code TEXT,
            area TEXT,
            description TEXT,
            scanned_at INTEGER NOT NULL,
            FOREIGN KEY(session_id) REFERENCES work_sessions(id) ON DELETE CASCADE
          );
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_qr_scans_session ON qr_scans(session_id);',
        );

        await db.execute('''
          CREATE TABLE session_locations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            lat REAL NOT NULL,
            lon REAL NOT NULL,
            accuracy REAL NOT NULL,
            at INTEGER NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0,
            remote_id INTEGER,
            FOREIGN KEY(session_id) REFERENCES work_sessions(id) ON DELETE CASCADE
          );
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_session_locations_session ON session_locations(session_id);',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_session_locations_at ON session_locations(at DESC);',
        );
      },

      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS work_pauses (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              session_id INTEGER NOT NULL,
              start_at INTEGER NOT NULL,
              end_at   INTEGER,
              FOREIGN KEY(session_id) REFERENCES work_sessions(id) ON DELETE CASCADE
            );
          ''');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_pause_active ON work_pauses(session_id, end_at);',
          );
        }

        if (oldV < 3) {
          await db.execute(
            "ALTER TABLE work_sessions ADD COLUMN selfie_start TEXT;",
          );
          await db.execute(
            "ALTER TABLE work_sessions ADD COLUMN selfie_end   TEXT;",
          );
          await db.execute(
            "ALTER TABLE work_sessions ADD COLUMN photo_start  TEXT;",
          );
          await db.execute(
            "ALTER TABLE work_sessions ADD COLUMN photo_end    TEXT;",
          );

          await db.execute('''
            CREATE TABLE IF NOT EXISTS qr_scans (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              session_id INTEGER NOT NULL,
              project_code TEXT,
              area TEXT,
              description TEXT,
              scanned_at INTEGER NOT NULL,
              FOREIGN KEY(session_id) REFERENCES work_sessions(id) ON DELETE CASCADE
            );
          ''');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_qr_scans_session ON qr_scans(session_id);',
          );
        }

        if (oldV < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS session_locations (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              session_id INTEGER NOT NULL,
              lat REAL NOT NULL,
              lon REAL NOT NULL,
              accuracy REAL NOT NULL,
              at INTEGER NOT NULL,
              FOREIGN KEY(session_id) REFERENCES work_sessions(id) ON DELETE CASCADE
            );
          ''');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_session_locations_session ON session_locations(session_id);',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_session_locations_at ON session_locations(at DESC);',
          );
        }

        if (oldV < 5) {
          await db.execute(
            "ALTER TABLE work_sessions ADD COLUMN remote_id INTEGER;",
          );
          await db.execute(
            "ALTER TABLE work_sessions ADD COLUMN synced INTEGER NOT NULL DEFAULT 0;",
          );
          await db.execute(
            "ALTER TABLE session_locations ADD COLUMN synced INTEGER NOT NULL DEFAULT 0;",
          );
          await db.execute(
            "ALTER TABLE session_locations ADD COLUMN remote_id INTEGER;",
          );
        }
      },
    );

    return _instance!;
  }

  static Future<void> close() async {
    if (_instance != null) {
      await _instance!.close();
      _instance = null;
    }
  }

  static Future<void> destroyForDev() async {
    await close();
    final docs = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docs.path, 'hm_innova_app.db');
    await deleteDatabase(dbPath);
  }
}
