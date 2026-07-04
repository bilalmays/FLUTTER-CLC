# car_luxe_cleaning_flutter

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Assistant IA Gemini direct — prototype Flutter

Pour tester sans backend, lance l'application avec une clé transmise au runtime :

```bash
flutter run --dart-define=GEMINI_API_KEY=TA_CLE_DE_TEST
```

Options utiles :

```bash
flutter run \
  --dart-define=GEMINI_API_KEY=TA_CLE_DE_TEST \
  --dart-define=GEMINI_MODEL=gemini-2.5-flash
```

En production, ne compile pas une vraie clé dans l'application. Utilise plutôt une API sécurisée côté serveur avec `CLC_API_BASE_URL`.

Pour tester avec le backend TypeScript existant :

```bash
flutter run --dart-define=CLC_API_BASE_URL=http://10.0.2.2:3000
```

Sur iPad physique, remplace `localhost` par l'adresse IP du PC/Mac ou par une URL HTTPS.

## Voix iPad / Android

La version Flutter utilise maintenant :

- `flutter_tts` pour lire les réponses ;
- `speech_to_text` pour le microphone ;
- les voix françaises installées sur l'appareil ;
- une sélection automatique fr-BE/fr-FR lorsque disponible.

Sur iOS/iPadOS, les permissions micro et reconnaissance vocale sont déclarées dans `ios/Runner/Info.plist`.
