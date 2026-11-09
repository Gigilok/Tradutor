import 'dart:io';

import 'package:flutter/material.dart';

import '../config.dart';
import '../models.dart';

/// Bolha da conversa. Mostra SEMPRE as duas versões quando existe
/// tradução: o texto original e a tradução para o seu idioma.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.translated,
    this.translating = false,
    this.translationFailed = false,
    this.onRetryTranslation,
    this.imagePath,
    this.onOpenImage,
  });

  final Message message;
  final bool isMine;
  final String? translated;
  final bool translating;
  final bool translationFailed;
  final VoidCallback? onRetryTranslation;
  final String? imagePath;
  final VoidCallback? onOpenImage;

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            message.original,
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final bubbleColor =
        isMine ? scheme.primaryContainer : const Color(0xFF23282E);
    final textColor = isMine ? Colors.black87 : Colors.white;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  message.senderName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                ),
              ),
            if (message.isImage && imagePath != null) _imagePart(),
            if (message.original.isNotEmpty) ...[
              _label(
                '${AppConfig.languageName(message.senderLang)} · original',
                textColor.withOpacity(0.55),
              ),
              const SizedBox(height: 2),
              SelectableText(
                message.original,
                style: TextStyle(color: textColor, fontSize: 15.5, height: 1.3),
              ),
            ],
            const SizedBox(height: 6),
            _translationPart(textColor),
            const SizedBox(height: 3),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _formatTime(message.createdAt),
                style: TextStyle(
                  fontSize: 10,
                  color: textColor.withOpacity(0.45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePart() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: onOpenImage,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260, maxHeight: 320),
            child: Image.file(
              File(imagePath!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 160,
                height: 120,
                color: Colors.black26,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(strokeWidth: 2),
                    SizedBox(height: 6),
                    Text(
                      'foto chegando...',
                      style: TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _translationPart(Color textColor) {
    if (translating) {
      return _box(
        textColor,
        Row(
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 6),
            Text(
              'traduzindo...',
              style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.6)),
            ),
          ],
        ),
      );
    }
    if (translationFailed && (translated == null || translated!.isEmpty)) {
      return _box(
        textColor,
        GestureDetector(
          onTap: onRetryTranslation,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh, size: 14, color: textColor.withOpacity(0.7)),
              const SizedBox(width: 4),
              Text(
                'tradução falhou — tentar de novo',
                style: TextStyle(
                  fontSize: 12,
                  color: textColor.withOpacity(0.7),
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (translated != null && translated!.isNotEmpty) {
      return _box(
        textColor,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('traduzido', textColor.withOpacity(0.55)),
            const SizedBox(height: 2),
            SelectableText(
              translated!,
              style: TextStyle(
                color: isMine ? Colors.black87 : Colors.white,
                fontSize: 15.5,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _box(Color textColor, Widget child) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }

  Widget _label(String text, Color color) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
        color: color,
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
