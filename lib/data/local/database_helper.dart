import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as cipher;
import '../../core/security/local_db_cipher.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static const int _dbVersion = 2;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('auticonnect_cache.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // Fetch the 256-bit AES key hardware-bound to this device
    final encryptionKey = await LocalDbCipher.getEncryptionKey();

    // Open/Create the SQLite database utilizing SQLCipher for at-rest encryption
    return await cipher.openDatabase(
      path,
      password: encryptionKey,
      version: _dbVersion,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    // 1. Cached Symbols (From Supabase) - Used for instant UI rendering
    await db.execute('''
      CREATE TABLE cached_symbols (
        id TEXT PRIMARY KEY,
        label TEXT NOT NULL,
        category TEXT NOT NULL,
        room_id TEXT,
        image_url TEXT
      )
    ''');

    // 2. Cached Rooms (From Supabase)
    await db.execute('''
      CREATE TABLE cached_rooms (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');

    // 3. Offline AI Fingerprint Cache (Never leaves the device)
    await db.execute('''
      CREATE TABLE wifi_fingerprints (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bssid TEXT NOT NULL,
        ssid TEXT NOT NULL,
        level INTEGER NOT NULL,
        frequency INTEGER NOT NULL DEFAULT 2400,
        room_id TEXT,
        timestamp INTEGER NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');

    // 4. Offline Taps / Usage Logs (Synced to Supabase when online)
    await db.execute('''
      CREATE TABLE offline_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        symbol_id TEXT NOT NULL,
        room_id TEXT,
        timestamp INTEGER NOT NULL,
        attempts INTEGER DEFAULT 0
      )
    ''');

    // Seed some safe fallback symbols just in case the first boot has no internet
    await db.insert('cached_symbols', {'id': 'home', 'label': 'Take me home', 'category': 'emergency'});
    await db.insert('cached_symbols', {'id': 'help', 'label': 'I need help', 'category': 'emergency'});
    await db.insert('cached_symbols', {'id': 'eat', 'label': 'I want food', 'category': 'needs'});
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _ensureColumnExists(
        db,
        table: 'wifi_fingerprints',
        column: 'frequency',
        definition: 'INTEGER NOT NULL DEFAULT 2400',
      );
      await _ensureColumnExists(
        db,
        table: 'wifi_fingerprints',
        column: 'room_id',
        definition: 'TEXT',
      );
    }
  }

  Future<void> _ensureColumnExists(
    Database db, {
    required String table,
    required String column,
    required String definition,
  }) async {
    final tableInfo = await db.rawQuery('PRAGMA table_info($table)');
    final hasColumn = tableInfo.any((row) => row['name'] == column);
    if (!hasColumn) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
