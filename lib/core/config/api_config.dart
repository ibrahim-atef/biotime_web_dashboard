class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'BIOTIME_API_URL',
    defaultValue: 'http://localhost:3000',
  );

  static const database = String.fromEnvironment(
    'BIOTIME_DB',
    defaultValue: '',
  );
}
