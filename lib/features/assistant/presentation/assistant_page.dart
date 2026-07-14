import 'dart:convert';
import 'dart:typed_data';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:car_luxe_cleaning_flutter/app/theme.dart';
import 'package:car_luxe_cleaning_flutter/core/errors/app_exception.dart';
import 'package:car_luxe_cleaning_flutter/features/assistant/data/assistant_repository.dart';
import 'package:car_luxe_cleaning_flutter/features/assistant/data/browser_speech.dart';
import 'package:car_luxe_cleaning_flutter/features/assistant/domain/assistant_response.dart';
import 'package:car_luxe_cleaning_flutter/features/assistant/domain/chat_message.dart';
import 'package:car_luxe_cleaning_flutter/shared/layout/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as chat_ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AssistantPage extends ConsumerStatefulWidget {
  const AssistantPage({super.key});

  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  static const _userId = 'client';
  static const _assistantId = 'assistant';

  final _inputController = TextEditingController();
  final _imagePicker = ImagePicker();
  final List<ChatMessage> _messages = [];
  final List<ChatImage> _pendingImages = [];
  final List<_AiCorrectionRule> _corrections = [];

  late final BrowserSpeechController _speech;
  late final chat.InMemoryChatController _chatController;

  bool _sending = false;
  bool _autoRead = false;

  @override
  void initState() {
    super.initState();
    final welcome = _welcomeMessage(
      "Bonjour, je suis l'assistant Car Luxe Cleaning. Decris l'etat du vehicule ou ajoute des photos pour recevoir un conseil personnalise.",
    );
    _messages.add(welcome);
    _chatController = chat.InMemoryChatController(
      messages: [_toFlyer(welcome)],
    );
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
    _chatController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _appendTranscript(String text) {
    final parts = [
      _inputController.text.trim(),
      text.trim(),
    ].where((part) => part.isNotEmpty).toList();
    _inputController.text = parts.join(' ');
    _inputController.selection = TextSelection.collapsed(
      offset: _inputController.text.length,
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
          .where((rule) => rule.customerMessage.trim().isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _corrections
          ..clear()
          ..addAll(rules);
      });
    } catch (_) {
      // Local assistant corrections are optional cache data.
    }
  }

  Future<void> _saveCorrections() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _AiCorrectionRule.storageKey,
      jsonEncode(_corrections.map((rule) => rule.toJson()).toList()),
    );
  }

  Future<void> _send({String? overrideText}) async {
    final text = (overrideText ?? _inputController.text).trim();
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
      _pendingImages.clear();
      _inputController.clear();
      _sending = true;
    });
    await _chatController.insertMessage(_toFlyer(userMessage));

    try {
      final result = await ref
          .read(assistantRepositoryProvider)
          .sendMessage(
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
      setState(() => _messages.add(assistantMessage));
      await _chatController.insertMessage(_toFlyer(assistantMessage));
      if (_autoRead) {
        _speech.speak(
          messageId: assistantMessage.id,
          text: assistantMessage.text,
        );
      }
    } on AppException catch (error) {
      await _addError(error.message);
    } catch (_) {
      await _addError(
        "La reponse recue n'a pas pu etre interpretee. Vous pouvez reformuler votre demande.",
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _addError(String message) async {
    if (!mounted) return;
    final error = ChatMessage(
      id: 'error-${DateTime.now().microsecondsSinceEpoch}',
      role: ChatRole.assistant,
      text: message,
      createdAt: DateTime.now(),
      isError: true,
    );
    setState(() => _messages.add(error));
    await _chatController.insertMessage(_toFlyer(error));
  }

  Future<void> _openAttachmentSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galerie'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickImage(source);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 72,
        maxWidth: 1280,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _pendingImages.add(
          ChatImage(
            id: 'image-${DateTime.now().microsecondsSinceEpoch}',
            fileName: file.name,
            mimeType: _mimeTypeFor(file.name),
            base64: base64Encode(bytes),
            bytes: bytes,
          ),
        );
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("L'image n'a pas pu etre ajoutee.")),
      );
    }
  }

  Future<void> _openCorrectionsPanel() async {
    final situationController = TextEditingController();
    final correctionController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final colors = ClcThemeColors.of(context);

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
              bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Corrections IA',
                        style: AppTextStyles.cardTitle.copyWith(
                          color: colors.textStrong,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: situationController,
                        decoration: const InputDecoration(
                          labelText: 'SITUATION CLIENT',
                          hintText: 'Ex: interieur tres sale avec odeur',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: correctionController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'REGLE A APPLIQUER',
                          hintText: 'Ex: proposer le pack interieur premium',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FButton(
                          onPress: addRule,
                          prefix: const Icon(Icons.add_rounded),
                          child: const Text('Ajouter'),
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (final rule in _corrections)
                        _CorrectionTile(
                          rule: rule,
                          onDelete: () => deleteRule(rule),
                        ),
                      if (_corrections.isEmpty)
                        Text(
                          'Aucune correction enregistree.',
                          style: AppTextStyles.body.copyWith(
                            color: colors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    situationController.dispose();
    correctionController.dispose();
  }

  Future<void> _reset() async {
    _speech.stopSpeaking();
    _speech.stopListening();
    final welcome = _welcomeMessage(
      'Nouvelle conversation ouverte. Decris le vehicule ou ajoute des photos.',
    );
    setState(() {
      _messages
        ..clear()
        ..add(welcome);
      _pendingImages.clear();
      _inputController.clear();
      _sending = false;
    });
    await _chatController.setMessages([_toFlyer(welcome)]);
  }

  chat.Message _toFlyer(ChatMessage message) {
    return chat.Message.text(
      id: message.id,
      authorId: message.role == ChatRole.user ? _userId : _assistantId,
      createdAt: message.createdAt,
      sentAt: message.createdAt,
      status: message.isError
          ? chat.MessageStatus.error
          : chat.MessageStatus.sent,
      text: message.text,
      metadata: {'imageCount': message.images.length},
    );
  }

  Future<chat.User?> _resolveUser(String id) async {
    return chat.User(
      id: id,
      name: id == _assistantId ? 'Assistant IA' : 'Client',
    );
  }

  ChatMessage? _domainFor(String id) {
    for (final message in _messages) {
      if (message.id == id) return message;
    }
    return null;
  }

  chat.Builders _builders() {
    return chat.Builders(
      textMessageBuilder:
          (context, message, index, {required isSentByMe, groupStatus}) {
            final domain = _domainFor(message.id);
            if (domain == null) {
              return chat_ui.SimpleTextMessage(message: message, index: index);
            }
            return _AssistantBubble(
              message: domain,
              isUser: isSentByMe,
              speaking: _speech.speakingMessageId == domain.id,
              onSpeak: () =>
                  _speech.speak(messageId: domain.id, text: domain.text),
              onStopSpeaking: _speech.stopSpeaking,
            );
          },
      composerBuilder: (context) => _AssistantComposer(
        controller: _inputController,
        sending: _sending,
        pendingImages: _pendingImages,
        onRemoveImage: (image) => setState(() => _pendingImages.remove(image)),
        onMic: _speech.toggleListening,
        listening: _speech.isListening,
        speechSupported: _speech.recognitionSupported,
        speechError: _speech.error,
      ),
      emptyChatListBuilder: (context) => const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);
    final isMobile = Responsive.isMobile(context);

    return Column(
      children: [
        _AssistantHeader(
          autoRead: _autoRead,
          voiceLabel: _speech.selectedVoiceLabel,
          correctionsCount: _corrections.length,
          compact: isMobile,
          listening: _speech.isListening,
          speechSupported: _speech.recognitionSupported,
          onAutoReadChanged: (value) => setState(() => _autoRead = value),
          onCorrections: _openCorrectionsPanel,
          onReset: _reset,
          onMic: _speech.toggleListening,
        ),
        if (_messages.length == 1) ...[
          const SizedBox(height: 12),
          _QuickPrompts(onSelected: (prompt) => _send(overrideText: prompt)),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: _GlassChatSurface(
            child: chat_ui.Chat(
              currentUserId: _userId,
              resolveUser: _resolveUser,
              chatController: _chatController,
              builders: _builders(),
              onMessageSend: (text) => _send(overrideText: text),
              onAttachmentTap: _openAttachmentSheet,
              backgroundColor: Colors.transparent,
              theme: chat.ChatTheme.fromThemeData(
                Theme.of(context),
              ).copyWith(shape: BorderRadius.circular(8)),
              decoration: BoxDecoration(
                color: colors.surfaceSoft.withValues(
                  alpha: colors.isLight ? 0.54 : 0.26,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AssistantHeader extends StatelessWidget {
  const _AssistantHeader({
    required this.autoRead,
    required this.voiceLabel,
    required this.correctionsCount,
    required this.compact,
    required this.listening,
    required this.speechSupported,
    required this.onAutoReadChanged,
    required this.onCorrections,
    required this.onReset,
    required this.onMic,
  });

  final bool autoRead;
  final String voiceLabel;
  final int correctionsCount;
  final bool compact;
  final bool listening;
  final bool speechSupported;
  final ValueChanged<bool> onAutoReadChanged;
  final VoidCallback onCorrections;
  final VoidCallback onReset;
  final VoidCallback onMic;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);
    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Assistant IA',
          style: AppTextStyles.cardTitle.copyWith(
            color: colors.textStrong,
            fontSize: compact ? 20 : 22,
          ),
        ),
        const SizedBox(width: 10),
        ShadBadge.secondary(child: Text('$correctionsCount regles')),
      ],
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FSwitch(
          value: autoRead,
          onChange: onAutoReadChanged,
          label: Text(
            'Lecture auto',
            style: TextStyle(color: colors.textStrong),
          ),
          description: Text(
            voiceLabel,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.muted),
          ),
        ),
        _HeaderIconButton(
          tooltip: listening ? 'Arreter le micro' : 'Dicter',
          icon: listening ? Icons.mic_off_rounded : Icons.mic_none_rounded,
          onPressed: speechSupported ? onMic : null,
        ),
        _HeaderIconButton(
          tooltip: 'Corrections IA',
          icon: Icons.psychology_alt_outlined,
          onPressed: onCorrections,
        ),
        _HeaderIconButton(
          tooltip: 'Nouvelle conversation',
          icon: Icons.refresh_rounded,
          onPressed: onReset,
        ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [title, const SizedBox(height: 12), actions],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: title),
        Flexible(
          child: Align(alignment: Alignment.centerRight, child: actions),
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: FButton.icon(
        onPress: onPressed,
        variant: FButtonVariant.outline,
        child: Icon(icon, size: 20),
      ),
    );
  }
}

class _GlassChatSurface extends StatelessWidget {
  const _GlassChatSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AdaptiveBlurView(
        blurStyle: BlurStyle.systemUltraThinMaterial,
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AssistantComposer extends StatelessWidget {
  const _AssistantComposer({
    required this.controller,
    required this.sending,
    required this.pendingImages,
    required this.onRemoveImage,
    required this.onMic,
    required this.listening,
    required this.speechSupported,
    required this.speechError,
  });

  final TextEditingController controller;
  final bool sending;
  final List<ChatImage> pendingImages;
  final ValueChanged<ChatImage> onRemoveImage;
  final VoidCallback onMic;
  final bool listening;
  final bool speechSupported;
  final String? speechError;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);
    return chat_ui.Composer(
      textEditingController: controller,
      hintText: 'Decris le vehicule, les taches ou ajoute des photos...',
      sendButtonDisabled: sending,
      attachmentIcon: const Icon(Icons.add_photo_alternate_outlined),
      sendIcon: sending
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.muted,
              ),
            )
          : const Icon(Icons.send_rounded),
      inputFillColor: colors.surfaceRaised,
      backgroundColor: colors.shell.withValues(alpha: 0.86),
      textColor: colors.textStrong,
      hintColor: colors.muted,
      maxLines: 4,
      topWidget: _ComposerTopBar(
        pendingImages: pendingImages,
        onRemoveImage: onRemoveImage,
        onMic: onMic,
        listening: listening,
        speechSupported: speechSupported,
        speechError: speechError,
        sending: sending,
      ),
    );
  }
}

class _ComposerTopBar extends StatelessWidget {
  const _ComposerTopBar({
    required this.pendingImages,
    required this.onRemoveImage,
    required this.onMic,
    required this.listening,
    required this.speechSupported,
    required this.speechError,
    required this.sending,
  });

  final List<ChatImage> pendingImages;
  final ValueChanged<ChatImage> onRemoveImage;
  final VoidCallback onMic;
  final bool listening;
  final bool speechSupported;
  final String? speechError;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);
    final hasError = (speechError ?? '').trim().isNotEmpty;
    final showBar = pendingImages.isNotEmpty || hasError || sending;
    if (!showBar && !speechSupported) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (sending)
                Text(
                  'Assistant en train de repondre...',
                  style: TextStyle(
                    color: colors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                const Spacer(),
              const Spacer(),
              Tooltip(
                message: listening ? 'Arreter le micro' : 'Dicter',
                child: IconButton(
                  onPressed: speechSupported ? onMic : null,
                  icon: Icon(
                    listening ? Icons.mic_off_rounded : Icons.mic_none_rounded,
                  ),
                ),
              ),
            ],
          ),
          if (pendingImages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final image in pendingImages)
                    _ImageThumb(
                      image: image,
                      onRemove: () => onRemoveImage(image),
                    ),
                ],
              ),
            ),
          if (hasError)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                speechError!,
                style: TextStyle(
                  color: colors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({
    required this.message,
    required this.isUser,
    required this.speaking,
    required this.onSpeak,
    required this.onStopSpeaking,
  });

  final ChatMessage message;
  final bool isUser;
  final bool speaking;
  final VoidCallback onSpeak;
  final VoidCallback onStopSpeaking;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);
    final background = message.isError
        ? colors.danger.withValues(alpha: 0.10)
        : isUser
        ? colors.focus
        : colors.surfaceRaised.withValues(alpha: colors.isLight ? 0.94 : 0.88);
    final textColor = isUser ? colors.onFocus : colors.textStrong;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: message.isError
                ? colors.danger.withValues(alpha: 0.26)
                : colors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: textColor,
                fontSize: 15.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (message.images.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final image in message.images) _ImageThumb(image: image),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    color: isUser
                        ? colors.onFocus.withValues(alpha: 0.68)
                        : colors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!isUser && !message.isError) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: speaking ? onStopSpeaking : onSpeak,
                    child: Icon(
                      speaking ? Icons.pause_rounded : Icons.volume_up_outlined,
                      color: colors.muted,
                      size: 17,
                    ),
                  ),
                ],
              ],
            ),
            if (message.recommendation != null)
              _RecommendationPanel(response: message.recommendation!),
          ],
        ),
      ),
    );
  }
}

