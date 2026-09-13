import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:tilawa/data/datasources/auth_api_client.dart';

/// Persists the signed-in session in the platform keystore/keychain.
///
/// Tokens are credentials, so they never go in the app's SQLite database or
/// shared preferences.
class AuthSessionStore {
  AuthSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  static const String _key = 'tilawa.auth.session';

  final FlutterSecureStorage _storage;

  Future<AuthSession?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return null;
      return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (error) {
      // A corrupt or undecryptable entry must not lock the user out of the
      // app; drop it and fall back to signed-out.
      debugPrint('Discarding unreadable auth session: $error');
      await clear();
      return null;
    }
  }

  Future<void> write(AuthSession session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));

  Future<void> clear() => _storage.delete(key: _key);
}
