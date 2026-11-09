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
  Future<Movie> addByUrl({
    required String roomId,
    required String addedBy,
    required String title,
    required String url,
  }) async {
    await PonteNet.instance.addMovie(title: title, url: url.trim());
    final list = await PonteNet.instance.loadMovies();
    return list.firstWhere((m) => m.url == url.trim());
  }

  /// Adiciona um filme que está no aparelho (arquivo local).
  /// A amiga vê o nome e escolhe a cópia dela para assistir junto.
  Future<Movie> addLocalFile({
    required String roomId,
    required String addedBy,
    required String title,
    required String localPath,
  }) async {
    final name = localPath.split('/').last;
    await PonteNet.instance.addMovie(title: title, fileName: name);
    final list = await PonteNet.instance.loadMovies();
    return list.firstWhere(
      (m) => m.fileName == name,
      orElse: () => list.first,
    );
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

  /// Estado de reprodução atual (sem persistência: a sincronia é ao vivo).
  Future<PlaybackState?> loadPlayback(String roomId) async {
    return null;
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
}
