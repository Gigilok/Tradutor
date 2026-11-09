import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models.dart';
import '../services/app_state.dart';
import '../services/chat_service.dart';
import '../services/translation.dart';
import '../widgets/message_bubble.dart';
import 'photo_view_screen.dart';

/// Conversa principal: lista de mensagens, envio de texto e fotos.
/// Cada mensagem recebida é traduzida automaticamente para o seu idioma
/// e exibida com as duas versões (original + traduzida).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chat = ChatService();
  final _input = TextEditingController();
  final _scroll = ScrollController();

  final List<Message> _messages = [];
  final Map<String, String> _translations = {};
  final Set<String> _translating = {};
  final Set<String> _failed = {};

  bool _loading = true;
  String? _otherLang;
  bool _sendingPhoto = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _chat.unsubscribe();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final state = context.read<AppState>();
    try {
      final messages = await _chat.loadMessages(state.roomId);
      if (!mounted) return;
      setState(() {
        _messages.addAll(messages);
        _loading = false;
      });
      _translatePending();
      _chat.subscribeMessages(state.roomId, (message) {
        if (!mounted) return;
        setState(() => _messages.add(message));
        _scrollToBottom();
        _translatePending();
      });
      final other = await _chat.otherLanguage(state.roomId, state.name);
      if (mounted && other != null) {
        setState(() => _otherLang = other);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Erro ao carregar conversa: $error');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Traduz para o meu idioma todas as mensagens da outra pessoa
  /// que ainda não têm tradução.
  Future<void> _translatePending() async {
    final state = context.read<AppState>();
    for (final message in _messages) {
      if (message.isSystem) continue;
      if (message.senderName.toLowerCase() == state.name.toLowerCase()) {
        continue;
      }
      if (_translations.containsKey(message.id) ||
          _translating.contains(message.id)) {
        continue;
      }
      if (message.senderLang == state.lang) {
        _translations[message.id] = '';
        continue;
      }
      setState(() {
        _translating.add(message.id);
        _failed.remove(message.id);
      });
      try {
        final translated = await TranslationService.translate(
          message.original,
          message.senderLang,
          state.lang,
        );
        if (!mounted) return;
        setState(() {
          _translations[message.id] = translated;
          _translating.remove(message.id);
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _translating.remove(message.id);
          _failed.add(message.id);
        });
      }
    }
  }

  Future<void> _retryTranslation(Message message) async {
    final state = context.read<AppState>();
    setState(() {
      _failed.remove(message.id);
      _translating.add(message.id);
    });
    try {
      final translated = await TranslationService.translate(
        message.original,
        message.senderLang,
        state.lang,
      );
      if (!mounted) return;
      setState(() {
        _translations[message.id] = translated;
        _translating.remove(message.id);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _translating.remove(message.id);
        _failed.add(message.id);
      });
    }
  }

  Future<void> _sendText() async {
    final state = context.read<AppState>();
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    try {
      await _chat.sendText(
        roomId: state.roomId,
        senderName: state.name,
        senderLang: state.lang,
        text: text,
      );
    } catch (error) {
      _showError('Não consegui enviar: $error');
    }
  }

  Future<void> _pickAndSendPhoto(ImageSource source) async {
    if (_sendingPhoto) return;
    final state = context.read<AppState>();
    final caption = TextEditingController();
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 70,
      );
      if (picked == null || !mounted) return;
      setState(() => _sendingPhoto = true);

      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF1E2227),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: Image.file(
                    File(picked.path),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: caption,
                decoration: const InputDecoration(
                  hintText: 'Legenda (opcional)',
                  prefixIcon: Icon(Icons.short_text),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Enviar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      if (confirmed != true || !mounted) return;

      await _chat.sendPhoto(
        roomId: state.roomId,
        senderName: state.name,
        senderLang: state.lang,
        imageFile: File(picked.path),
        caption: caption.text.trim(),
      );
    } catch (error) {
      _showError('Não consegui enviar a foto: $error');
    } finally {
      if (mounted) setState(() => _sendingPhoto = false);
    }
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E2227),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tirar foto agora'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendPhoto(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('Conversa'),
            Text(
              'Sala ${state.roomCode}${_otherLang != null ? ' · amiga fala $_otherLang' : ''}',
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 56,
                                color: Colors.white24,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Mande a primeira mensagem!\n'
                                'Ela chega traduzida para a sua amiga.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white38),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          reverse: true,
                          padding: const EdgeInsets.only(bottom: 8),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message =
                                _messages[_messages.length - 1 - index];
                            final isMine = message.senderName.toLowerCase() ==
                                state.name.toLowerCase();
                            return MessageBubble(
                              message: message,
                              isMine: isMine,
                              translated: _translations[message.id],
                              translating: _translating.contains(message.id),
                              translationFailed: _failed.contains(message.id),
                              onRetryTranslation: () =>
                                  _retryTranslation(message),
                              onOpenImage: message.imageUrl == null
                                  ? null
                                  : () => Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) => PhotoViewScreen(
                                            imageUrl: message.imageUrl!,
                                          ),
                                        ),
                                      ),
                            );
                          },
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1D21),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed:
                              _sendingPhoto ? null : _showPhotoSourceSheet,
                          icon: _sendingPhoto
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.add_photo_alternate_outlined),
                          tooltip: 'Enviar foto',
                        ),
                        Expanded(
                          child: TextField(
                            controller: _input,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: 'Mensagem em ${_myLangName(state)}...',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            onSubmitted: (_) => _sendText(),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filled(
                          onPressed: _sendText,
                          icon: const Icon(Icons.send_rounded),
                          tooltip: 'Enviar',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String _myLangName(AppState state) {
    return AppConfig.languageName(state.lang);
  }
}
