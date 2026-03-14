import 'package:flutter_test/flutter_test.dart';
import 'package:autism_assist_app/domain/models/symbol_model.dart';
import 'package:autism_assist_app/domain/models/wifi_fingerprint_model.dart';

void main() {
  group('Domain Models Tests', () {
    test('SymbolModel Serializes and Deserializes safely', () {
      const symbol = SymbolModel(
        id: 'test_123',
        label: 'I want juice',
        category: 'needs',
      );

      final json = symbol.toJson();
      expect(json['id'], 'test_123');
      expect(json['label'], 'I want juice');
      expect(json['usageCount'], 0);

      final restored = SymbolModel.fromJson(json);
      expect(restored.id, 'test_123');
      expect(restored.label, 'I want juice');
    });

    test('WifiFingerprintModel captures structural offline schema', () {
      const fp = WifiFingerprintModel(
        bssid: '00:11:22:33',
        ssid: 'Home_Wifi',
        level: -45,
        frequency: 2400,
        timestamp: 1670000000,
      );

      final map = fp.toJson();
      expect(map['level'], -45);
      expect(map['ssid'], 'Home_Wifi');

      final reconstructed = WifiFingerprintModel.fromJson(map);
      expect(reconstructed.bssid, '00:11:22:33');
    });
  });
}
