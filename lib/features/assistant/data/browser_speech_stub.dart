import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

typedef TranscriptCallback = void Function(String text);
typedef SpeechStateCallback = void Function();

const _selectedVoiceKey = 'car_luxe_cleaning.voice.selected.v1';
const _premiumVoiceKeywords = [
  'natural',
  'neural',
  'premium',
  'enhanced',
  'siri',
  'google',
  'microsoft',
  'samsung',
];
const _roboticVoiceKeywords = ['compact', 'legacy', 'eloquence'];

/// Native iOS/Android/macOS/Windows implementation used by the existing
/// assistant UI. The class keeps the historical name so web and native can be
/// swapped through the conditional export in `browser_speech.dart`.
class BrowserSpeechController {
  BrowserSpeechController({
    required this.onTranscript,
    required this.onStateChanged,
  });

  final TranscriptCallback onTranscript;
  final SpeechStateCallback onStateChanged;

  final FlutterTts _tts = FlutterTts();
  final SpeechToText _recognition = SpeechToText();

  bool _initialized = false;
  bool _recognitionReady = false;
  bool _listening = false;
  String? _speakingMessageId;
  String? _error;
  Map<String, String>? _selectedVoice;
  List<Map<String, dynamic>> _voices = const [];

  bool get speechSupported => true;
  bool get recognitionSupported => _recognitionReady;
  bool get isListening => _listening;
  bool get isSpeaking => _speakingMessageId != null;
  String? get speakingMessageId => _speakingMessageId;
  String? get error => _error;
  String get selectedVoiceLabel {
    final voice = _selectedVoice;
    if (voice == null) return 'Voix française automatique';
    return [
      voice['name'],
      voice['locale'],
    ].where((value) => value != null && value.trim().isNotEmpty).join(' - ');
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.92);
    await _tts.setPitch(0.98);
    await _tts.setVolume(1.0);

    _tts.setCompletionHandler(() {
      _speakingMessageId = null;
      onStateChanged();
    });
    _tts.setCancelHandler(() {
      _speakingMessageId = null;
      onStateChanged();
    });
    _tts.setErrorHandler((message) {
      _speakingMessageId = null;
      _error = 'Lecture vocale interrompue.';
      onStateChanged();
    });

    _voices = await _loadVoices();
    _selectedVoice = await _loadSavedVoice() ?? _findBestFrenchVoice();
    final voice = _selectedVoice;
    if (voice != null) {
      await _tts.setVoice(voice);
    }

