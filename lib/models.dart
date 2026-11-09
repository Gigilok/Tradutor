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
  final String? imageUrl;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.roomId,
    required this.senderName,
    required this.senderLang,
    required this.kind,
    required this.original,
    this.imageUrl,
    required this.createdAt,
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      senderName: (map['sender_name'] ?? '') as String,
      senderLang: (map['sender_lang'] ?? 'pt') as String,
      kind: (map['kind'] ?? 'text') as String,
      original: (map['original'] ?? '') as String,
      imageUrl: map['image_url'] as String?,
      createdAt:
          DateTime.tryParse((map['created_at'] ?? '') as String)?.toLocal() ??
              DateTime.now(),
    );
  }

  bool get isSystem => kind == 'system';
  bool get isImage => kind == 'image';
}

/// Um filme adicionado à sala.
class Movie {
  final String id;
  final String roomId;
  final String title;
  final String? url; // link direto (.mp4, .m3u8) — null quando arquivo local
  final String? localPath; // caminho no aparelho de quem adicionou
  final String addedBy;
  final DateTime createdAt;

  Movie({
    required this.id,
    required this.roomId,
    required this.title,
    this.url,
    this.localPath,
    required this.addedBy,
    required this.createdAt,
  });

  bool get isLocal => url == null || url!.isEmpty;

  factory Movie.fromMap(Map<String, dynamic> map) {
    return Movie(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      title: (map['title'] ?? 'Filme') as String,
      url: map['url'] as String?,
      localPath: map['local_path'] as String?,
      addedBy: (map['added_by'] ?? '') as String,
      createdAt:
          DateTime.tryParse((map['created_at'] ?? '') as String)?.toLocal() ??
              DateTime.now(),
    );
  }
}

/// Estado de reprodução compartilhado (assistir junto, sincronizado).
class PlaybackState {
  final String roomId;
  final String? movieId;
  final double positionSeconds;
  final bool isPlaying;
  final String controller; // nome de quem controla a reprodução

  PlaybackState({
    required this.roomId,
    this.movieId,
    required this.positionSeconds,
    required this.isPlaying,
    required this.controller,
  });

  factory PlaybackState.fromMap(Map<String, dynamic> map) {
    final pos = map['position_seconds'];
    return PlaybackState(
      roomId: map['room_id'] as String,
      movieId: map['movie_id'] as String?,
      positionSeconds: pos == null ? 0.0 : (pos is num ? pos.toDouble() : 0.0),
      isPlaying: (map['is_playing'] ?? false) as bool,
      controller: (map['controller'] ?? '') as String,
    );
  }
}

/// Um membro da sala (você ou sua amiga).
class RoomMember {
  final String id;
  final String roomId;
  final String name;
  final String lang;
  final DateTime lastSeen;

  RoomMember({
    required this.id,
    required this.roomId,
    required this.name,
    required this.lang,
    required this.lastSeen,
  });

  factory RoomMember.fromMap(Map<String, dynamic> map) {
    return RoomMember(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      name: (map['name'] ?? '') as String,
      lang: (map['lang'] ?? 'pt') as String,
      lastSeen:
          DateTime.tryParse((map['last_seen'] ?? '') as String)?.toLocal() ??
              DateTime.now(),
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
