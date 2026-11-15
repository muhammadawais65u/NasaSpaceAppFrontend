/// Values can be overridden at build time, for example:
/// flutter run -d chrome --dart-define=API_BASE=http://192.168.1.20:8000
class AppConfig {
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://localhost:8000',
  );

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://fkpgakudyqvqikkrgoth.supabase.co',
  );

  /// Public (anon) key. Safe to ship in the app; never put the service key here.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZrcGdha3VkeXF2cWlra3Jnb3RoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ2MzYzOTksImV4cCI6MjExMDIxMjM5OX0.O1B9aZKu0Li4Wt7AyYFpOsLMGSu5n2sA2bWEo7O75H8',
  );
}