class _RecommendationPanel extends StatelessWidget {
  const _RecommendationPanel({required this.response});

  final AssistantResponse response;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);
    final hasContent =
        response.recommendedPackName.isNotEmpty ||
        response.reasons.isNotEmpty ||
        response.suggestedOptions.isNotEmpty ||
        response.followUpQuestion.isNotEmpty;
    if (!hasContent) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.field,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RECOMMANDATION',
            style: AppTextStyles.eyebrow.copyWith(
              color: colors.focus,
              letterSpacing: 1.6,
            ),
          ),
          if (response.recommendedPackName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              response.recommendedPackName,
              style: AppTextStyles.cardTitle.copyWith(
                color: colors.textStrong,
                fontSize: 18,
              ),
            ),
          ],
          for (final reason in response.reasons) ...[
            const SizedBox(height: 6),
            Text(
              '- $reason',
              style: AppTextStyles.body.copyWith(color: colors.muted),
            ),
          ],
          for (final option in response.suggestedOptions) ...[
            const SizedBox(height: 6),
            Text(
              '+ $option',
              style: AppTextStyles.body.copyWith(color: colors.muted),
            ),
          ],
          if (response.followUpQuestion.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              response.followUpQuestion,
              style: TextStyle(
                color: colors.textStrong,
                fontWeight: FontWeight.w900,
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
    final colors = ClcThemeColors.of(context);
    const prompts = [
      'Quel pack choisir ?',
      'Analyser mon vehicule',
      'Comparer deux packs',
      'Taches sur les sieges',
      "Poils d'animaux",
      'Mauvaise odeur',
    ];

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final prompt in prompts)
            ActionChip(
              label: Text(prompt),
              onPressed: () => onSelected(prompt),
              labelStyle: TextStyle(
                color: colors.textStrong,
                fontWeight: FontWeight.w800,
              ),
              backgroundColor: colors.field,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: colors.border),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  const _ImageThumb({required this.image, this.onRemove});

  final ChatImage image;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            Uint8List.fromList(image.bytes),
            width: 76,
            height: 76,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),
        if (onRemove != null)
          Positioned(
            right: 4,
            top: 4,
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: colors.focus,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: colors.onFocus,
                  size: 15,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CorrectionTile extends StatelessWidget {
  const _CorrectionTile({required this.rule, required this.onDelete});

  final _AiCorrectionRule rule;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.field,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.psychology_alt_outlined, color: colors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.customerMessage,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rule.correctionNote,
                  style: AppTextStyles.body.copyWith(color: colors.muted),
                ),
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

ChatMessage _welcomeMessage(String text) {
  return ChatMessage(
    id: 'welcome-${DateTime.now().microsecondsSinceEpoch}',
    role: ChatRole.assistant,
    text: text,
    createdAt: DateTime.now(),
  );
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
