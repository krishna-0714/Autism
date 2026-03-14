import 'package:wifi_iot/wifi_iot.dart';
import '../models/wifi_fingerprint_model.dart';
import 'package:flutter/foundation.dart';
import '../../data/api/ai_api_client.dart';
import '../../data/local/database_helper.dart';

abstract class IContextRepository {
  Future<String?> determineCurrentRoom(List<WifiFingerprintModel> fingerprints);
  Future<void> saveRoomFingerprints(String roomId, List<WifiFingerprintModel> fingerprints);
  Future<List<WifiFingerprintModel>> scanWifiNetworks();
}

class ContextRepositoryImpl implements IContextRepository {
  final AiApiClient _apiClient;

  ContextRepositoryImpl({AiApiClient? apiClient}) 
    : _apiClient = apiClient ?? AiApiClient();

  @override
  Future<String?> determineCurrentRoom(List<WifiFingerprintModel> fingerprints) async {
    if (fingerprints.isEmpty) return null;
    
    // Connect to the actual Python backend to resolve the room heuristic
    final room = await _apiClient.analyzeRoomContext(fingerprints);
    
    // Offline fallback logic would go here if `room` is null
    return room ?? "Unknown Context";
  }

  @override
  Future<void> saveRoomFingerprints(String roomId, List<WifiFingerprintModel> fingerprints) async {
    if (fingerprints.isEmpty) return;

    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      for (final fp in fingerprints) {
        if (fp.bssid.isEmpty) continue;
        await txn.insert('wifi_fingerprints', {
          'bssid': fp.bssid,
          'ssid': fp.ssid,
          'level': fp.level,
          'frequency': fp.frequency,
          'room_id': roomId,
          'timestamp': fp.timestamp,
          'synced': 0,
        });
      }
    });
  }

  @override
  Future<List<WifiFingerprintModel>> scanWifiNetworks() async {
    try {
      final isWifiEnabled = await WiFiForIoTPlugin.isEnabled();
      if (!isWifiEnabled) {
         await WiFiForIoTPlugin.setEnabled(true);
      }

      final List<WifiNetwork> networks = await WiFiForIoTPlugin.loadWifiList();
      final int currentTimestamp = DateTime.now().millisecondsSinceEpoch;

      final fingerprints = networks
          .where((network) => (network.bssid ?? '').isNotEmpty)
          .map(
            (network) => WifiFingerprintModel(
              bssid: network.bssid!,
              ssid: network.ssid ?? 'Unknown',
              level: network.level ?? -100,
              frequency: network.frequency ?? 2400,
              timestamp: currentTimestamp,
            ),
          )
          .toList();

      return fingerprints;

    } catch (e) {
      debugPrint("Hardware Error Scanning Wi-Fi: $e");
      return [];
    }
  }
}
