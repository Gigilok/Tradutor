import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

/// Estado global do perfil: nome, idioma e sala atual.
/// Fica salvo no aparelho (shared_preferences), então a pessoa
/// só preenche uma vez.
class AppState extends ChangeNotifier {
  String name = '';
  String lang = 'pt';
  String roomCode = '';
  String roomId = '';

  bool get isLoggedIn => name.isNotEmpty && roomCode.isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    name = prefs.getString('profile_name') ?? '';
    lang = prefs.getString('profile_lang') ?? 'pt';
    roomCode = prefs.getString('room_code') ?? '';
    roomId = prefs.getString('room_id') ?? '';
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_name', name);
    await prefs.setString('profile_lang', lang);
    await prefs.setString('room_code', roomCode);
    await prefs.setString('room_id', roomId);
  }

  /// Cria uma nova sala com código aleatório de 4 letras.
  Future<void> createRoom() async {
    final client = Supabase.instance.client;
    for (var attempt = 0; attempt < 10; attempt++) {
      final code = _randomCode();
      final existing = await client
          .from('rooms')
          .select('id')
          .eq('code', code)
          .maybeSingle();
      if (existing != null) continue;
      final inserted = await client
          .from('rooms')
          .insert({'code': code})
          .select('id, code')
          .single();
      roomCode = inserted['code'] as String;
      roomId = inserted['id'] as String;
      await _joinRoom();
      return;
    }
    throw Exception('Não foi possível criar a sala. Tente novamente.');
  }

  /// Entra numa sala existente pelo código.
  Future<void> joinRoom(String code) async {
    final clean = code.trim().toUpperCase();
    if (clean.length < 3) {
      throw Exception('Digite o código da sala (4 letras).');
    }
    final client = Supabase.instance.client;
    final room = await client
        .from('rooms')
        .select('id, code')
        .eq('code', clean)
        .maybeSingle();
    if (room == null) {
      throw Exception('Sala "$clean" não encontrada. Confira o código.');
    }
    roomCode = room['code'] as String;
    roomId = room['id'] as String;
    await _joinRoom();
  }

  /// Registra você como membro da sala e avisa no chat.
  Future<void> _joinRoom() async {
    final client = Supabase.instance.client;
    await client.from('members').insert({
      'room_id': roomId,
      'name': name,
      'lang': lang,
    });
    await client.from('messages').insert({
      'room_id': roomId,
      'sender_name': name,
      'sender_lang': lang,
      'kind': 'system',
      'original': '$name entrou na sala (${AppConfig.languageName(lang)})',
    });
    await _save();
    notifyListeners();
  }

  /// Atualiza perfil (nome e/ou idioma).
  Future<void> updateProfile({String? newName, String? newLang}) async {
    final client = Supabase.instance.client;
    if (newName != null && newName.trim().isNotEmpty) name = newName.trim();
    if (newLang != null) lang = newLang;
    if (isLoggedIn) {
      await client.from('members').insert({
        'room_id': roomId,
        'name': name,
        'lang': lang,
      });
    }
    await _save();
    notifyListeners();
  }

  /// Sai da sala (limpa o vínculo guardado no aparelho).
  Future<void> leaveRoom() async {
    roomCode = '';
    roomId = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('room_code');
    await prefs.remove('room_id');
    notifyListeners();
  }

  static String _randomCode() {
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(4, (_) => letters[random.nextInt(letters.length)])
        .join();
  }
}
