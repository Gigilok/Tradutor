import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../models.dart';

/// Conversa em tempo real: envio de textos e fotos, escuta de novas
/// mensagens e consulta de membros da sala.
class ChatService {
  RealtimeChannel? _channel;

  /// Escuta novas mensagens da sala em tempo real.
  /// Retorna o canal criado (guarde para cancelar ao sair da tela).
  RealtimeChannel subscribeMessages(
    String roomId,
    void Function(Message message) onMessage,
  ) {
    final client = Supabase.instance.client;
    _channel?.unsubscribe();
    final channel = client
        .channel('mensagens-$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) {
            final map = payload.newRecord;
            if (map.isNotEmpty) {
              onMessage(Message.fromMap(map));
            }
          },
        )
        .subscribe();
    _channel = channel;
    return channel;
  }

  Future<void> unsubscribe() async {
    await _channel?.unsubscribe();
    _channel = null;
  }

  /// Carrega as últimas [limit] mensagens da sala (mais antigas primeiro).
  Future<List<Message>> loadMessages(String roomId, {int limit = 200}) async {
    final client = Supabase.instance.client;
    final rows = await client
        .from('messages')
        .select()
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .limit(limit);
    final list = (rows as List)
        .map((row) => Message.fromMap(row as Map<String, dynamic>))
        .toList();
    return list.reversed.toList();
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
    final client = Supabase.instance.client;
    await client.from('messages').insert({
      'room_id': roomId,
      'sender_name': senderName,
      'sender_lang': senderLang,
      'kind': 'text',
      'original': clean,
    });
  }

  /// Envia uma foto (arquivo já comprimido) com legenda opcional.
  /// Retorna a URL pública da foto.
  Future<String> sendPhoto({
    required String roomId,
    required String senderName,
    required String senderLang,
    required File imageFile,
    String? caption,
  }) async {
    final client = Supabase.instance.client;
    final bytes = await imageFile.readAsBytes();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$roomId/foto_$stamp.jpg';

    await client.storage.from(AppConfig.photoBucket).uploadBinary(path, bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg'));

    final publicUrl =
        client.storage.from(AppConfig.photoBucket).getPublicUrl(path);

    await client.from('messages').insert({
      'room_id': roomId,
      'sender_name': senderName,
      'sender_lang': senderLang,
      'kind': 'image',
      'original': (caption ?? '').trim(),
      'image_url': publicUrl,
    });
    return publicUrl;
  }

  /// Carrega os membros da sala (para saber o idioma da outra pessoa).
  Future<List<RoomMember>> loadMembers(String roomId) async {
    final client = Supabase.instance.client;
    final rows = await client
        .from('members')
        .select()
        .eq('room_id', roomId)
        .order('last_seen', ascending: false)
        .limit(20);
    return (rows as List)
        .map((row) => RoomMember.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Idioma mais recente de outra pessoa da sala (null se ainda ninguém).
  Future<String?> otherLanguage(String roomId, String myName) async {
    final members = await loadMembers(roomId);
    for (final member in members) {
      if (member.name.toLowerCase() != myName.toLowerCase()) {
        return member.lang;
      }
    }
    return null;
  }
}

/// Helper para logs de debug sem quebrar as regras de lint.
void debugLog(String message) {
  if (kDebugMode) {
    // ignore: avoid_print
    print('[Ponte] $message');
  }
}
