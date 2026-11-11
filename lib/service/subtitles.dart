import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';
import 'translation.dart';

/// Lê e traduz arquivos de legenda (.srt e .vtt).
class SubtitleService {
  static final RegExp _timeLine = RegExp(
    r'(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})\s*-->\s*'
    r'(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})',
  );

  /// Faz o parse do conteúdo de um arquivo .srt ou .vtt.
  /// Aceita índices, marcação WEBVTT e blocos com ou sem numeração.
  static List<SubtitleCue> parse(String content) {
    final cues = <SubtitleCue>[];
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final blocks = normalized.split(RegExp(r'\n{2,}'));

    for (final block in blocks) {
      final lines = block
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      if (lines.isEmpty) continue;
      if (lines.first.toUpperCase().startsWith('WEBVTT')) {
        lines.removeAt(0);
        if (lines.isEmpty) continue;
      }

      // Localiza a linha de tempo (pode vir depois do índice).
      var timeIndex = -1;
      Match? match;
      for (var i = 0; i < lines.length; i++) {
        final m = _timeLine.firstMatch(lines[i]);
        if (m != null) {
          timeIndex = i;
          match = m;
          break;
        }
      }
      if (match == null || timeIndex < 0) continue;

      final start = _parseTime(
        match.group(1)!,
        match.group(2)!,
        match.group(3)!,
        match.group(4)!,
      );
      final end = _parseTime(
        match.group(5)!,
        match.group(6)!,
        match.group(7)!,
        match.group(8)!,
      );

      final textLines = lines
          .skip(timeIndex + 1)
          .where((l) => !l.startsWith('NOTE'))
          .toList();
      final text = textLines.join('\n').trim();
      if (text.isEmpty) continue;

      final cue = SubtitleCue(start: start, end: end, text: text);
      cues.add(cue);
    }
    cues.sort((a, b) => a.start.compareTo(b.start));
    return cues;
  }

  static Duration _parseTime(String h, String m, String s, String ms) {
    final millis = int.parse(ms.padRight(3, '0'));
    return Duration(
      hours: int.parse(h),
      minutes: int.parse(m),
      seconds: int.parse(s),
      milliseconds: millis,
    );
  }

  /// Baixa uma legenda de uma URL (aceita texto simples; se for um
  /// endereço de vídeo, vai falhar com mensagem clara).
  ///
  /// >>> CORREÇÃO #15: valida a URL antes de fazer o GET para evitar SSRF.
  /// Bloqueia schemes não-HTTP, hosts de rede interna (10.x, 192.168.x,
  /// 127.x, etc.) e localhost.
  static Future<String> download(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) {
      throw ArgumentError('URL vazia.');
    }
    final uri = Uri.tryParse(cleanUrl);
    if (uri == null || !uri.hasScheme) {
      throw ArgumentError('URL inválida.');
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      throw ArgumentError(
          'Só aceitamos http:// ou https:// (recebido: $scheme).');
    }
    if (_isPrivateOrLoopback(uri.host)) {
      throw ArgumentError(
          'Não baixamos legendas de rede interna (${uri.host}). '
          'Use um link público.');
    }
    final response = await http.get(uri).timeout(
          const Duration(seconds: 30),
        );
    if (response.statusCode != 200) {
      throw Exception(
          'Não consegui baixar a legenda (HTTP ${response.statusCode}).');
    }
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  /// >>> CORREÇÃO #15: bloqueia hosts de rede interna/loopback.
  static bool _isPrivateOrLoopback(String host) {
    if (host.isEmpty || host == 'localhost') return true;
    final parts = host.split('.');
    if (parts.length == 4) {
      final octets = parts.map((p) => int.tryParse(p)).toList();
      if (octets.every((o) => o != null && o! >= 0 && o <= 255)) {
        final a = octets[0]!;
        final b = octets[1]!;
        if (a == 10) return true;
        if (a == 172 && b >= 16 && b <= 31) return true;
        if (a == 192 && b == 168) return true;
        if (a == 127) return true;
        if (a == 169 && b == 254) return true;
        if (a == 0) return true;
      }
    }
    return false;
  }

  /// Traduz todas as falas da legenda para o idioma [to],
  /// reportando progresso de 0.0 a 1.0.
  static Future<void> translateCues(
    List<SubtitleCue> cues,
    String from,
    String to, {
    void Function(double progress)? onProgress,
  }) async {
    // Limpa traduções anteriores.
    for (final cue in cues) {
      cue.translated = null;
    }
    final texts = cues.map((c) => c.text).toList();
    final translated = await TranslationService.translateBatch(
      texts,
      from,
      to,
      onProgress: onProgress,
    );
    for (var i = 0; i < cues.length && i < translated.length; i++) {
      cues[i].translated = translated[i];
    }
  }

  /// Fala ativa na posição informada (ou null).
  static SubtitleCue? cueAt(List<SubtitleCue> cues, Duration position) {
    // Começa do fim: legendas costumam estar em ordem cronológica.
    for (var i = cues.length - 1; i >= 0; i--) {
      final cue = cues[i];
      if (position >= cue.start) {
        if (position <= cue.end) return cue;
        // Já passamos de todas as falas que começaram antes.
        return null;
      }
    }
    return null;
  }
}
