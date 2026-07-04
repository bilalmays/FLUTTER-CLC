class AppConstants {
  const AppConstants._();

  static const appName = 'Car Luxe Cleaning';
  static const appSubtitle = 'CRM premium';
  static const defaultApiBaseUrl = String.fromEnvironment(
    'CLC_API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  static const accessCode = String.fromEnvironment(
    'CLC_ACCESS_CODE',
    defaultValue: 'CLC',
  );

  /// Prototype only: use `--dart-define=GEMINI_API_KEY=...` when you
  /// want Flutter to call Gemini directly. Do not hardcode keys in source.
  static const geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AQ.Ab8RN6LlkIIuZvn74cybWLdblnf5N1RcuhL-1qrr3P4023tfWw',
  );

  static const geminiModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-2.5-flash',
  );
}
