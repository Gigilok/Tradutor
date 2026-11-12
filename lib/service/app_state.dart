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
    // >>> CORREÇÃO: try/catch — se o SharedPreferences falhar (ex. disco
    // cheio), o app não deve crashar na inicialização.
    try {
      final prefs = await SharedPreferences.getInstance();
      name = prefs.getString('profile_name') ?? '';
      lang = prefs.getString('profile_lang') ?? 'pt';
      roomCode = prefs.getString('room_code') ?? '';
      roomId = roomCode;
      notifyListeners();
    } catch (e) {
      // Fallback silencioso: deixa os defaults (name='', lang='pt',
      // roomCode=''). Usuário vai para a JoinScreen preencher de novo.
      lang = 'pt';
      notifyListeners();
    }
  }

  Future<void> _save() async {
    // >>> CORREÇÃO: try/catch pela mesma razão acima.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_name', name);
      await prefs.setString('profile_lang', lang);
      await prefs.setString('room_code', roomCode);
    } catch (_) {
      // silencioso: se não conseguiu salvar, segue o jogo em memória.
    }
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

  /// Conecta no servidor público da sala e avisa no chat que você chegou.
  ///
  /// >>> CORREÇÃO #19: removido o idioma da mensagem de sistema exibida.
  /// Antes era "$name entrou na sala (Português)" — isso vazava o idioma
  /// do usuário para qualquer pessoa que escutasse o tópico público
  /// ponte/<sala>/msg no broker.emqx.io. Agora a mensagem só diz que
  /// entrou; o idioma segue no campo `lang` do JSON (que só as duas
  /// pessoas da sala sabem decodificar via seu app).
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
      text: '$name entrou na sala',
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
  ///
  /// >>> CORREÇÃO #11: o histórico da sala NÃO é apagado ao sair —
  /// ele fica salvo em SharedPreferences por sala (ver
  /// PonteNet._saveHistory). Se o usuário voltar a entrar na mesma
  /// sala, as mensagens aparecem de novo. Para apagar explicitamente,
  /// usar clearHistory(roomCode) a partir dos Ajustes.
  Future<void> leaveRoom() async {
    await PonteNet.instance.disconnect();
    final oldRoom = roomCode;
    roomCode = '';
    roomId = '';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('room_code');
    } catch (_) {}
    notifyListeners();
  }

  /// >>> CORREÇÃO #11: apaga o histórico local de uma sala específica.
  /// Chamado pelo botão "Limpar histórico" nos Ajustes.
  Future<void> clearHistory() async {
    if (roomCode.isEmpty) return;
    await PonteNet.instance.clearHistory(roomCode);
    notifyListeners();
  }

  static String _randomCode() {
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(4, (_) => letters[random.nextInt(letters.length)])
        .join();
  }
}
