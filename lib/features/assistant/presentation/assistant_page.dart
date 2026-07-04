import 'dart:convert';
import 'dart:typed_data';

import 'package:car_luxe_cleaning_flutter/app/theme.dart';
import 'package:car_luxe_cleaning_flutter/core/errors/app_exception.dart';
import 'package:car_luxe_cleaning_flutter/core/widgets/app_button.dart';
import 'package:car_luxe_cleaning_flutter/features/assistant/data/assistant_repository.dart';
import 'package:car_luxe_cleaning_flutter/features/assistant/data/browser_speech.dart';
import 'package:car_luxe_cleaning_flutter/features/assistant/domain/chat_message.dart';
import 'package:car_luxe_cleaning_flutter/shared/layout/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AssistantPage extends ConsumerStatefulWidget {
  const AssistantPage({super.key});

  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  late final BrowserSpeechController _speech;
  final List<ChatMessage> _messages = [
    ChatMessage(
      id: 'welcome',
      role: ChatRole.assistant,
      text:
          "Bonjour, je suis l'assistant Car Luxe Cleaning. Décris l’état du véhicule ou ajoute des photos pour recevoir un conseil personnalisé.",
      createdAt: DateTime.now(),
    ),
  ];
  final List<ChatImage> _pendingImages = [];
  final List<_AiCorrectionRule> _corrections = [];
  bool _sending = false;
  bool _autoRead = false;

  @override
  void initState() {
    super.initState();
    _speech = BrowserSpeechController(
      onTranscript: _appendTranscript,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
    );
    _speech.initialize();
    _loadCorrections();
  }

  @override
  void dispose() {
    _speech.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _appendTranscript(String text) {
    final current = _controller.text.trim();
    _controller.text = [
      current,
      text.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  Future<void> _loadCorrections() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_AiCorrectionRule.storageKey);
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final rules = decoded
          .whereType<Map<String, dynamic>>()
          .map(_AiCorrectionRule.fromJson)
          .whereType<_AiCorrectionRule>()
          .toList();
      if (!mounted) return;
      setState(() {
        _corrections
          ..clear()
          ..addAll(rules);
      });
    } catch (_) {
      // Corrupted local correction data should not block the assistant.
    }
  }

  Future<void> _saveCorrections() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _AiCorrectionRule.storageKey,
      jsonEncode(_corrections.map((rule) => rule.toJson()).toList()),
    );
  }

  Future<void> _openCorrectionsPanel() async {
    final situationController = TextEditingController();
    final correctionController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void addRule() {
              final situation = situationController.text.trim();
              final correction = correctionController.text.trim();
              if (situation.isEmpty || correction.isEmpty) return;
              final rule = _AiCorrectionRule.create(
                customerMessage: situation,
                correctionNote: correction,
              );
              setState(() => _corrections.insert(0, rule));
              setModalState(() {
                situationController.clear();
                correctionController.clear();
              });
              _saveCorrections();
            }

            void deleteRule(_AiCorrectionRule rule) {
              setState(
                () => _corrections.removeWhere((item) => item.id == rule.id),
              );
              setModalState(() {});
              _saveCorrections();
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom +
                    MediaQuery.viewPaddingOf(context).bottom +
                    20,
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 900),
                margin: const EdgeInsets.symmetric(horizontal: 0),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: AppShadows.lifted,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Corrections IA',
                              style: AppTextStyles.cardTitle.copyWith(
                                fontSize: 24,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ajoute une situation et la bonne règle. Ces corrections sont réutilisées dans les prochaines réponses Gemini.',
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: situationController,
                        decoration: const InputDecoration(
                          labelText: 'SITUATION CLIENT',
                          hintText:
                              'Ex: intérieur très sale avec boue et odeur',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: correctionController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'RÈGLE À APPLIQUER',
                          hintText:
                              'Ex: proposer un reconditionnement intérieur premium',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: AppButton(
                          label: 'Ajouter',
                          icon: Icons.add_rounded,
                          onPressed: addRule,
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (_corrections.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            'Aucune correction enregistrée.',
                            style: AppTextStyles.body,
                          ),
                        )
                      else
                        ..._corrections.map(
                          (rule) => _CorrectionRuleTile(
                            rule: rule,
                            onDelete: () => deleteRule(rule),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    situationController.dispose();
    correctionController.dispose();
  }

  Future<void> _send({String? overrideText}) async {
    final text = (overrideText ?? _controller.text).trim();
    if ((text.isEmpty && _pendingImages.isEmpty) || _sending) return;

    final images = List<ChatImage>.from(_pendingImages);
    final userMessage = ChatMessage(
      id: 'user-${DateTime.now().microsecondsSinceEpoch}',
      role: ChatRole.user,
      text: text.isEmpty ? 'Analyse les photos jointes.' : text,
      images: images,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _controller.clear();
      _pendingImages.clear();
      _sending = true;
    });
    _scrollToBottom();

    try {
      final repository = ref.read(assistantRepositoryProvider);
      final result = await repository.sendMessage(
        message: userMessage.text,
        images: images,
        history: _messages
            .where((message) => message.id != userMessage.id)
            .toList(),
        corrections: _corrections.map((rule) => rule.toJson()).toList(),
      );
      if (!mounted) return;
      final assistantMessage = ChatMessage(
        id: 'assistant-${DateTime.now().microsecondsSinceEpoch}',
        role: ChatRole.assistant,
        text: result.reply,
        recommendation: result,
        createdAt: DateTime.now(),
      );
      setState(() {
        _messages.add(assistantMessage);
      });
      if (_autoRead) {
        _speech.speak(
          messageId: assistantMessage.id,
          text: assistantMessage.text,
        );
      }
    } on AppException catch (error) {
      _addError(error.message);
    } catch (_) {
      _addError(
        "La réponse reçue n’a pas pu être interprétée. Vous pouvez reformuler votre demande.",
      );
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  void _addError(String message) {
    if (!mounted) return;
    setState(() {
      _messages.add(
        ChatMessage(
          id: 'error-${DateTime.now().microsecondsSinceEpoch}',
          role: ChatRole.assistant,
          text: message,
          createdAt: DateTime.now(),
          isError: true,
        ),
      );
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await _imagePicker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final mimeType = _mimeTypeFor(file.name);
    setState(() {
      _pendingImages.add(
        ChatImage(
          id: 'image-${DateTime.now().microsecondsSinceEpoch}',
          fileName: file.name,
          mimeType: mimeType,
          base64: base64Encode(bytes),
          bytes: bytes,
        ),
      );
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 4 : 8,
            vertical: isMobile ? 4 : 8,
          ),
          child: _AssistantHeader(
            autoRead: _autoRead,
            voiceLabel: _speech.selectedVoiceLabel,
            onAutoReadChanged: (value) => setState(() => _autoRead = value),
            correctionsCount: _corrections.length,
            onCorrections: _openCorrectionsPanel,
            onReset: _reset,
            compact: isMobile,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 32,
                    vertical: isMobile ? 18 : 26,
                  ),
                  itemCount: _messages.length + (_sending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_sending && index == _messages.length) {
                      return const _TypingBubble();
                    }
                    return _MessageBubble(
                      message: _messages[index],
                      speaking:
                          _speech.speakingMessageId == _messages[index].id,
                      onSpeak: () => _speech.speak(
                        messageId: _messages[index].id,
                        text: _messages[index].text,
                      ),
                      onStopSpeaking: _speech.stopSpeaking,
                    );
                  },
                ),
              ),
              if (_messages.length == 1)
                _QuickPrompts(
                  onSelected: (prompt) => _send(overrideText: prompt),
                ),
              if (_pendingImages.isNotEmpty)
                _PendingImages(
                  images: _pendingImages,
                  onRemove: (image) =>
                      setState(() => _pendingImages.remove(image)),
                ),
              _Composer(
                controller: _controller,
                sending: _sending,
                onSend: () => _send(),
                onCamera: () => _pickImage(ImageSource.camera),
                onGallery: () => _pickImage(ImageSource.gallery),
                onMic: () => _speech.toggleListening(),
                listening: _speech.isListening,
                speechSupported: _speech.recognitionSupported,
                speechError: _speech.error,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _reset() {
    _speech.stopSpeaking();
    _speech.stopListening();
    setState(() {
      _messages
        ..clear()
        ..add(
          ChatMessage(
            id: 'welcome-${DateTime.now().millisecondsSinceEpoch}',
            role: ChatRole.assistant,
            text:
                "Nouvelle conversation ouverte. Décris le véhicule ou ajoute des photos.",
            createdAt: DateTime.now(),
          ),
        );
      _pendingImages.clear();
      _controller.clear();
    });
  }
}

class _AssistantHeader extends StatelessWidget {
  const _AssistantHeader({
    required this.autoRead,
    required this.voiceLabel,
    required this.correctionsCount,
    required this.onAutoReadChanged,
    required this.onCorrections,
    required this.onReset,
    required this.compact,
  });

  final bool autoRead;
  final String voiceLabel;
  final int correctionsCount;
  final ValueChanged<bool> onAutoReadChanged;
  final VoidCallback onCorrections;
  final VoidCallback onReset;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Assistant IA',
          style: AppTextStyles.pageTitle.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );

    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _VoicePill(
          label: voiceLabel,
          autoRead: autoRead,
          onChanged: onAutoReadChanged,
        ),
        _HeaderActionButton(
          label: correctionsCount > 0
              ? 'Corrections IA ($correctionsCount)'
              : 'Corrections IA',
          icon: Icons.psychology_alt_outlined,
          onPressed: onCorrections,
        ),
        _HeaderActionButton(
          label: 'Nouvelle conversation',
          icon: Icons.refresh_rounded,
          onPressed: onReset,
        ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [title, const SizedBox(height: 18), actions],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: title),
        const SizedBox(width: 18),
        Flexible(child: actions),
      ],
    );
  }
}

class _VoicePill extends StatelessWidget {
  const _VoicePill({
    required this.label,
    required this.autoRead,
    required this.onChanged,
  });

  final String label;
  final bool autoRead;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 42, maxWidth: 300),
      padding: const EdgeInsets.only(left: 16, right: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.graphic_eq_rounded,
            size: 18,
            color: AppColors.muted,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(value: autoRead, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: AppColors.text),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.speaking,
    required this.onSpeak,
    required this.onStopSpeaking,
  });

  final ChatMessage message;
  final bool speaking;
  final VoidCallback onSpeak;
  final VoidCallback onStopSpeaking;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final bubbleColor = message.isError
        ? const Color(0xFFFFF2F1)
        : isUser
        ? AppColors.navy
        : Colors.white;
    final textColor = message.isError
        ? AppColors.danger
        : isUser
        ? Colors.white
        : AppColors.text;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: Responsive.isMobile(context) ? 680 : 820,
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 14, 10),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isUser ? 20 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 20),
                  ),
                  border: message.isError
                      ? Border.all(color: const Color(0xFFF2B8B5))
                      : null,
                  boxShadow: isUser || message.isError
                      ? const []
                      : const [
                          BoxShadow(
                            color: Color(0x0F000000),
                            blurRadius: 20,
                            offset: Offset(0, 4),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.text,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (message.images.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final image in message.images)
                            _ImageThumb(image: image),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.createdAt),
                          style: TextStyle(
                            color: isUser
                                ? Colors.white.withValues(alpha: 0.7)
                                : const Color(0xFF9CA3AF),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (!isUser &&
                            !message.isError &&
                            message.text.trim().isNotEmpty) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: speaking ? onStopSpeaking : onSpeak,
                            child: Icon(
                              speaking
                                  ? Icons.pause_rounded
                                  : Icons.volume_up_outlined,
                              color: const Color(0xFF9CA3AF),
                              size: 15,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (message.recommendation != null)
                _RecommandationPanel(response: message.recommendation!),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommandationPanel extends StatelessWidget {
  const _RecommandationPanel({required this.response});

  final dynamic response;

  @override
  Widget build(BuildContext context) {
    final hasPack = (response.recommendedPackName as String).isNotEmpty;
    if (!hasPack &&
        response.reasons.isEmpty &&
        response.suggestedOptions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recommandation'.toUpperCase(),
            style: AppTextStyles.eyebrow.copyWith(letterSpacing: 2.2),
          ),
          if (hasPack) ...[
            const SizedBox(height: 10),
            Text(
              response.recommendedPackName as String,
              style: AppTextStyles.cardTitle,
            ),
          ],
          for (final reason in response.reasons as List<String>) ...[
            const SizedBox(height: 8),
            Text('- $reason', style: AppTextStyles.body),
          ],
          if ((response.followUpQuestion as String).isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              response.followUpQuestion as String,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.text,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickPrompts extends StatelessWidget {
  const _QuickPrompts({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    const prompts = [
      'Quel pack choisir ?',
      'Analyser mon véhicule',
      'Comparer deux packs',
      'Taches sur les sièges',
      "Poils d'animaux",
      'Mauvaise odeur',
      'Je souhaite un reconditionnement',
      'Mon véhicule est très sale',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final prompt in prompts)
            ActionChip(
              label: Text(prompt),
              onPressed: () => onSelected(prompt),
              labelStyle: const TextStyle(fontWeight: FontWeight.w800),
              backgroundColor: AppColors.surfaceMuted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
        ],
      ),
    );
  }
}

class _PendingImages extends StatelessWidget {
  const _PendingImages({required this.images, required this.onRemove});

  final List<ChatImage> images;
  final ValueChanged<ChatImage> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final image in images)
            Stack(
              children: [
                _ImageThumb(image: image),
                Positioned(
                  right: 4,
                  top: 4,
                  child: GestureDetector(
                    onTap: () => onRemove(image),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: AppColors.navy,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  const _ImageThumb({required this.image});

  final ChatImage image;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.memory(
        Uint8List.fromList(image.bytes),
        width: 82,
        height: 82,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onCamera,
    required this.onGallery,
    required this.onMic,
    required this.listening,
    required this.speechSupported,
    required this.speechError,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onMic;
  final bool listening;
  final bool speechSupported;
  final String? speechError;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 30,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText:
                              'Décris le véhicule, les taches, les odeurs ou ajoute des photos…',
                        ),
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 15,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _IconAction(
                      icon: Icons.camera_alt_outlined,
                      onTap: onCamera,
                      enabled: !sending,
                    ),
                    _IconAction(
                      icon: Icons.add_photo_alternate_outlined,
                      onTap: onGallery,
                      enabled: !sending,
                    ),
                    _IconAction(
                      icon: listening
                          ? Icons.mic_off_rounded
                          : Icons.mic_none_rounded,
                      onTap: onMic,
                      selected: listening,
                      enabled: speechSupported && !sending,
                    ),
                    const SizedBox(width: 4),
                    _SendRoundButton(
                      sending: sending,
                      enabled: !sending,
                      onTap: onSend,
                    ),
                  ],
                ),
              ),
              if ((speechError ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                _ComposerError(message: speechError!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.onTap,
    this.selected = false,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: selected ? AppColors.navy : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Icon(
            icon,
            color: selected
                ? Colors.white
                : enabled
                ? AppColors.muted
                : AppColors.muted.withValues(alpha: 0.42),
          ),
        ),
      ),
    );
  }
}

class _SendRoundButton extends StatelessWidget {
  const _SendRoundButton({
    required this.sending,
    required this.enabled,
    required this.onTap,
  });

  final bool sending;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: enabled ? onTap : null,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.navy
              : AppColors.muted.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(
          sending ? Icons.more_horiz_rounded : Icons.send_rounded,
          color: Colors.white,
          size: 19,
        ),
      ),
    );
  }
}

class _ComposerError extends StatelessWidget {
  const _ComposerError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.danger,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 20,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Text(
          'Assistant en train de répondre…',
          style: AppTextStyles.body,
        ),
      ),
    );
  }
}

