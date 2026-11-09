import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models.dart';
import 'mqtt_service.dart';

/// Conversa em tempo real: envio de textos e fotos, escuta de novas
/// mensagens e presença (quem está online).
/// Usa o servidor público gratuito (broker.emqx.io) via [PonteNet].
class ChatService {
  /// Carrega as últimas [limit] mensagens da sala (mais antigas primeiro).
  /// O histórico vem do servidor na hora da conexão (até ~60 recentes).
  Future<List<Message>> loadMessages(String roomId, {int limit = 200}) async {
    return PonteNet.instance.loadMessages(limit: limit);
  }

  /// Escuta novas mensagens da sala em tempo real.
  void subscribeMessages(
    String roomId,
    void Function(Message message) onMessage,
  ) {
    PonteNet.instance.onMessage = onMessage;
  }

  /// Acompanha quem está online na sala agora.
  /// [onOthersOnline] recebe os nomes das OUTRAS pessoas online;
  /// [onOtherLastSeen] recebe quando a outra pessoa foi vista por último.
  void subscribePresence({
    required String roomId,
    required String myName,
    required void Function(Set<String> others) onOthersOnline,
    void Function(DateTime? lastSeen)? onOtherLastSeen,
  }) {
    PonteNet.instance.onPresenceChanged = () {
      final friend = PonteNet.instance.friendPresence(myName);
      onOthersOnline(
        PonteNet.instance.others
            .where((p) => p.online)
            .map((p) => p.name)
            .toSet(),
      );
      onOtherLastSeen?.call(friend?.lastSeen);
    };
  }

  /// Dados de presença da outra pessoa (online agora ou visto por último).
  PresenceInfo? friendPresence(String myName) =>
      PonteNet.instance.friendPresence(myName);

  /// Avisa quando uma foto terminou de chegar (para redesenhar a bolha).
  set onPhotosChanged(void Function()? callback) {
    PonteNet.instance.onPhotosChanged = callback;
  }

  /// Idioma mais recente de outra pessoa da sala (null se ainda ninguém).
  Future<String?> otherLanguage(String roomId, String myName) async {
    return PonteNet.instance.otherLanguage(myName);
  }

  /// Envia uma mensagem de texto.
  Future<void> sendText({
    required String roomId,
    required String senderName,
    required String senderLang,
    required String text,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    await PonteNet.instance.sendChat(
      senderName: senderName,
      senderLang: senderLang,
      kind: 'text',
      text: clean,
    );
  }

  /// Envia uma foto (arquivo já comprimido) com legenda opcional.
  /// A foto viaja em pedaços pelo servidor e vai direto para o aparelho
  /// da outra pessoa — não precisa de link nem de nuvem.
  Future<void> sendPhoto({
    required String roomId,
    required String senderName,
    required String senderLang,
    required File imageFile,
    String? caption,
  }) async {
    final bytes = await imageFile.readAsBytes();
    await PonteNet.instance.sendPhotoBytes(
      senderName: senderName,
      senderLang: senderLang,
      bytes: bytes,
      caption: caption,
    );
  }

  /// Mantido para compatibilidade: a conexão fica aberta o app inteiro.
  Future<void> unsubscribe() async {}

  /// Aviso do sistema (ex.: "Maria entrou na sala").
  Future<void> sendSystem(String text) async {
    await PonteNet.instance.sendChat(
      senderName: 'Ponte',
      senderLang: 'pt',
      kind: 'system',
      text: text,
    );
  }
}

/// Helper para logs de debug sem quebrar as regras de lint.
void debugLog(String message) {
  if (kDebugMode) {
    // ignore: avoid_print
    print('[Ponte] $message');
  }
}
