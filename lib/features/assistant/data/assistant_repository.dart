import 'dart:convert';

import 'package:car_luxe_cleaning_flutter/app/constants.dart';
import 'package:car_luxe_cleaning_flutter/core/api/api_client.dart';
import 'package:car_luxe_cleaning_flutter/core/errors/app_exception.dart';
import 'package:car_luxe_cleaning_flutter/features/assistant/domain/assistant_response.dart';
import 'package:car_luxe_cleaning_flutter/features/assistant/domain/chat_message.dart';
import 'package:car_luxe_cleaning_flutter/features/basket/data/service_catalog.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final assistantRepositoryProvider = Provider<AssistantRepository>((ref) {
  // Prototype: when a GEMINI_API_KEY is provided through --dart-define, Flutter
  // can call Gemini directly. For production, keep this empty and use the
  // secured backend /api/gemini route instead.
  if (AppConstants.geminiApiKey.trim().isNotEmpty) {
    return DirectGeminiAssistantRepository(Dio());
  }
  return RemoteAssistantRepository(ref.watch(apiClientProvider));
});

abstract class AssistantRepository {
  Future<AssistantResponse> sendMessage({
    required String message,
    required List<ChatImage> images,
    required List<ChatMessage> history,
    List<Map<String, dynamic>> corrections = const [],
  });
}

class RemoteAssistantRepository implements AssistantRepository {
  const RemoteAssistantRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<AssistantResponse> sendMessage({
    required String message,
    required List<ChatImage> images,
    required List<ChatMessage> history,
    List<Map<String, dynamic>> corrections = const [],
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/api/gemini',
        data: {
          'message': message,
          'images': images.map((image) => image.toRequestJson()).toList(),
          'history': _historyToJson(history),
          'corrections': corrections,
        },
      );

      final payload = response.data;
      final assistantPayload = payload?['response'];
      if (assistantPayload is! Map<String, dynamic>) {
        throw const AppException("La réponse de l'assistant est invalide.");
      }
      return _validatedResponse(assistantPayload);
    } on DioException catch (error) {
      final data = error.response?.data;
      if (data is Map && data['error'] is String) {
        throw AppException(data['error'] as String, cause: error);
      }
      throw AppException(
        "L'assistant est temporairement indisponible.",
        cause: error,
      );
    }
  }
}

class DirectGeminiAssistantRepository implements AssistantRepository {
  DirectGeminiAssistantRepository(this._dio);

  final Dio _dio;

  @override
  Future<AssistantResponse> sendMessage({
    required String message,
    required List<ChatImage> images,
    required List<ChatMessage> history,
    List<Map<String, dynamic>> corrections = const [],
  }) async {
    final apiKey = AppConstants.geminiApiKey.trim();
    if (apiKey.isEmpty) {
      throw const AppException(
        'Clé Gemini absente. Lance Flutter avec --dart-define=GEMINI_API_KEY=...',
      );
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'https://generativelanguage.googleapis.com/v1beta/models/${AppConstants.geminiModel}:generateContent',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          sendTimeout: const Duration(seconds: 35),
          receiveTimeout: const Duration(seconds: 45),
        ),
        data: {
          'systemInstruction': {
            'parts': [
              {'text': _buildSystemPrompt(corrections)},
            ],
          },
          'contents': [
            ..._historyToGemini(history),
            {
              'role': 'user',
              'parts': [
                {'text': message},
                ...images.map(
                  (image) => {
                    'inlineData': {
                      'mimeType': image.mimeType,
                      'data': image.base64,
                    },
                  },
                ),
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.2,
            'responseMimeType': 'application/json',
          },
        },
      );

      final rawText = _extractGeminiText(response.data);
      final decoded = jsonDecode(_stripJsonFence(rawText));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Gemini did not return an object.');
      }
      return _validatedResponse(decoded);
    } on DioException catch (error) {
      final code = error.response?.statusCode;
      final message = code == 429
          ? 'Le quota Gemini de test semble atteint. Réessaie plus tard.'
          : "L'assistant Gemini direct est indisponible.";
      throw AppException(message, cause: error);
    } on FormatException catch (error) {
      throw AppException(
        "La réponse reçue n'a pas pu être interprétée.",
        cause: error,
      );
    }
  }
}

List<Map<String, dynamic>> _historyToJson(List<ChatMessage> history) {
  return history
      .where((item) => item.text.trim().isNotEmpty)
      .toList()
      .reversed
      .take(10)
      .toList()
      .reversed
      .map(
        (item) => {
          'role': item.role == ChatRole.user ? 'user' : 'assistant',
          'text': item.text,
        },
      )
      .toList();
}

