// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

typedef TranscriptCallback = void Function(String text);
typedef SpeechStateCallback = void Function();

const _premiumVoiceKeywords = ['natural', 'neural', 'premium', 'online'];
const _preferredVoiceNames = [
  'apple',
  'siri',
  'amelie',
  'audrey',
  'thomas',
  'microsoft denise online',
  'microsoft henri online',
  'microsoft eloise online',
  'microsoft vivienne online',
  'microsoft remy online',
  'google fran',
  'google francais',
  'google fr',
  'google nederlands',
  'xander',
  'claire',
];
const _roboticVoiceKeywords = ['compact', 'desktop', 'legacy', 'eloquence'];

class BrowserSpeechController {
  BrowserSpeechController({
    required this.onTranscript,
    required this.onStateChanged,
  });

  final TranscriptCallback onTranscript;
  final SpeechStateCallback onStateChanged;

  html.SpeechRecognition? _recognition;
  StreamSubscription<html.SpeechRecognitionEvent>? _resultSubscription;
  StreamSubscription<html.SpeechRecognitionError>? _errorSubscription;
  StreamSubscription<html.Event>? _endSubscription;
  int _speechRunId = 0;

  bool _listening = false;
  String? _speakingMessageId;
  String? _error;
  html.SpeechSynthesisVoice? _selectedVoice;

  bool get speechSupported => html.window.speechSynthesis != null;
  bool get recognitionSupported => html.SpeechRecognition.supported;
  bool get isListening => _listening;
  bool get isSpeaking => _speakingMessageId != null;
  String? get speakingMessageId => _speakingMessageId;
  String? get error => _error;
  String get selectedVoiceLabel {
    final voice = _selectedVoice;
    if (voice == null) {
      return speechSupported ? 'Voix automatique' : 'Voix non disponible';
    }
    return [voice.name, voice.lang].whereType<String>().join(' - ');
  }

  Future<void> initialize() async {
    _selectedVoice = _findBestVoice('fr-BE');
    Timer(const Duration(milliseconds: 450), () {
      _selectedVoice = _findBestVoice('fr-BE');
      onStateChanged();
    });
    Timer(const Duration(milliseconds: 1400), () {
      _selectedVoice = _findBestVoice('fr-BE');
      onStateChanged();
    });
    onStateChanged();
  }

  void speak({
    required String messageId,
    required String text,
    String language = 'fr-BE',
  }) {
    final synthesis = html.window.speechSynthesis;
    if (synthesis == null) {
      _error = 'Lecture vocale non disponible sur ce navigateur.';
      onStateChanged();
      return;
    }

    final chunks = _buildSpeechChunks(text);
    if (chunks.isEmpty) return;

    stopSpeaking(notify: false);
    final runId = ++_speechRunId;
    _speakingMessageId = messageId;
    _error = null;
    _selectedVoice = _findBestVoice(language);
    onStateChanged();

    void speakChunk(int index) {
      if (_speechRunId != runId) return;
      if (index >= chunks.length) {
        _speakingMessageId = null;
        onStateChanged();
        return;
      }

      final utterance = html.SpeechSynthesisUtterance(chunks[index]);
      final voice = _selectedVoice;
      utterance.lang = voice?.lang ?? language;
      utterance.voice = voice;
      final settings = _speechSettingsForVoice(voice);
      utterance.rate = settings.rate;
      utterance.pitch = settings.pitch;
      utterance.volume = 1;
      utterance.onEnd.listen((_) {
        if (_speechRunId != runId) return;
        Timer(const Duration(milliseconds: 70), () => speakChunk(index + 1));
      });
      utterance.onError.listen((_) {
        if (_speechRunId != runId) return;
        _speakingMessageId = null;
        _error = 'Lecture vocale interrompue.';
        onStateChanged();
      });
      synthesis.speak(utterance);
    }

    speakChunk(0);
  }

  void stopSpeaking({bool notify = true}) {
    _speechRunId += 1;
    html.window.speechSynthesis?.cancel();
    _speakingMessageId = null;
    if (notify) onStateChanged();
  }

  void toggleListening({String language = 'fr-BE'}) {
    if (_listening) {
      stopListening();
      return;
    }
    _startListening(language);
  }

  void _startListening(String language) {
    if (!recognitionSupported) {
      _error =
          "La reconnaissance vocale n'est pas disponible sur ce navigateur.";
      onStateChanged();
      return;
    }

    stopSpeaking();
    stopListening(notify: false);

    final recognition = html.SpeechRecognition()
      ..lang = language
      ..interimResults = true
      ..continuous = false
      ..maxAlternatives = 1;

    _recognition = recognition;
    _listening = true;
    _error = null;
    onStateChanged();

    _resultSubscription = recognition.onResult.listen((event) {
      final results = event.results;
      if (results == null) return;
      final buffer = StringBuffer();
      final start = event.resultIndex ?? 0;
      for (var index = start; index < results.length; index += 1) {
        final result = results[index];
        if (result.isFinal != true) continue;
        final alternative = result.item(0);
        final transcript = alternative.transcript?.trim();
        if (transcript != null && transcript.isNotEmpty) {
          buffer.write(' ');
          buffer.write(transcript);
        }
      }
      final transcript = buffer.toString().trim();
      if (transcript.isNotEmpty) onTranscript(transcript);
    });

    _errorSubscription = recognition.onError.listen((event) {
      _error = event.error == 'not-allowed'
          ? 'Permission micro refusee.'
          : 'Le micro est indisponible.';
      _listening = false;
      onStateChanged();
    });

    _endSubscription = recognition.onEnd.listen((_) {
      _listening = false;
      onStateChanged();
    });

    try {
      recognition.start();
    } catch (_) {
      _error = 'Le micro est deja actif ou indisponible.';
      _listening = false;
      onStateChanged();
    }
  }

