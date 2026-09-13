import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:tilawa/core/config/app_config.dart';
import 'package:tilawa/data/datasources/api_client.dart';
import 'package:tilawa/data/datasources/auth_api_client.dart';
import 'package:tilawa/data/datasources/auth_session_store.dart';
import 'package:tilawa/services/database_service.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';

/// Sign-in failure with a message safe to show the user.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthState {
  const AuthState({
    this.session,
    this.isGuest = false,
    this.isLoading = true,
    this.isSigningIn = false,
    this.error,
  });

  final AuthSession? session;

  /// Using the app without an account. Everything stays on the device; nothing
  /// syncs until the user signs in.
  final bool isGuest;

  final bool isLoading;
  final bool isSigningIn;
  final String? error;

  static const AuthUser guestUser = AuthUser(
    id: 'guest',
    email: '',
    displayName: 'Guest',
    provider: 'guest',
  );

  AuthUser? get user => session?.user ?? (isGuest ? guestUser : null);

  bool get isSignedIn => session != null;

  /// Whether the app should open, whether or not there is an account behind it.
  bool get isAuthenticated => isSignedIn || isGuest;

  AuthState copyWith({
    AuthSession? session,
    bool clearSession = false,
    bool? isGuest,
    bool? isLoading,
    bool? isSigningIn,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      session: clearSession ? null : (session ?? this.session),
      isGuest: isGuest ?? this.isGuest,
      isLoading: isLoading ?? this.isLoading,
      isSigningIn: isSigningIn ?? this.isSigningIn,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Owns the signed-in session.
///
/// Sign-in is federated only — Google or Apple. The app receives an identity
/// token from the provider, hands it to the API, and stores the Tilawa session
/// the API issues in return. No password ever passes through the client.
class AuthNotifier extends StateNotifier<AuthState> implements AuthTokenSource {
  AuthNotifier({
    required AuthApiClient api,
    AuthSessionStore? store,
    GoogleSignIn? googleSignIn,
  })  : _api = api,
        _store = store ?? AuthSessionStore(),
        _google = googleSignIn ?? GoogleSignIn.instance,
        super(const AuthState()) {
    unawaited(_restore());
  }

  final AuthApiClient _api;
  final AuthSessionStore _store;
  final GoogleSignIn _google;
  final DatabaseService _database = DatabaseService();

  static const String _guestSettingKey = 'auth.guest';

  bool _googleInitialized = false;
  Future<AuthSession?>? _inFlightRefresh;

  /// Apple's own sign-in button is only offered where Apple provides it
  /// natively, or where a web redirect has been configured.
  bool get isAppleAvailable {
    if (kIsWeb) return AppConfig.hasAppleWebConfig;
    // `defaultTargetPlatform` rather than `dart:io`, so this file still
    // compiles for the web build.
    final platform = defaultTargetPlatform;
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      return true;
    }
    return AppConfig.hasAppleWebConfig;
  }

  /// True when this build offers to open without an account.
  bool get allowsGuest => AppConfig.allowGuest;

  Future<void> _restore() async {
    final stored = await _store.read();
    if (stored == null) {
      final wasGuest = await _database.getSetting(_guestSettingKey) == 'true';
      state = state.copyWith(isLoading: false, isGuest: wasGuest);
      return;
    }

    if (!stored.isExpired) {
      state = state.copyWith(session: stored, isLoading: false);
      return;
    }

    // Expired on launch: try once to renew before showing the sign-in screen.
    try {
      final renewed = await _api.refresh(stored.refreshToken);
      await _store.write(renewed);
      state = state.copyWith(session: renewed, isLoading: false);
    } on Exception catch (error) {
      debugPrint('Stored session could not be renewed: $error');
      await _store.clear();
      state = const AuthState(isLoading: false);
    }
  }

  Future<void> signInWithGoogle() async {
    await _signIn(() async {
      if (!AppConfig.hasGoogleConfig) {
        throw const AuthFailure(
          'Google Sign-In is not configured for this build.',
        );
      }

      if (!_googleInitialized) {
        await _google.initialize(
          clientId: AppConfig.googleClientId.isEmpty
              ? null
              : AppConfig.googleClientId,
          serverClientId: AppConfig.googleServerClientId,
        );
        _googleInitialized = true;
      }

      final account = await _google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthFailure(
          'Google did not return an identity token. Check the server client id.',
        );
      }

      return _api.signIn(
        provider: AuthProviderKind.google,
        identityToken: idToken,
        displayName: account.displayName,
      );
    });
  }

  Future<void> signInWithApple() async {
    await _signIn(() async {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: AppConfig.hasAppleWebConfig
            ? WebAuthenticationOptions(
                clientId: AppConfig.appleServiceId,
                redirectUri: Uri.parse(AppConfig.appleRedirectUri),
              )
            : null,
      );

      final identityToken = credential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        throw const AuthFailure('Apple did not return an identity token.');
      }

      // Apple sends the name only on the first authorization, so pass it
      // through when it is there and let the API keep whatever it already has.
      final name = [credential.givenName, credential.familyName]
          .whereType<String>()
          .where((part) => part.isNotEmpty)
          .join(' ');

      return _api.signIn(
        provider: AuthProviderKind.apple,
        identityToken: identityToken,
        authorizationCode: credential.authorizationCode,
        displayName: name.isEmpty ? null : name,
      );
    });
  }

  Future<void> signOut() async {
    final session = state.session;
    state = state.copyWith(isLoading: true, clearError: true);

    if (session != null) {
      try {
        await _api.signOut(session.refreshToken);
      } on Exception catch (error) {
        // Revoking server-side is best effort; the local session goes either
        // way so the user is never stuck signed in.
        debugPrint('Server sign-out failed: $error');
      }
    }
    if (_googleInitialized) {
      try {
        await _google.signOut();
      } on Exception catch (error) {
        debugPrint('Google sign-out failed: $error');
      }
    }

    await _store.clear();
    await _database.deleteSetting(_guestSettingKey);
    state = const AuthState(isLoading: false);
  }

  /// Opens the app with no account. Progress is kept on the device only.
  Future<void> continueAsGuest() async {
    if (!AppConfig.allowGuest) return;
    await _database.saveSetting(_guestSettingKey, 'true');
    state = const AuthState(isGuest: true, isLoading: false);
  }

  void clearError() => state = state.copyWith(clearError: true);

  Future<void> _signIn(Future<AuthSession> Function() run) async {
    if (state.isSigningIn) return;
    state = state.copyWith(isSigningIn: true, clearError: true);
    try {
      final session = await run();
      await _store.write(session);
      state = AuthState(session: session, isLoading: false);
    } on AuthFailure catch (failure) {
      state = state.copyWith(isSigningIn: false, error: failure.message);
    } on SignInWithAppleAuthorizationException catch (error) {
      state = state.copyWith(
        isSigningIn: false,
        // A user-cancelled dialog is not an error worth reporting.
        error: error.code == AuthorizationErrorCode.canceled
            ? null
            : 'Sign in with Apple failed: ${error.message}',
        clearError: error.code == AuthorizationErrorCode.canceled,
      );
    } on GoogleSignInException catch (error) {
      state = state.copyWith(
        isSigningIn: false,
        error: error.code == GoogleSignInExceptionCode.canceled
            ? null
            : 'Google sign-in failed: ${error.description ?? error.code.name}',
        clearError: error.code == GoogleSignInExceptionCode.canceled,
      );
    } on ApiException catch (error) {
      state = state.copyWith(
        isSigningIn: false,
        error: error.statusCode == 401
            ? 'The server rejected that account.'
            : 'Sign-in failed (HTTP ${error.statusCode}).',
      );
    } on Exception catch (error) {
      state = state.copyWith(
        isSigningIn: false,
        error: 'Sign-in failed: $error',
      );
    }
  }

  // --- AuthTokenSource ------------------------------------------------------

  @override
  Future<String?> accessToken() async {
    final session = state.session;
    if (session == null) return null;
    if (!session.isExpired) return session.accessToken;
    return (await _refreshSession())?.accessToken;
  }

  @override
  Future<String?> refresh() async => (await _refreshSession())?.accessToken;

  /// Renews the session, collapsing concurrent callers onto one request so a
  /// burst of 401s cannot spend the refresh token more than once.
  Future<AuthSession?> _refreshSession() {
    return _inFlightRefresh ??= () async {
      try {
        final current = state.session;
        if (current == null) return null;
        final renewed = await _api.refresh(current.refreshToken);
        await _store.write(renewed);
        state = state.copyWith(session: renewed);
        return renewed;
      } on Exception catch (error) {
        debugPrint('Session refresh failed: $error');
        await _store.clear();
        state = const AuthState(isLoading: false);
        return null;
      } finally {
        _inFlightRefresh = null;
      }
    }();
  }
}

final authApiClientProvider = Provider<AuthApiClient>((ref) {
  final client = AuthApiClient(
    baseUrl: ref.watch(appSettingsProvider.select((s) => s.serverUrl)),
  );
  ref.onDispose(client.close);
  return client;
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(api: ref.watch(authApiClientProvider));
});

/// Token source handed to [TilawaApiClient] so API calls carry the session.
final authTokenSourceProvider = Provider<AuthTokenSource>((ref) {
  return ref.watch(authProvider.notifier);
});
