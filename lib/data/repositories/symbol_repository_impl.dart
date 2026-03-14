import 'package:sqflite/sqflite.dart';
import '../../domain/models/symbol_model.dart';
import '../../domain/repositories/i_symbol_repository.dart';
import '../local/database_helper.dart';

class SymbolRepositoryImpl implements ISymbolRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Database> getDatabase() async => await _dbHelper.database;

  @override
  Future<void> addSymbol(SymbolModel symbol) async {
    final db = await _dbHelper.database;
    await db.insert(
      'cached_symbols',
      {
        'id': symbol.id,
        'label': symbol.label,
        'category': symbol.category,
        'room_id': symbol.roomId,
        'image_url': symbol.imageUrl,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteSymbol(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'cached_symbols',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<SymbolModel?> getSymbolById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'cached_symbols',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return _mapToSymbol(maps.first);
    }
    return null;
  }

  @override
  Future<List<SymbolModel>> getSymbols({String? category, String? roomId}) async {
    final db = await _dbHelper.database;

    final maps = await _querySymbols(db, category: category, roomId: roomId);
    if (maps.isNotEmpty || roomId == null) {
      return maps.map((map) => _mapToSymbol(map)).toList();
    }

    // If the model returned a display label (e.g. "Living Room (Heuristic)"),
    // try resolving it to the canonical cached room id.
    final normalizedName = roomId.replaceAll(' (Heuristic)', '').trim();
    final roomMaps = await db.query(
      'cached_rooms',
      columns: ['id'],
      where: 'LOWER(name) = ?',
      whereArgs: [normalizedName.toLowerCase()],
      limit: 1,
    );
    if (roomMaps.isEmpty) return const [];

    final resolvedRoomId = roomMaps.first['id'] as String?;
    if (resolvedRoomId == null || resolvedRoomId.isEmpty) return const [];

    final fallbackMaps = await _querySymbols(db, category: category, roomId: resolvedRoomId);
    return fallbackMaps.map((map) => _mapToSymbol(map)).toList();
  }

  Future<List<Map<String, Object?>>> _querySymbols(
    Database db, {
    String? category,
    String? roomId,
  }) {
    String? whereClause;
    List<dynamic>? whereArgs;

    if (category != null && roomId != null) {
      whereClause = 'category = ? AND room_id = ?';
      whereArgs = [category, roomId];
    } else if (category != null) {
      whereClause = 'category = ?';
      whereArgs = [category];
    } else if (roomId != null) {
      whereClause = 'room_id = ?';
      whereArgs = [roomId];
    }

    return db.query(
      'cached_symbols',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'label ASC',
    );
  }

  @override
  Future<void> incrementUsageCount(String id) async {
    // In the Minimal SQLite architecture, usage count tracking happens in the 
    // `offline_queue` table which SyncEngine later fires to Supabase to calculate metrics.
    final db = await _dbHelper.database;
    await db.insert('offline_queue', {
      'symbol_id': id,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> updateSymbol(SymbolModel symbol) async {
    final db = await _dbHelper.database;
    await db.update(
      'cached_symbols',
      {
        'label': symbol.label,
        'category': symbol.category,
        'room_id': symbol.roomId,
        'image_url': symbol.imageUrl,
      },
      where: 'id = ?',
      whereArgs: [symbol.id],
    );
  }

  // Helper method to map SQLite rows back into Domain Models
  SymbolModel _mapToSymbol(Map<String, dynamic> map) {
    return SymbolModel(
      id: map['id'] as String,
      label: map['label'] as String,
      category: map['category'] as String,
      roomId: map['room_id'] as String?,
      imageUrl: map['image_url'] as String?,
    );
  }
}
