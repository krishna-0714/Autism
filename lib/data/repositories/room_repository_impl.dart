import 'package:sqflite/sqflite.dart';
import '../../domain/models/room_model.dart';
import '../local/database_helper.dart';

class RoomRepositoryImpl {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Fetches all rooms from the local SQLite cache
  Future<List<RoomModel>> getAllRooms() async {
    final db = await _dbHelper.database;
    final maps = await db.query('cached_rooms', orderBy: 'name ASC');
    return maps.map((map) => _mapToRoom(map)).toList();
  }

  /// Fetches a single room by ID
  Future<RoomModel?> getRoomById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'cached_rooms',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) return _mapToRoom(maps.first);
    return null;
  }

  /// Upserts a room (insert or replace if already exists)
  /// Idempotent — safe to call multiple times with same data
  Future<void> upsertRoom(RoomModel room) async {
    final db = await _dbHelper.database;
    await db.insert(
      'cached_rooms',
      {'id': room.id, 'name': room.name},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Bulk upsert — used to write the full Supabase sync batch in one transaction
  Future<void> upsertAllRooms(List<RoomModel> rooms) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final room in rooms) {
      batch.insert(
        'cached_rooms',
        {'id': room.id, 'name': room.name},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true); // Transaction commit — atomic write
  }

  /// Deletes a room by ID
  Future<void> deleteRoom(String id) async {
    final db = await _dbHelper.database;
    await db.delete('cached_rooms', where: 'id = ?', whereArgs: [id]);
  }

  /// Clears all cached rooms before a full re-sync
  Future<void> clearAll() async {
    final db = await _dbHelper.database;
    await db.delete('cached_rooms');
  }

  RoomModel _mapToRoom(Map<String, dynamic> map) {
    return RoomModel(
      id: map['id'] as String,
      name: map['name'] as String,
    );
  }
}
