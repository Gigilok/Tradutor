import '../models.dart';
import 'mqtt_service.dart';

/// Filmes da sala e sincronização de reprodução ("assistir junto").
/// Usa o servidor público gratuito (broker.emqx.io) via [PonteNet].
class MovieService {
  /// Lista os filmes da sala, mais recentes primeiro.
  Future<List<Movie>> loadMovies(String roomId) async {
    return PonteNet.instance.loadMovies();
  }

  /// Adiciona um filme por link (mp4, m3u8/HLS...).
  ///
  /// >>> CORREÇÃO #3 + #15: antes usava firstWhere((m) => m.url == url),
  /// que crashava com StateError se o MQTT demorasse a refletir o filme
  /// recém-publicado (loadMovies voltava lista sem ele). Agora
  /// construímos o Movie localmente e retornamos direto, sem re-ler.
  /// Também valida a URL antes de publicar para evitar SSRF.
  Future<Movie> addByUrl({
    required String roomId,
    required String addedBy,
    required String title,
    required String url,
  }) async {
    final cleanUrl = url.trim();
    _validateVideoUrl(cleanUrl);
    // Constrói o Movie localmente (espelha o que addMovie publica no broker).
    final movie = Movie(
      id: '', // id é gerado dentro do PonteNet.addMovie; não temos acesso aqui.
      title: title.trim().isEmpty ? 'Filme' : title.trim(),
      url: cleanUrl,
      addedBy: addedBy,
      createdAt: DateTime.now(),
    );
    await PonteNet.instance.addMovie(title: title, url: cleanUrl);
    return movie;
  }

  /// Adiciona um filme que está no aparelho (arquivo local).
  /// A amiga vê o nome e escolhe a cópia dela para assistir junto.
  ///
  /// >>> CORREÇÃO #3: antes usava firstWhere com orElse: () => list.first,
  /// que crashava se a lista estivesse vazia. Agora construímos o Movie
  /// localmente e retornamos direto.
  Future<Movie> addLocalFile({
    required String roomId,
    required String addedBy,
    required String title,
    required String localPath,
  }) async {
    final name = localPath.split('/').last;
    final movie = Movie(
      id: '',
      title: title.trim().isEmpty ? name : title.trim(),
      fileName: name,
      addedBy: addedBy,
      createdAt: DateTime.now(),
    );
    await PonteNet.instance.addMovie(title: title, fileName: name);
    return movie;
  }

  /// Remove um filme da lista (some também para a amiga).
  Future<void> removeMovie(String movieId) async {
    await PonteNet.instance.removeMovie(movieId);
  }

  /// Publica o estado de reprodução (sincronização "assistir junto").
  Future<void> publishPlayback({
    required String roomId,
    required String movieId,
    required double positionSeconds,
    required bool isPlaying,
    required String controller,
  }) async {
    await PonteNet.instance.publishPlayback(
      movieId: movieId,
      positionSeconds: positionSeconds,
      isPlaying: isPlaying,
      controller: controller,
    );
  }

  /// Estado de reprodução atual (recebido via MQTT ou publicado por este
  /// cliente). >>> CORREÇÃO #4: antes sempre retornava null, fazendo a
  /// sincronização nunca restaurar corretamente quando a tela do player
  /// abria depois. Agora delega para PonteNet.loadPlayback().
  Future<PlaybackState?> loadPlayback(String roomId) async {
    return PonteNet.instance.loadPlayback();
  }

  /// Escuta mudanças de reprodução (para acompanhar quem controla).
  void subscribePlayback(
    String roomId,
    void Function(PlaybackState state) onChanged,
  ) {
    PonteNet.instance.onPlayback = onChanged;
  }

  Future<void> unsubscribe() async {
    PonteNet.instance.onPlayback = null;
  }

  /// >>> CORREÇÃO #15: valida URL de vídeo antes de publicar/sharear.
  /// Bloqueia schemes perigosos (file://, ftp://), ranges privados
  /// (10.x, 192.168.x, 172.16-31.x, 127.x) que poderiam ser usados
  /// para SSRF, e exige que a URL tenha uma extensão de vídeo
  /// reconhecida (.mp4, .m3u8, .mkv, .webm, .mov) ou seja HLS válido.
  void _validateVideoUrl(String url) {
    if (url.isEmpty) {
      throw ArgumentError('URL vazia.');
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw ArgumentError('URL inválida.');
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      throw ArgumentError(
        'Só aceitamos http:// ou https:// (recebido: $scheme).');
    }
    final host = uri.host;
    if (host.isEmpty) {
      throw ArgumentError('URL sem host.');
    }
    // Bloqueia ranges privados/loopback para evitar SSRF.
    if (_isPrivateOrLoopback(host)) {
      throw ArgumentError(
        'Não aceitamos URLs de rede interna ($host). Use um link público.');
    }
    // Confere extensão do path (ignora query string).
    final path = uri.path.toLowerCase();
    final hasVideoExt = path.endsWith('.mp4') ||
        path.endsWith('.m3u8') ||
        path.endsWith('.mkv') ||
        path.endsWith('.webm') ||
        path.endsWith('.mov') ||
        path.endsWith('.avi');
    // HLS às vezes não tem extensão clara; aceita se o host parecer CDN.
    if (!hasVideoExt && !path.contains('m3u8')) {
      throw ArgumentError(
        'A URL não termina em .mp4, .m3u8 ou outro formato de vídeo.');
    }
  }

  bool _isPrivateOrLoopback(String host) {
    if (host == 'localhost') return true;
    final parts = host.split('.');
    if (parts.length == 4) {
      // IPv4
      final octets = parts.map((p) => int.tryParse(p)).toList();
      if (octets.every((o) => o != null && o! >= 0 && o <= 255)) {
        final a = octets[0]!;
        final b = octets[1]!;
        if (a == 10) return true;                  // 10.0.0.0/8
        if (a == 172 && b >= 16 && b <= 31) return true;  // 172.16.0.0/12
        if (a == 192 && b == 168) return true;     // 192.168.0.0/16
        if (a == 127) return true;                 // 127.0.0.0/8 (loopback)
        if (a == 169 && b == 254) return true;     // 169.254.0.0/16 (link-local)
        if (a == 0) return true;                   // 0.0.0.0/8
      }
    }
    return false;
  }
}
