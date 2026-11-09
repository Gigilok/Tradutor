/// Modelos de dados usados pelo app.
library;

/// Uma mensagem do chat (texto, foto ou aviso do sistema).
class Message {
  final String id;
  final String roomId;
  final String senderName;
  final String senderLang;
  final String kind; // 'text' | 'image' | 'system'
  final String original;
  final String? photoId;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.roomId,
    required this.senderName,
    required this.senderLang,
    required this.kind,
    required this.original,
    this.photoId,
    required this.createdAt,
  });

  /// Monta a mensagem a partir do JSON que vem do servidor MQTT.
  factory Message.fromMqtt(Map<String, dynamic> map, {required String room}) {
    final ts = map['ts'];
    return Message(
      id: map['id'] as String,
      roomId: room,
      senderName: (map['name'] ?? '') as String,
      senderLang: (map['lang'] ?? 'pt') as String,
      kind: (map['kind'] ?? 'text') as String,
      original: (map['text'] ?? '') as String,
      photoId: map['photoId'] as String?,
      createdAt: ts is num
          ? DateTime.fromMillisecondsSinceEpoch(ts.toInt())
          : DateTime.now(),
    );
  }

  bool get isSystem => kind == 'system';
  bool get isImage => kind == 'image';
}

/// Um filme adicionado à sala.
class Movie {
  final String id;
  final String title;
  final String? url; // link direto (.mp4, .m3u8) — null quando arquivo local
  final String? localPath; // caminho no aparelho de quem adicionou
  final String? fileName; // nome do arquivo, para a amiga achar a cópia dela
  final String addedBy;
  final DateTime createdAt;

  Movie({
    required this.id,
    required this.title,
    this.url,
    this.localPath,
    this.fileName,
    required this.addedBy,
    required this.createdAt,
  });

  bool get isLocal => url == null || url!.isEmpty;

  /// Monta o filme a partir do JSON que vem do servidor MQTT.
  factory Movie.fromMqtt(Map<String, dynamic> map) {
    final ts = map['ts'];
    return Movie(
      id: map['id'] as String,
      title: (map['title'] ?? 'Filme') as String,
      url: map['url'] as String?,
      fileName: map['file'] as String?,
      addedBy: (map['by'] ?? '') as String,
      createdAt: ts is num
          ? DateTime.fromMillisecondsSinceEpoch(ts.toInt())
          : DateTime.now(),
    );
  }

  Movie copyWith({String? localPath}) {
    return Movie(
      id: id,
      title: title,
      url: url,
      localPath: localPath ?? this.localPath,
      fileName: fileName,
      addedBy: addedBy,
      createdAt: createdAt,
    );
  }
}

/// Estado de reprodução compartilhado (assistir junto, sincronizado).
class PlaybackState {
  final String? movieId;
  final double positionSeconds;
  final bool isPlaying;
  final String controller; // nome de quem controla a reprodução

  PlaybackState({
    this.movieId,
    required this.positionSeconds,
    required this.isPlaying,
    required this.controller,
  });

  factory PlaybackState.fromMap(Map<String, dynamic> map) {
    final pos = map['position_seconds'];
    return PlaybackState(
      movieId: map['movie_id'] as String?,
      positionSeconds: pos == null ? 0.0 : (pos is num ? pos.toDouble() : 0.0),
      isPlaying: (map['is_playing'] ?? false) as bool,
      controller: (map['controller'] ?? '') as String,
    );
  }
}

/// Uma legenda (fala) de um arquivo .srt/.vtt.
class SubtitleCue {
  final Duration start;
  final Duration end;
  final String text;
  String? translated;

  SubtitleCue({required this.start, required this.end, required this.text});

  bool activeAt(Duration position) => position >= start && position <= end;
}
