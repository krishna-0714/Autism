import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/wifi_fingerprint_model.dart';

class AiApiClient {
  final String baseUrl = const String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://autism-assist-backend.onrender.com/api/v1',
  );

  Future<String?> analyzeRoomContext(List<WifiFingerprintModel> fingerprints) async {
    try {
      final url = Uri.parse('$baseUrl/process-context');
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        debugPrint('Skipping context API call: no authenticated Supabase session.');
        return null;
      }

      final payload = fingerprints.map((f) => f.toJson()).toList();
      final token = session.accessToken;

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({"fingerprints": payload}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['room'] as String?;
      } else {
        // Log the error centrally, but don't crash
        debugPrint('Backend Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Network Error: $e');
      return null;
    }
  }
}
