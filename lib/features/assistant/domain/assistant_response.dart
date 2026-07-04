enum AssistantResponseType {
  message,
  question,
  recommendation,
  comparison,
  photoAnalysis,
}

class AssistantResponse {
  const AssistantResponse({
    required this.type,
    required this.reply,
    required this.recommendedPackCode,
    required this.recommendedPackName,
    required this.alternativePackCode,
    required this.alternativePackName,
    required this.confidence,
    required this.reasons,
    required this.suggestedOptions,
    required this.followUpQuestion,
    required this.requiresHumanInspection,
  });

  final AssistantResponseType type;
  final String reply;
  final String recommendedPackCode;
  final String recommendedPackName;
  final String alternativePackCode;
  final String alternativePackName;
  final double confidence;
  final List<String> reasons;
  final List<String> suggestedOptions;
  final String followUpQuestion;
  final bool requiresHumanInspection;

  factory AssistantResponse.fromJson(Map<String, dynamic> json) {
    return AssistantResponse(
      type: _typeFromJson(json['type']),
      reply: json['reply'] as String? ?? '',
      recommendedPackCode: json['recommendedPackCode'] as String? ?? '',
      recommendedPackName: json['recommendedPackName'] as String? ?? '',
      alternativePackCode: json['alternativePackCode'] as String? ?? '',
      alternativePackName: json['alternativePackName'] as String? ?? '',
      confidence: (json['confidence'] as num? ?? 0).toDouble().clamp(0, 1),
      reasons: (json['reasons'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      suggestedOptions: (json['suggestedOptions'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      followUpQuestion: json['followUpQuestion'] as String? ?? '',
      requiresHumanInspection:
          json['requiresHumanInspection'] as bool? ?? false,
    );
  }
}

AssistantResponseType _typeFromJson(Object? value) {
  switch (value) {
    case 'question':
      return AssistantResponseType.question;
    case 'recommendation':
      return AssistantResponseType.recommendation;
    case 'comparison':
      return AssistantResponseType.comparison;
    case 'photo_analysis':
      return AssistantResponseType.photoAnalysis;
    default:
      return AssistantResponseType.message;
  }
}
