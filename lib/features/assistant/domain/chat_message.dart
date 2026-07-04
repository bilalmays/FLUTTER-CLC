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
}
