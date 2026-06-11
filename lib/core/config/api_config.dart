class ApiConfig {
  /// Bump when shipping to GitHub Pages (shown in Settings for cache verification).
  static const appVersion = '1.0.1+2';

  static const baseUrl = String.fromEnvironment(
    'BIOTIME_API_URL',
    defaultValue: 'http://localhost:3000',
  );

  static const database = String.fromEnvironment(
    'BIOTIME_DB',
    defaultValue: '',
  );
}
