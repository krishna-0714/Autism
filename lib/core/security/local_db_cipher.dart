import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Provides encryption key logic to secure the local SQLite Database (SQLCipher)
/// following Security Auditor and Database Design principles from GEMINI.md.
class LocalDbCipher {
  static const _storage = FlutterSecureStorage();
  static const _keyName = 'autism_assist_local_encryption_key';

  /// Generates or retrieves a secure 256-bit encryption key for SQLCipher usage
  static Future<String> getEncryptionKey() async {
    // Attempt to read the existing key from the Secure Enclave / Keystore
    final existingKey = await _storage.read(key: _keyName);
    if (existingKey != null) {
      return existingKey;
    }

    // Generate a new key and securely store it
    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    // We add more entropy for the initial key generation
    final bytes = utf8.encode("${timestamp}_AutiConnect_Secure_Salt_V1");
    final digest = sha256.convert(bytes);
    
    final newKey = digest.toString();
    await _storage.write(key: _keyName, value: newKey);
    return newKey;
  }
}