  void stopListening({bool notify = true}) {
    _resultSubscription?.cancel();
    _errorSubscription?.cancel();
    _endSubscription?.cancel();
    _resultSubscription = null;
    _errorSubscription = null;
    _endSubscription = null;
    try {
      _recognition?.stop();
    } catch (_) {
      try {
        _recognition?.abort();
      } catch (_) {}
    }
    _recognition = null;
    _listening = false;
    if (notify) onStateChanged();
  }

  void dispose() {
    stopSpeaking(notify: false);
    stopListening(notify: false);
  }

  html.SpeechSynthesisVoice? _findBestVoice(String language) {
    final voices = html.window.speechSynthesis?.getVoices() ?? const [];
    final target = language.toLowerCase().substring(0, 2);
    final matching = voices.where((voice) {
      final lang = (voice.lang ?? '').toLowerCase();
      return lang.startsWith(target);
    }).toList();
    if (matching.isEmpty) return voices.isEmpty ? null : voices.first;
    matching.sort((a, b) {
      final score = _scoreVoice(b, language) - _scoreVoice(a, language);
      if (score != 0) return score;
      return (a.name ?? '').compareTo(b.name ?? '');
    });
    return matching.first;
  }

  int _scoreVoice(html.SpeechSynthesisVoice voice, String language) {
    final target = language.toLowerCase().substring(0, 2);
    final lang = (voice.lang ?? '').toLowerCase();
    final name = (voice.name ?? '').toLowerCase();
    var score = 0;

    if (lang == language.toLowerCase()) score += 35;
    if (lang.startsWith(target)) score += 45;
    for (final preferred in _preferredVoiceNames) {
      if (name.contains(preferred)) score += 90;
    }
    for (final keyword in _premiumVoiceKeywords) {
      if (name.contains(keyword)) score += 36;
    }
    if (name.contains('microsoft') ||
        name.contains('google') ||
        name.contains('apple') ||
        name.contains('siri')) {
      score += 16;
    }
    if (voice.localService == true) score += 3;
    for (final keyword in _roboticVoiceKeywords) {
      if (name.contains(keyword)) score -= 45;
    }
    return score;
  }
}

({double rate, double pitch}) _speechSettingsForVoice(
  html.SpeechSynthesisVoice? voice,
) {
  final name = (voice?.name ?? '').toLowerCase();
  final premium =
      _premiumVoiceKeywords.any(name.contains) ||
      name.contains('apple') ||
      name.contains('siri');
  return (rate: premium ? 0.92 : 0.86, pitch: premium ? 0.98 : 0.94);
}

List<String> _buildSpeechChunks(String text) {
  final cleaned = _cleanSpeechText(text);
  if (cleaned.isEmpty) return const [];
  final matches = RegExp(r'[^.!?;:]+[.!?;:]?').allMatches(cleaned);
  final sentences = matches
      .map((match) => match.group(0)?.trim() ?? '')
      .where((part) => part.isNotEmpty);
  final chunks = <String>[];

  for (final sentence in sentences) {
    final previous = chunks.isEmpty ? '' : chunks.last;
    if (previous.isNotEmpty && '$previous $sentence'.length <= 220) {
      chunks[chunks.length - 1] = '$previous $sentence';
      continue;
    }
    if (sentence.length <= 220) {
      chunks.add(sentence);
      continue;
    }
    var current = '';
    for (final word in sentence.split(RegExp(r'\s+'))) {
      final next = current.isEmpty ? word : '$current $word';
      if (next.length > 220 && current.isNotEmpty) {
        chunks.add(current);
        current = word;
      } else {
        current = next;
      }
    }
    if (current.isNotEmpty) chunks.add(current);
  }

  return chunks;
}

String _cleanSpeechText(String text) {
  return text
      .replaceAll(RegExp(r'https?:\/\/\S+'), '')
      .replaceAll(RegExp(r'[`*_#>|[\]{}]'), '')
      .replaceAll(RegExp(r'\bEUR\b'), 'euros')
      .replaceAll(RegExp(r'\bkm\b', caseSensitive: false), 'kilometres')
      .replaceAll(RegExp(r'\bHTVA\b'), 'hors TVA')
      .replaceAll(RegExp(r'\bTVAC\b'), 'TVA comprise')
      .replaceAll(RegExp(r'\bPDF\b'), 'P D F')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
