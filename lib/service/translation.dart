import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Tradução automática gratuita, com dois provedores e troca automática
/// em caso de falha:
///   1. Endpoint público do Google Translate (rápido, sem chave);
///   2. MyMemory (reserva, sem chave).
///
/// Inclui cache em memória para não repetir pedidos iguais.
class TranslationService {
  static final Map<String, String> _cache = {};
  static final http.Client _client = http.Client();

  static const Duration _timeout = Duration(seconds: 15);

  /// Traduz [text] do idioma [from] para [to] (códigos como 'pt', 'en'...).
  /// Devolve o próprio texto quando os idiomas são iguais ou o texto é vazio.
  static Future<String> translate(
    String text,
    String from,
    String to,
  ) async {
    final clean = text.trim();
    if (clean.isEmpty || from == to) return text;

    final key = '${from.toLowerCase()}2${to.toLowerCase()}:$clean';
    final cached = _cache[key];
    if (cached != null) return cached;

    String? result;
    for (final provider in [_viaGoogleChromeEx, _viaGoogle, _viaMyMemory]) {
      try {
        final candidate = await provider(clean, from, to);
        if (candidate.trim().isNotEmpty) {
          result = candidate;
          break;
        }
      } catch (_) {
        // tenta o próximo provedor
      }
    }

    if (result == null || result.trim().isEmpty) {
      throw Exception('Falha na tradução. Tente novamente.');
    }
    _cache[key] = result;
    return result;
  }

  /// Traduz uma lista de textos (usado pelas legendas) em blocos,
  /// reportando progresso de 0.0 a 1.0.
  static Future<List<String>> translateBatch(
    List<String> texts,
    String from,
    String to, {
    void Function(double progress)? onProgress,
  }) async {
    if (from == to) return List<String>.from(texts);

    final results = List<String?>.filled(texts.length, null, growable: false);
    final pending = <int>[];
    for (var i = 0; i < texts.length; i++) {
      final clean = texts[i].trim();
      if (clean.isEmpty) {
        results[i] = texts[i];
      } else {
        final cached = _cache['${from}2$to:$clean'];
        if (cached != null) {
          results[i] = cached;
        } else {
          pending.add(i);
        }
      }
    }

    // Monta blocos de até ~1200 caracteres juntando falas com um separador.
    const separator = '\n@@#\n';
    final chunks = <List<int>>[];
    var current = <int>[];
    var currentLength = 0;
    for (final index in pending) {
      final length = texts[index].length;
      if (current.isNotEmpty && currentLength + length > 1200) {
        chunks.add(current);
        current = <int>[];
        currentLength = 0;
      }
      current.add(index);
      currentLength += length + separator.length;
    }
    if (current.isNotEmpty) chunks.add(current);

    var done = 0;
    final total = pending.isEmpty ? 1 : pending.length;
    for (final chunk in chunks) {
      final joined = chunk.map((i) => texts[i]).join(separator);
      var translatedParts = <String>[];
      try {
        final translated = await translate(joined, from, to);
        translatedParts = translated.split('@@#');
      } catch (_) {
        translatedParts = const [];
      }

      if (translatedParts.length != chunk.length) {
        // Bloco veio desalinhado: traduz item por item (caminho mais lento).
        for (final i in chunk) {
          try {
            results[i] = await translate(texts[i], from, to);
          } catch (_) {
            results[i] = texts[i];
          }
          done++;
          onProgress?.call(done / total);
        }
      } else {
        for (var j = 0; j < chunk.length; j++) {
          results[chunk[j]] = translatedParts[j].trim();
          done++;
        }
        onProgress?.call(done / total);
      }
    }

    onProgress?.call(1.0);
    return results
        .map((r) => r ?? '') // nunca nulo
        .toList();
  }

  // -------------------------------------------------------------------------
  // Provedores
  // -------------------------------------------------------------------------

  static String _googleCode(String lang) {
    switch (lang.toLowerCase()) {
      case 'zh':
        return 'zh-CN';
      default:
        return lang;
    }
  }

  /// Provedor 1: endpoint público do Google (clients5, usado pelo Chrome).
  /// Qualidade Google, sem chave, tolera bem volumes maiores.
  static Future<String> _viaGoogleChromeEx(
    String text,
    String from,
    String to,
  ) async {
    final url = Uri.parse(
      'https://clients5.google.com/translate_a/t'
      '?client=dict-chrome-ex&sl=${_googleCode(from)}'
      '&tl=${_googleCode(to)}&q=${Uri.encodeComponent(text)}',
    );
    final response = await _client.get(url).timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('ChromeEx HTTP ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    if (data is! List || data.isEmpty) {
      throw Exception('Resposta inesperada do ChromeEx');
    }
    final first = data[0];
    if (first is String) return first;
    if (first is List && first.isNotEmpty && first[0] is String) {
      return first[0] as String;
    }
    throw Exception('Formato inesperado do ChromeEx');
  }

  /// Provedor 2: endpoint clássico do Google Translate (translate_a/single).
  static Future<String> _viaGoogle(String text, String from, String to) async {
    final url = Uri.parse(
      'https://translate.googleapis.com/translate_a/single'
      '?client=gtx&sl=${_googleCode(from)}&tl=${_googleCode(to)}&dt=t',
    );
    final response = await _client.post(url, body: {'q': text}).timeout(
      _timeout,
    );
    if (response.statusCode != 200) {
      throw Exception('Google translate HTTP ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    if (data is! List || data.isEmpty || data[0] is! List) {
      throw Exception('Resposta inesperada do Google translate');
    }
    final buffer = StringBuffer();
    for (final part in (data[0] as List)) {
      if (part is List && part.isNotEmpty) {
        buffer.write(part[0] ?? '');
      }
    }
    return buffer.toString();
  }

  /// Provedor 3: MyMemory (reserva, aceita blocos de até ~500 caracteres).
  static Future<String> _viaMyMemory(
    String text,
    String from,
    String to,
  ) async {
    // MyMemory aceita blocos de até ~500 caracteres.
    final pieces = <String>[];
    final buffer = StringBuffer();
    for (final line in text.split('\n')) {
      if (buffer.length + line.length > 450) {
        pieces.add(buffer.toString());
        buffer.clear();
      }
      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write(line);
    }
    if (buffer.isNotEmpty) pieces.add(buffer.toString());

    final output = <String>[];
    for (final piece in pieces) {
      final url = Uri.parse(
        'https://api.mymemory.translated.net/get'
        '?langpair=${_googleCode(from)}|${_googleCode(to)}',
      );
      final response = await _client.post(url, body: {'q': piece}).timeout(
        _timeout,
      );
      if (response.statusCode != 200) {
        throw Exception('MyMemory HTTP ${response.statusCode}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final status = data['responseStatus'];
      if (status is num && status >= 400) {
        throw Exception('MyMemory status $status');
      }
      final responseData = data['responseData'];
      if (responseData is! Map<String, dynamic>) {
        throw Exception('MyMemory resposta inválida');
      }
      output.add((responseData['translatedText'] ?? '') as String);
    }
    return output.join('\n');
  }
}
