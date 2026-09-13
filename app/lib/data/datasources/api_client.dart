import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Non-2xx response from the API.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode): $body';
}

/// Supplies the current access token, and refreshes it once on a 401.
abstract class AuthTokenSource {
  Future<String?> accessToken();

  /// Returns a fresh token, or null when the session cannot be renewed.
  Future<String?> refresh();
}

/// HTTP client for the Tilawa API.
///
/// One implementation for every platform: `package:http` covers mobile,
/// desktop and web, so there is no io/web split to keep in sync.
class TilawaApiClient {
  TilawaApiClient({
    required String baseUrl,
    http.Client? httpClient,
    AuthTokenSource? tokens,
    Duration timeout = const Duration(seconds: 8),
  })  : _baseUrl = _stripTrailingSlash(baseUrl),
        _http = httpClient ?? http.Client(),
        _tokens = tokens,
        _timeout = timeout;

  final String _baseUrl;
  final http.Client _http;
  final AuthTokenSource? _tokens;
  final Duration _timeout;

  String get baseUrl => _baseUrl;

  // --- Revision -------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getSurahs() async =>
      _asList(await _send('GET', '/api/v1/revision/surahs'));

  Future<Map<String, dynamic>> getPrioritySurah() async =>
      _asMap(await _send('GET', '/api/v1/revision/priority'));

  Future<List<Map<String, dynamic>>> getPlans() async =>
      _asList(await _send('GET', '/api/v1/revision/plans'));

  Future<Map<String, dynamic>> createPlan(Map<String, dynamic> body) async =>
      _asMap(await _send('POST', '/api/v1/revision/plans', body: body));

  Future<Map<String, dynamic>> updatePlan(
    String id,
    Map<String, dynamic> body,
  ) async =>
      _asMap(await _send('PUT', '/api/v1/revision/plans/$id', body: body));

  Future<void> deletePlan(String id) async {
    await _send('DELETE', '/api/v1/revision/plans/$id');
  }

  Future<List<Map<String, dynamic>>> recordSelfAssessment({
    required int surahNumber,
    required int confidence,
    required int durationSeconds,
    String? section,
    required int quranReadCount,
  }) async {
    return _asList(
      await _send('POST', '/api/v1/revision/self-assessments', body: {
        'surahNumber': surahNumber,
        'confidence': confidence,
        'durationSeconds': durationSeconds,
        'section': section,
        'quranReadCount': quranReadCount,
      }),
    );
  }

  Future<Map<String, dynamic>> getProgress() async =>
      _asMap(await _send('GET', '/api/v1/revision/progress'));

  // --- Recitation sessions --------------------------------------------------

  /// Uploads one completed offline follow-along session.
  Future<Map<String, dynamic>> recordRecitationSession(
    Map<String, dynamic> body,
  ) async =>
      _asMap(await _send('POST', '/api/v1/recitation/sessions', body: body));

  Future<List<Map<String, dynamic>>> getRecitationSessions({
    int limit = 50,
  }) async =>
      _asList(await _send('GET', '/api/v1/recitation/sessions?limit=$limit'));

  // --- Reciter profile ------------------------------------------------------

  /// Mirrors the onboarding answers so they follow the reciter to another
  /// device. Replaces whatever is stored: the device is the source of truth.
  Future<void> putReciterProfile(Map<String, dynamic> body) async {
    await _send('PUT', '/api/v1/profile', body: body);
  }

  Future<Map<String, dynamic>> getReciterProfile() async =>
      _asMap(await _send('GET', '/api/v1/profile'));

  // --- Leaderboard ----------------------------------------------------------

  /// Standings. [scope] is `global` or `friends`.
  Future<Map<String, dynamic>> getLeaderboard({
    String scope = 'global',
    int limit = 10,
  }) async =>
      _asMap(await _send(
        'GET',
        '/api/v1/leaderboard?scope=$scope&limit=$limit',
      ));

  /// Follows another reciter by the address they signed up with.
  Future<void> addFriend(String email) async {
    await _send('POST', '/api/v1/leaderboard/friends', body: {'email': email});
  }

  Future<void> removeFriend(String friendUserId) async {
    await _send('DELETE', '/api/v1/leaderboard/friends/$friendUserId');
  }

  // --- Health ---------------------------------------------------------------

  Future<bool> healthCheck() async {
    try {
      await _send('GET', '/health', authenticated: false)
          .timeout(const Duration(seconds: 3));
      return true;
    } on Exception {
      return false;
    }
  }

  void close() => _http.close();

  // --- Plumbing -------------------------------------------------------------

  /// Sends a request, retrying once with a refreshed token on 401.
  Future<Object?> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    var response = await _dispatch(method, path, body, authenticated, null);

    if (response.statusCode == 401 && authenticated && _tokens != null) {
      final refreshed = await _tokens.refresh();
      if (refreshed != null) {
        response = await _dispatch(method, path, body, true, refreshed);
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, response.body);
    }
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  Future<http.Response> _dispatch(
    String method,
    String path,
    Map<String, dynamic>? body,
    bool authenticated,
    String? overrideToken,
  ) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{'Accept': 'application/json'};

    if (authenticated) {
      final token = overrideToken ?? await _tokens?.accessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final streamed = await _http.send(request).timeout(_timeout);
    return http.Response.fromStream(streamed);
  }

  static String _stripTrailingSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  static List<Map<String, dynamic>> _asList(Object? json) =>
      (json as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();

  static Map<String, dynamic> _asMap(Object? json) =>
      (json as Map<String, dynamic>?) ?? const {};
}
