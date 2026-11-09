import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import 'mqtt_service.dart';

/// Estado global do perfil: nome, idioma e sala atual.
/// Fica salvo no aparelho (shared_preferences), ent茫o a pessoa
/// s贸 preenche UMA vez. Depois disso o app abre direto na conversa.
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
    roomId = roomCode;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_name', name);
    await prefs.setString('profile_lang', lang);
    await prefs.setString('room_code', roomCode);
  }

  /// Cria uma nova sala com c贸digo aleat贸rio de 4 caracteres.
  /// N茫o precisa de servidor para "criar": a sala existe a partir do
  /// momento em que as duas pessoas usam o mesmo c贸digo.
  Future<void> createRoom() async {
    roomCode = _randomCode();
    roomId = roomCode;
    await _joinRoom();
  }

  /// Entra numa sala existente pelo c贸digo (o mesmo da amiga).
  Future<void> joinRoom(String code) async {
    final clean = code.trim().toUpperCase();
    if (clean.length < 4) {
      throw Exception('O c贸digo da sala tem 4 caracteres (ex.: K7PD).');
    }
    roomCode = clean;
    roomId = clean;
    await _joinRoom();
  }

  /// Conecta no servidor p煤blico da sala e avisa no chat que voc锚 chegou.
  Future<void> _joinRoom() async {
    await PonteNet.instance.connect(
      roomCode: roomCode,
      name: name,
      lang: lang,
    );
    await _save();
    await PonteNet.instance.sendChat(
      senderName: 'Ponte',
      senderLang: lang,
      kind: 'system',
      text: '$name entrou na sala (${AppConfig.languageName(lang)})',
    );
    notifyListeners();
  }

  /// Atualiza perfil (nome e/ou idioma) e avisa a amiga na hora.
  Future<void> updateProfile({String? newName, String? newLang}) async {
    if (newName != null && newName.trim().isNotEmpty) name = newName.trim();
    if (newLang != null) lang = newLang;
    if (isLoggedIn) {
      PonteNet.instance.updateProfile(name: name, lang: lang);
    }
    await _save();
    notifyListeners();
  }

  /// Sai da sala (limpa o v铆nculo guardado no aparelho).
  Future<void> leaveRoom() async {
    await PonteNet.instance.disconnect();
    roomCode = '';
    roomId = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('room_code');
    notifyListeners();
  }

  static String _randomCode() {
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(4, (_) => letters[random.nextInt(letters.length)])
        .join();
  }
}