List<Map<String, dynamic>> _historyToGemini(List<ChatMessage> history) {
  return _historyToJson(history).map((item) {
    final role = item['role'] == 'assistant' ? 'model' : 'user';
    return {
      'role': role,
      'parts': [
        {'text': item['text']},
      ],
    };
  }).toList();
}

String _extractGeminiText(Map<String, dynamic>? payload) {
  final candidates = payload?['candidates'];
  if (candidates is! List || candidates.isEmpty) {
    throw const FormatException('No candidates.');
  }
  final first = candidates.first;
  if (first is! Map<String, dynamic>) {
    throw const FormatException('Invalid candidate.');
  }
  final content = first['content'];
  if (content is! Map<String, dynamic>) {
    throw const FormatException('Invalid content.');
  }
  final parts = content['parts'];
  if (parts is! List || parts.isEmpty) {
    throw const FormatException('No parts.');
  }
  final text = (parts.first as Map?)?['text'];
  if (text is! String || text.trim().isEmpty) {
    throw const FormatException('Empty text.');
  }
  return text;
}

String _stripJsonFence(String value) {
  var text = value.trim();
  if (text.startsWith('```')) {
    text = text.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
    text = text.replaceFirst(RegExp(r'\s*```$'), '');
  }
  return text.trim();
}

AssistantResponse _validatedResponse(Map<String, dynamic> json) {
  final response = AssistantResponse.fromJson(json);
  final allowedCodes = _allowedPackCodes;
  if (response.recommendedPackCode.isNotEmpty &&
      !allowedCodes.contains(response.recommendedPackCode)) {
    return AssistantResponse(
      type: AssistantResponseType.question,
      reply: response.reply.isNotEmpty
          ? response.reply
          : 'Je dois vérifier quelques informations avant de recommander un pack.',
      recommendedPackCode: '',
      recommendedPackName: '',
      alternativePackCode: '',
      alternativePackName: '',
      confidence: 0,
      reasons: response.reasons,
      suggestedOptions: response.suggestedOptions,
      followUpQuestion: response.followUpQuestion.isNotEmpty
          ? response.followUpQuestion
          : 'Souhaitez-vous traiter surtout l’intérieur, l’extérieur, ou les deux ?',
      requiresHumanInspection: response.requiresHumanInspection,
    );
  }
  return response;
}

Set<String> get _allowedPackCodes => {
  for (final category in officialServiceCategories)
    for (final service in category.services) service.id,
};

String _buildSystemPrompt(List<Map<String, dynamic>> corrections) {
  final catalog = officialServiceCategories
      .map(
        (category) => {
          'categoryId': category.id,
          'category': category.label,
          'services': category.services
              .map(
                (service) => {
                  'code': service.id,
                  'name': service.label,
                  'priceS': service.price.resolve(CatalogVehicleSize.s),
                  'priceM': service.price.resolve(CatalogVehicleSize.m),
                  'priceL': service.price.resolve(CatalogVehicleSize.l),
                },
              )
              .toList(),
        },
      )
      .toList();

  final approvedCorrections = corrections
      .where((item) => item['status'] == 'approved')
      .where((item) => item['reusableRule'] != false)
      .take(8)
      .toList();

  return '''
Tu es l'assistant officiel de Car Luxe Cleaning.

Mission : conseiller les clients sur les services de lavage, detailing,
polissage, céramique, reconditionnement et suppléments.

Règles obligatoires :
- réponds dans la langue du client ;
- recommande uniquement un service dont le code existe dans le catalogue ;
- n'invente jamais de prix, durée, disponibilité, promotion ou service ;
- les prix viennent uniquement du catalogue transmis ;
- pose une seule question courte si les informations sont insuffisantes ;
- l'analyse des photos reste indicative et doit être confirmée à l'inspection ;
- ne promets jamais qu'une tache, odeur ou rayure disparaîtra totalement ;
- ne confirme jamais un rendez-vous ou paiement.

Retourne uniquement ce JSON, sans Markdown :
{
  "type": "message | question | recommendation | comparison | photo_analysis",
  "reply": "texte clair pour le client",
  "recommendedPackCode": "code exact du catalogue ou chaîne vide",
  "recommendedPackName": "nom exact ou chaîne vide",
  "alternativePackCode": "code exact ou chaîne vide",
  "alternativePackName": "nom exact ou chaîne vide",
  "confidence": 0.0,
  "reasons": ["raison utile"],
  "suggestedOptions": ["option utile"],
  "followUpQuestion": "une question courte ou chaîne vide",
  "requiresHumanInspection": false
}

CATALOGUE AUTORISÉ :
${jsonEncode(catalog)}

CORRECTIONS MÉTIER VALIDÉES :
${jsonEncode(approvedCorrections)}
''';
}
