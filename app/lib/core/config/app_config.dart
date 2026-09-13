/// Build-time configuration.
///
/// Override with `--dart-define`, e.g.
/// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5188`.
class AppConfig {
  const AppConfig._();

  /// Base URL of the Tilawa API.
  ///
  /// `10.0.2.2` is the host machine as seen from the Android emulator; iOS
  /// simulators and desktop builds reach it on `localhost`.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5188',
  );

  /// OAuth client id for Google Sign-In on iOS/macOS. Android resolves its own
  /// client from the signing certificate, so it may be left empty there.
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
  );

  /// The backend's Google client id. Required for the client to receive an ID
  /// token the API can verify.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  /// Service id registered with Apple, used for the Android/web Sign in with
  /// Apple flow. Native iOS does not need it.
  static const String appleServiceId = String.fromEnvironment(
    'APPLE_SERVICE_ID',
  );

  /// Redirect the Apple web flow returns to. Must match the service id's
  /// configured return URL.
  static const String appleRedirectUri = String.fromEnvironment(
    'APPLE_REDIRECT_URI',
  );

  /// Lets the app be opened without an account, for demos and for trying the
  /// offline features before committing to a sign-in.
  /// `--dart-define=ALLOW_GUEST=true`
  static const bool allowGuest =
      bool.fromEnvironment('ALLOW_GUEST', defaultValue: false);

  static bool get hasGoogleConfig => googleServerClientId.isNotEmpty;

  static bool get hasAppleWebConfig =>
      appleServiceId.isNotEmpty && appleRedirectUri.isNotEmpty;
}