class _CorrectionRuleTile extends StatelessWidget {
  const _CorrectionRuleTile({required this.rule, required this.onDelete});

  final _AiCorrectionRule rule;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.psychology_alt_outlined, color: AppColors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.customerMessage,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(rule.correctionNote, style: AppTextStyles.body),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Supprimer',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _AiCorrectionRule {
  const _AiCorrectionRule({
    required this.id,
    required this.createdAt,
    required this.customerMessage,
    required this.correctionNote,
  });

  static const storageKey = 'car_luxe_cleaning.ai_corrections.v1';

  final String id;
  final DateTime createdAt;
  final String customerMessage;
  final String correctionNote;

  factory _AiCorrectionRule.create({
    required String customerMessage,
    required String correctionNote,
  }) {
    final now = DateTime.now();
    return _AiCorrectionRule(
      id: 'correction-${now.microsecondsSinceEpoch}',
      createdAt: now,
      customerMessage: customerMessage,
      correctionNote: correctionNote,
    );
  }

  factory _AiCorrectionRule.fromJson(Map<String, dynamic> json) {
    return _AiCorrectionRule(
      id:
          json['id'] as String? ??
          'correction-${DateTime.now().microsecondsSinceEpoch}',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      customerMessage: json['customerMessage'] as String? ?? '',
      correctionNote: json['correctionNote'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    final timestamp = createdAt.toIso8601String();
    return {
      'id': id,
      'createdAt': timestamp,
      'updatedAt': timestamp,
      'sourceMessageId': '',
      'kind': 'correction',
      'customerMessage': customerMessage,
      'assistantReply': '',
      'proposedPackCode': '',
      'correctedPackCode': '',
      'reason': 'other',
      'correctionNote': correctionNote,
      'reusableRule': true,
      'status': 'approved',
    };
  }
}

String _mimeTypeFor(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
