import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:tilawa/data/datasources/api_client.dart';

/// Identity providers the backend can verify.
enum AuthProviderKind {
  google('google'),
  apple('apple');

  const AuthProviderKind(this.wireName);

  final String wireName;
}

/// The signed-in account as the API describes it.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.provider,
  });

  final String id;
  final String email;
  final String displayName;
  final String provider;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: (json['email'] as String?) ?? '',
      displayName: (json['displayName'] as String?) ?? '',
      provider: (json['provider'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'provider': provider,
      };
}

/// Access + refresh token pair issued by the API.
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final AuthUser user;

  /// Treated as expired a minute early so a request never races the boundary.
  bool get isExpired =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 1)));

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt.toIso8601String(),
        'user': user.toJson(),
      };
}

/// Exchanges provider identity tokens for a Tilawa session.
///
/// The provider token is only ever verified server-side against the issuer's
/// public keys; the app never sees or stores a password.
class AuthApiClient {
  AuthApiClient({
    required String baseUrl,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 12),
  })  : _baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _http = httpClient ?? http.Client(),
        _timeout = timeout;

  final String _baseUrl;
  final http.Client _http;
  final Duration _timeout;

  /// [identityToken] is the Google ID token or the Apple identity token.
  /// Apple only returns the user's name on the very first authorization, so
  /// [displayName] is forwarded when present.
  Future<AuthSession> signIn({
    required AuthProviderKind provider,
    required String identityToken,
    String? authorizationCode,
    String? displayName,
  }) async {
    final response = await _post('/api/v1/auth/${provider.wireName}', {
      'identityToken': identityToken,
      if (authorizationCode != null) 'package:tilawa/data/datasources/authorizationCode': authorizationCode,
      if (displayName != null && displayName.isNotEmpty)
        'package:tilawa/data/datasources/displayName': displayName,
    });
    return AuthSession.fromJson(response);
  }

  Future<AuthSession> refresh(String refreshToken) async {
    final response = await _post('/api/v1/auth/refresh', {
      'refreshToken': refreshToken,
    });
    return AuthSession.fromJson(response);
  }

  Future<void> signOut(String refreshToken) async {
    await _post('/api/v1/auth/sign-out', {'refreshToken': refreshToken});
  }

  void close() => _http.close();

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _http
        .post(
          Uri.parse('$_baseUrl$path'),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, response.body);
    }
    if (response.body.isEmpty) return const {};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
