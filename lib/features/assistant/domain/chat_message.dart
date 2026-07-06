import 'dart:convert';

import 'package:car_luxe_cleaning_flutter/features/assistant/domain/assistant_response.dart';

enum ChatRole { user, assistant }

class ChatImage {
  const ChatImage({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.base64,
    required this.bytes,
  });

  final String id;
  final String fileName;
  final String mimeType;
  final String base64;
  final List<int> bytes;

  Map<String, dynamic> toRequestJson() => {
    'fileName': fileName,
    'mimeType': mimeType,
    'base64': base64,
  };

  factory ChatImage.fromJson(Map<String, dynamic> json) {
    final encoded = json['base64'] as String? ?? '';
    return ChatImage(
      id: json['id'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      mimeType: json['mimeType'] as String? ?? 'image/jpeg',
      base64: encoded,
      bytes: _decodeBase64(encoded),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    'mimeType': mimeType,
    'base64': base64,
  };
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.images = const [],
    this.recommendation,
    this.isError = false,
  });

  final String id;
  final ChatRole role;
  final String text;
  final DateTime createdAt;
  final List<ChatImage> images;
  final AssistantResponse? recommendation;
  final bool isError;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final imagesJson = json['images'];
    final recommendationJson = json['recommendation'];
    return ChatMessage(
      id: json['id'] as String? ?? '',
      role: _chatRoleFromJson(json['role']),
      text: json['text'] as String? ?? '',
      createdAt: _dateFromJson(json['createdAt']),
      images: imagesJson is List
          ? imagesJson
                .whereType<Map<String, dynamic>>()
                .map(ChatImage.fromJson)
                .toList()
          : const [],
      recommendation: recommendationJson is Map<String, dynamic>
          ? AssistantResponse.fromJson(recommendationJson)
          : null,
      isError: json['isError'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'text': text,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'images': images.map((image) => image.toJson()).toList(),
    'recommendation': recommendation?.toJson(),
    'isError': isError,
  };
}

ChatRole _chatRoleFromJson(Object? value) {
  return value == 'user' ? ChatRole.user : ChatRole.assistant;
}

DateTime _dateFromJson(Object? value) {
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}

List<int> _decodeBase64(String value) {
  if (value.isEmpty) return const [];
  try {
    return base64Decode(value);
  } on FormatException {
    return const [];
  }
}
