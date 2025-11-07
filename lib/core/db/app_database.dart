import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static Database? _instance;

  /// Obtiene (o crea) la instancia única de la base de datos.
  static Future<Database> get instance async {
    if (_instance != null) return _instance!;

    final docs = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docs.path, 'hm_innova_app.db');

    _instance = await openDatabase(
      dbPath,
      version: 3, // esquema actual
      onConfigure: (db) async {
        // Algunos PRAGMA devuelven fila => usar rawQuery (no execute)
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

      // ─────────── CREACIÓN INICIAL ───────────
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
            photo_end    TEXT
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
      },

      // ─────────── MIGRACIONES ───────────
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
              "ALTER TABLE work_sessions ADD COLUMN selfie_start TEXT;");
          await db.execute(
              "ALTER TABLE work_sessions ADD COLUMN selfie_end   TEXT;");
          await db.execute(
              "ALTER TABLE work_sessions ADD COLUMN photo_start  TEXT;");
          await db.execute(
              "ALTER TABLE work_sessions ADD COLUMN photo_end    TEXT;");

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
      },
    );

    return _instance!;
  }

  /// Cierra la conexión (útil en tests o cuando cambias de usuario).
  static Future<void> close() async {
    if (_instance != null) {
      await _instance!.close();
      _instance = null;
    }
  }

  /// ⚠️ Solo para desarrollo: elimina el archivo de la BD y reinicia.
  static Future<void> destroyForDev() async {
    await close();
    final docs = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docs.path, 'hm_innova_app.db');
    await deleteDatabase(dbPath);
  }
}