    _recognitionReady = await _recognition.initialize(
      onStatus: _handleSpeechStatus,
      onError: _handleSpeechError,
      debugLogging: false,
    );
    onStateChanged();
  }

  Future<List<Map<String, dynamic>>> _loadVoices() async {
    try {
      final rawVoices = await _tts.getVoices;
      if (rawVoices is! List) return const [];
      return rawVoices
          .whereType<Map>()
          .map((voice) => Map<String, dynamic>.from(voice))
          .where((voice) {
            final name = '${voice['name'] ?? ''}'.trim();
            final locale = '${voice['locale'] ?? ''}'.trim();
            return name.isNotEmpty && locale.isNotEmpty;
          })
          .toList();
    } catch (error) {
      debugPrint('Voice loading failed: $error');
      return const [];
    }
  }

  Future<Map<String, String>?> _loadSavedVoice() async {
    final preferences = await SharedPreferences.getInstance();
    final name = preferences.getString('$_selectedVoiceKey.name');
    final locale = preferences.getString('$_selectedVoiceKey.locale');
    if (name == null || locale == null) return null;
    final exists = _voices.any(
      (voice) => voice['name'] == name && voice['locale'] == locale,
    );
    if (!exists) return null;
    return {'name': name, 'locale': locale};
  }

  Map<String, String>? _findBestFrenchVoice() {
    if (_voices.isEmpty) return null;
    final frenchVoices = _voices.where((voice) {
      final locale = '${voice['locale'] ?? ''}'.toLowerCase();
      final name = '${voice['name'] ?? ''}'.toLowerCase();
      return locale.startsWith('fr') ||
          name.contains('french') ||
          name.contains('français') ||
          name.contains('france');
    }).toList();

    final candidates = frenchVoices.isEmpty ? _voices : frenchVoices;
    candidates.sort((a, b) => _scoreVoice(b).compareTo(_scoreVoice(a)));
    final selected = candidates.first;
    return {'name': '${selected['name']}', 'locale': '${selected['locale']}'};
  }

  int _scoreVoice(Map<String, dynamic> voice) {
    final name = '${voice['name'] ?? ''}'.toLowerCase();
    final locale = '${voice['locale'] ?? ''}'.toLowerCase();
    var score = 0;
    if (locale == 'fr-be') score += 120;
    if (locale == 'fr-fr') score += 110;
    if (locale.startsWith('fr')) score += 90;
    for (final keyword in _premiumVoiceKeywords) {
      if (name.contains(keyword)) score += 28;
    }
    for (final keyword in _roboticVoiceKeywords) {
      if (name.contains(keyword)) score -= 50;
    }
    return score;
  }

  Future<void> speak({
    required String messageId,
    required String text,
    String language = 'fr-BE',
  }) async {
    await initialize();
    final cleaned = _cleanSpeechText(text);
    if (cleaned.isEmpty) return;
    stopListening(notify: false);
    await stopSpeaking(notify: false);
    _speakingMessageId = messageId;
    _error = null;
    final voice = _selectedVoice;
    if (voice != null) {
      await _tts.setVoice(voice);
    } else {
      await _tts.setLanguage(language);
    }
    onStateChanged();
    await _tts.speak(cleaned);
  }

  Future<void> stopSpeaking({bool notify = true}) async {
    await _tts.stop();
    _speakingMessageId = null;
    if (notify) onStateChanged();
  }

  Future<void> toggleListening({String language = 'fr-BE'}) async {
    await initialize();
    if (_listening) {
      stopListening();
      return;
    }
    if (!_recognitionReady) {
      _error = 'Reconnaissance vocale non disponible sur cet appareil.';
      onStateChanged();
      return;
    }
    await stopSpeaking(notify: false);
    _listening = true;
    _error = null;
    onStateChanged();
    await _recognition.listen(
      onResult: _handleSpeechResult,
      listenOptions: SpeechListenOptions(
        localeId: language,
        listenFor: const Duration(seconds: 14),
        pauseFor: const Duration(seconds: 3),
        partialResults: false,
        cancelOnError: true,
      ),
    );
  }

  void _handleSpeechResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords.trim();
    if (words.isNotEmpty && result.finalResult) {
      onTranscript(words);
    }
  }

  void _handleSpeechStatus(String status) {
    if (status == 'done' || status == 'notListening') {
      _listening = false;
      onStateChanged();
    }
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    _listening = false;
    _error = error.permanent
        ? 'Permission micro refusée ou reconnaissance vocale indisponible.'
        : 'Je n’ai pas bien compris. Réessaie avec une phrase courte.';
    onStateChanged();
  }

  void stopListening({bool notify = true}) {
    if (_recognition.isListening) {
      _recognition.stop();
    }
    _listening = false;
    if (notify) onStateChanged();
  }

  Future<void> dispose() async {
    await stopSpeaking(notify: false);
    stopListening(notify: false);
  }
}

String _cleanSpeechText(String text) {
  return text
      .replaceAll(RegExp(r'https?:\/\/\S+'), '')
      .replaceAll(RegExp(r'```[\s\S]*?```'), '')
      .replaceAll(RegExp(r'[`*_#>|\[\]{}]'), '')
      .replaceAll(RegExp(r'\bEUR\b'), 'euros')
      .replaceAll(RegExp(r'\bkm\b', caseSensitive: false), 'kilomètres')
      .replaceAll(RegExp(r'\bHTVA\b'), 'hors TVA')
      .replaceAll(RegExp(r'\bTVAC\b'), 'TVA comprise')
      .replaceAll(RegExp(r'\bPDF\b'), 'P D F')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
