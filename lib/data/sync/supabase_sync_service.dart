import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../repositories/symbol_repository_impl.dart';
import '../repositories/room_repository_impl.dart';
import '../../domain/models/symbol_model.dart';
import '../../domain/models/room_model.dart';

/// Orchestrates all data synchronization between Supabase (cloud) and SQLite (device cache).
/// Handles:
///   1. Boot sync — downloads fresh symbols + rooms from Supabase into SQLite
///   2. Offline flush — drains offline_queue into Supabase messages when reconnected
class SupabaseSyncService {
  final SupabaseClient _client = Supabase.instance.client;
  final SymbolRepositoryImpl _symbolRepo = SymbolRepositoryImpl();
  final RoomRepositoryImpl _roomRepo = RoomRepositoryImpl();
  
  static const int _maxRetries = 5;

  /// Call this on app startup. Downloads cloud data into the local SQLite cache.
  /// Safe to call multiple times — uses idempotent upserts internally.
  Future<void> syncOnBoot(String familyId) async {
    await Future.wait([
      _syncRooms(familyId),
      _syncSymbols(familyId),
    ]);
  }

  Future<void> _syncRooms(String familyId) async {
    try {
      final response = await _client
          .from('rooms')
          .select('id, name')
          .eq('family_id', familyId);

      final rooms = (response as List)
          .map((r) => RoomModel.fromJson(r as Map<String, dynamic>))
          .toList();

      // Atomic batch write — all rooms written in one SQLite transaction
      await _roomRepo.upsertAllRooms(rooms);
    } catch (e) {
      // Non-fatal — app will still use stale SQLite cache if offline
      debugPrint('Room sync skipped (offline?): $e');
    }
  }

  Future<void> _syncSymbols(String familyId) async {
    try {
      final response = await _client
          .from('symbols')
          .select('id, label, category, room_id, image_url, sort_order')
          .eq('family_id', familyId)
          .order('sort_order');

      final symbols = (response as List).map((s) {
        final map = s as Map<String, dynamic>;
        return SymbolModel(
          id: map['id'] as String,
          label: map['label'] as String,
          category: map['category'] as String,
          roomId: map['room_id'] as String?,
          imageUrl: map['image_url'] as String?,
        );
      }).toList();

      // Atomic batch upsert into cached_symbols
      for (final symbol in symbols) {
        await _symbolRepo.addSymbol(symbol);
      }
    } catch (e) {
      debugPrint('Symbol sync skipped (offline?): $e');
    }
  }

  /// Reads offline_queue from SQLite and flushes safely to Supabase messages.
  /// Respects the `attempts` counter so it stops after maxRetries (Circuit Breaker).
  Future<void> flushOfflineQueue(String familyId, String deviceId) async {
    final db = await _symbolRepo.getDatabase();

    // Read only events that haven't exceeded the retry limit
    final pending = await db.query(
      'offline_queue',
      where: 'attempts < ?',
      whereArgs: [_maxRetries],
      orderBy: 'timestamp ASC',
    );

    if (pending.isEmpty) return;

    for (final event in pending) {
      final id = event['id'] as int;
      try {
        await _client.from('messages').insert({
          'family_id': familyId,
          'symbol_id': event['symbol_id'],
          'room_id': event['room_id'],
          'sender_device_id': deviceId,
          'detection_method': 'wifi',
          'status': 'pending',
          'timestamp': event['timestamp'],
        });

        // Successfully synced — delete from queue
        await db.delete('offline_queue', where: 'id = ?', whereArgs: [id]);
      } catch (e) {
        // Supabase still down — increment attempts counter (Circuit Breaker)
        await db.rawUpdate(
          'UPDATE offline_queue SET attempts = attempts + 1 WHERE id = ?',
          [id],
        );
        debugPrint('Flush failed for event $id (attempt ${event['attempts']}): $e');
      }
    }
  }
}
