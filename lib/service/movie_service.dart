import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';

/// Filmes da sala e sincronização de reprodução ("assistir junto").
class MovieService {
  RealtimeChannel? _channel;

  /// Lista os filmes da sala, mais recentes primeiro.
  Future<List<Movie>> loadMovies(String roomId) async {
    final client = Supabase.instance.client;
    final rows = await client
        .from('movies')
        .select()
        .eq('room_id', roomId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => Movie.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Adiciona um filme por link (mp4, m3u8/HLS...).
  Future<Movie> addByUrl({
    required String roomId,
    required String addedBy,
    required String title,
    required String url,
  }) async {
    final client = Supabase.instance.client;
    final inserted = await client
        .from('movies')
        .insert({
          'room_id': roomId,
          'title': title.trim().isEmpty ? 'Filme' : title.trim(),
          'url': url.trim(),
          'added_by': addedBy,
        })
        .select()
        .single();
    return Movie.fromMap(inserted);
  }

  /// Adiciona um filme que está só no aparelho (arquivo local).
  Future<Movie> addLocalFile({
    required String roomId,
    required String addedBy,
    required String title,
    required String localPath,
  }) async {
    final client = Supabase.instance.client;
    final inserted = await client
        .from('movies')
        .insert({
          'room_id': roomId,
          'title': title.trim().isEmpty ? 'Filme' : title.trim(),
          'local_path': localPath,
          'added_by': addedBy,
        })
        .select()
        .single();
    return Movie.fromMap(inserted);
  }

  /// Remove um filme da lista.
  Future<void> removeMovie(String movieId) async {
    final client = Supabase.instance.client;
    await client.from('movies').delete().eq('id', movieId);
  }

  /// Publica/atualiza o estado de reprodução da sala (sincronização).
  Future<void> publishPlayback({
    required String roomId,
    required String movieId,
    required double positionSeconds,
    required bool isPlaying,
    required String controller,
  }) async {
    final client = Supabase.instance.client;
    await client.from('playback').upsert({
      'room_id': roomId,
      'movie_id': movieId,
      'position_seconds': positionSeconds,
      'is_playing': isPlaying,
      'controller': controller,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Estado de reprodução atual da sala (ou null).
  Future<PlaybackState?> loadPlayback(String roomId) async {
    final client = Supabase.instance.client;
    final row = await client
        .from('playback')
        .select()
        .eq('room_id', roomId)
        .maybeSingle();
    if (row == null) return null;
    return PlaybackState.fromMap(row);
  }

  /// Escuta mudanças de reprodução (para acompanhar quem controla).
  RealtimeChannel subscribePlayback(
    String roomId,
    void Function(PlaybackState state) onChanged,
  ) {
    final client = Supabase.instance.client;
    _channel?.unsubscribe();
    final channel = client
        .channel('playback-$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'playback',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) {
            final map = payload.newRecord;
            if (map.isNotEmpty) {
              onChanged(PlaybackState.fromMap(map));
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
}
