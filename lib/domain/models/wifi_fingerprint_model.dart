class WifiFingerprintModel {
  final String bssid;
  final String ssid;
  final int level;
  final int frequency;
  final int timestamp;

  const WifiFingerprintModel({
    required this.bssid,
    required this.ssid,
    required this.level,
    required this.frequency,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'bssid': bssid,
      'ssid': ssid,
      'level': level,
      'frequency': frequency,
      'timestamp': timestamp,
    };
  }

  factory WifiFingerprintModel.fromJson(Map<String, dynamic> json) {
    return WifiFingerprintModel(
      bssid: json['bssid'] as String,
      ssid: json['ssid'] as String,
      level: json['level'] as int,
      frequency: json['frequency'] as int,
      timestamp: json['timestamp'] as int,
    );
  }
}
