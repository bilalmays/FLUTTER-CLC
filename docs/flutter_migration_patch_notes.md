# Correctifs Flutter — parité TypeScript / iPad

Ce lot corrige une partie importante de la migration Flutter sans modifier le projet TypeScript parent.

## Assistant IA

- Ajout d'un mode Gemini direct pour prototype avec `--dart-define=GEMINI_API_KEY=...`.
- Conservation du backend `/api/gemini` lorsque la clé directe n'est pas fournie.
- Injection du catalogue Car Luxe Cleaning réel dans le prompt Gemini.
- Validation du pack recommandé pour empêcher les packs inexistants.
- Conservation des corrections métier locales dans le contexte de Gemini.
- Textes visibles corrigés avec accents.

## Voix iPad / Android

- Remplacement du stub natif par une vraie implémentation `flutter_tts` + `speech_to_text`.
- Sélection automatique d'une voix française fr-BE/fr-FR lorsque disponible.
- Nettoyage du texte avant lecture vocale.
- Ajout de `NSSpeechRecognitionUsageDescription` pour iOS/iPadOS.

## PDF

- Ajout d'un vrai QR code dans le devis.
- Ajout de l'intégration réelle des signatures PNG dans les PDF.
- Ajout de l'intégration réelle des photos dans l'état des lieux.
- Ajout d'une structure `DocumentPhoto` pour passer les images au générateur PDF.
- Extension du service pick-up pour inclure les signatures capturées.

## iPad / Safe area / Qualité

- `themeMode` passe à `ThemeMode.system`.
- Documentation ajoutée pour les URL backend sur Android emulator, iOS simulator et iPad physique.
- Plusieurs textes visibles ont été corrigés pour une finition plus premium.

## Reste à finaliser

- Persistance métier avec Drift/SQLite au lieu de `SharedPreferences`.
- Historique réel des PDF générés.
- Sélecteur de polissage partiel interactif côté Flutter.
- Portage complet des réglages avancés et de la corbeille TypeScript.
- Tests sur vrai iPad, en portrait, paysage et split view.
